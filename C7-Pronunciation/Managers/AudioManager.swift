//
//  AudioManager.swift
//  Unified audio recording and phoneme recognition manager
//

import Foundation
import AVFoundation
import Combine


class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = AudioManager()
    
    // MARK: - Published State
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var isProcessingPhonemes = false
    
    var isPhonemeRecognitionReady: Bool { return true } // Assumed ready if app launched
    
    // MARK: - Dependencies
    private let wav2vecManager = Wav2VecManager() // Renamed class
    private var audioRecorder: AVAudioRecorder?
    private let audioSession = AVAudioSession.sharedInstance()
    
    var audioURL: URL?
    private var permissionGranted = false
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        checkPermissions()
    }
    
    func preloadModel() async {
        print("AudioManager: Waiting for model to load...")
        await wav2vecManager.load()
        print("AudioManager: Model ready.")
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func checkPermissions() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: permissionGranted = true
        case .denied: permissionGranted = false
        case .undetermined:
            AVAudioApplication.requestRecordPermission { allowed in
                self.permissionGranted = allowed
            }
        @unknown default: permissionGranted = false
        }
    }
    
    // MARK: - Public Recording Methods
    
    func startRecording() {
        if let existing = audioRecorder { existing.stop() }
        
        if !permissionGranted { return }
        
        let fileName = "user_recording.wav"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.audioURL = documentsPath.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
            
            let newRecorder = try AVAudioRecorder(url: self.audioURL!, settings: settings)
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true
            
            if newRecorder.prepareToRecord() && newRecorder.record() {
                self.audioRecorder = newRecorder
                self.isRecording = true
                print("✓ Recording started")
            }
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        print("✓ Recording stopped")
    }
    
    var currentAveragePower: Float {
        guard let recorder = audioRecorder else { return 0.0 }
        
        if !recorder.isRecording {
            return 0.0
        }
        
        recorder.updateMeters()
        
        let power = recorder.averagePower(forChannel: 0)
        
        let minDb: Float = -60.0
        
        if power < minDb {
            return 0.0
        } else if power >= 0.0 {
            return 1.0
        } else {
            let normalized = (abs(minDb) - abs(power)) / abs(minDb)
            return pow(normalized, 3)
        }
    }
    
    // MARK: - Phoneme Recognition (Restored Functions)
    
    /// Recognize phonemes from the last recorded audio file
    func recognizePhonemesFromLastRecording() async throws -> [[PhonemePrediction]] {
        guard let url = audioURL else {
            throw AudioError.noRecordingAvailable
        }
        return try await recognizePhonemes(from: url)
    }
    
    /// Recognize phonemes from a specific URL
    func recognizePhonemes(from url: URL) async throws -> [[PhonemePrediction]] {
        DispatchQueue.main.async { self.isProcessingPhonemes = true }
        defer { DispatchQueue.main.async { self.isProcessingPhonemes = false } }
        
        // 1. Preprocess (remains here as it uses AVFoundation)
        let samples = try loadAndPreprocessAudio(from: url)
        
        // 2. Delegate to Manager (normalization happens per-chunk there)
        return try await wav2vecManager.process(samples: samples)
    }
    
    /// Recognize phonemes from raw samples
    func recognizePhonemes(from samples: [Float]) async throws -> [[PhonemePrediction]] {
        DispatchQueue.main.async { self.isProcessingPhonemes = true }
        defer { DispatchQueue.main.async { self.isProcessingPhonemes = false } }
        
        return try await wav2vecManager.process(samples: samples)
    }
    
    // MARK: - Audio Preprocessing Helpers
    
    private func loadAndPreprocessAudio(from url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        
        // Handle empty files - return empty array, Wav2VecManager will handle gracefully
        if audioFile.length == 0 {
            return []
        }
        
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioError.audioLoadFailed
        }
        try audioFile.read(into: buffer)
        
        var samples = convertToMono(buffer: buffer)
        
        if format.sampleRate != 16000 {
            samples = resample(samples: samples, fromRate: format.sampleRate, toRate: 16000)
        }
        
        // REMOVED: Min-max normalization was INCORRECT for wav2vec2
        // The model requires zero-mean unit-variance normalization which
        // is now applied per-chunk in Wav2VecManager.splitIntoChunks()
        //
        // OLD (WRONG):
        // if let maxVal = samples.map({ abs($0) }).max(), maxVal > 0 {
        //     samples = samples.map { $0 / maxVal }
        // }
        
        if samples.isEmpty { return [] }
        
        return samples
    }
    
    private func convertToMono(buffer: AVAudioPCMBuffer) -> [Float] {
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        guard let channelData = buffer.floatChannelData else { return [] }
        var monoSamples = [Float](repeating: 0, count: frameCount)
        
        if channelCount == 1 {
            for i in 0..<frameCount { monoSamples[i] = channelData[0][i] }
        } else {
            for i in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channelCount { sum += channelData[channel][i] }
                monoSamples[i] = sum / Float(channelCount)
            }
        }
        return monoSamples
    }
    
    private func resample(samples: [Float], fromRate: Double, toRate: Double) -> [Float] {
        let ratio = toRate / fromRate
        let outputLength = Int(Double(samples.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)
        for i in 0..<outputLength {
            let srcIdx = Double(i) / ratio
            let idxInt = Int(srcIdx)
            let frac = Float(srcIdx - Double(idxInt))
            if idxInt < samples.count - 1 {
                output[i] = samples[idxInt] + (samples[idxInt+1] - samples[idxInt]) * frac
            } else if idxInt < samples.count {
                output[i] = samples[idxInt]
            }
        }
        return output
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        audioRecorder = nil
    }
}
