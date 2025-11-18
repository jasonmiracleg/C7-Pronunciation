//
//  AudioManager.swift
//  Unified audio recording and phoneme recognition manager
//

import Foundation
import AVFoundation
import Combine
import CoreML

// MARK: - Errors

enum AudioError: LocalizedError {
    case noRecordingAvailable
    case phonemeRecognitionNotReady
    case managerDeallocated
    case modelNotLoaded
    case decoderNotInitialized
    case audioLoadFailed
    case invalidOutput
    case fileNotFound
    case loadFailed
    case invalidFormat
    case resamplingFailed
    case silentAudio
    case tooShort
    
    var errorDescription: String? {
        switch self {
        case .noRecordingAvailable:
            return "No recording available"
        case .phonemeRecognitionNotReady:
            return "Phoneme recognition not initialized"
        case .managerDeallocated:
            return "Audio manager was deallocated"
        case .modelNotLoaded:
            return "Model not loaded"
        case .decoderNotInitialized:
            return "Decoder not initialized"
        case .audioLoadFailed:
            return "Failed to load audio file"
        case .invalidOutput:
            return "Invalid model output"
        case .fileNotFound:
            return "File not found"
        case .loadFailed:
            return "Failed to load processor"
        case .invalidFormat:
            return "Audio is in an invalid format"
        case .resamplingFailed:
            return "Failed resampling audio"
        case .silentAudio:
            return "Audio is completely silent (likely corrupted)"
        case .tooShort:
            return "Audio file is too short"
        }
    }
}

class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = AudioManager()
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var isProcessingPhonemes = false
    
    // MARK: - Audio Recording Properties
    
    var audioURL: URL?
    private var audioRecorder: AVAudioRecorder?
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Phoneme Recognition Properties
    
    private var model: MLModel?
    private var vocabulary: PhonemeVocabulary?
    private var decoder: CTCDecoder?
    
    private let modelName = "Wav2Vec2_Phoneme"
    private let vocabFilename = "vocab"
    private let chunkSize = 80000 // 5 seconds at 16kHz
    
    /// Indicates if phoneme recognition is ready
    private(set) var isPhonemeRecognitionReady = false
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupAudioSession()
        initializePhonemeRecognition()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - Phoneme Recognition Initialization
    
    private func initializePhonemeRecognition() {
        do {
            // Load vocabulary
            guard let vocab = PhonemeVocabulary(jsonFilename: vocabFilename) else {
                print("✗ Failed to load vocabulary from \(vocabFilename).json")
                return
            }
            self.vocabulary = vocab
            
            // Initialize decoder
            self.decoder = CTCDecoder(vocabulary: vocab)
            
            // Load CoreML model
            guard let modelURL = Bundle.main.url(
                forResource: modelName,
                withExtension: "mlmodelc"
            ) ?? Bundle.main.url(
                forResource: modelName,
                withExtension: "mlpackage"
            ) else {
                print("✗ Model not found: \(modelName)")
                return
            }
            
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
            print("✓ Model loaded: \(modelName)")
            
            isPhonemeRecognitionReady = true
            
        } catch {
            print("\n✗ Phoneme recognition initialization failed: \(error)")
        }
    }
    
    // MARK: - Recording Methods
    
    /// Start recording audio as WAV for phoneme recognition
    func startRecording() {
        let fileName = "recording_\(UUID().uuidString).wav"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.audioURL = documentsPath.appendingPathComponent(fileName)
        
        // Uncompressed WAV optimized for CoreML (16kHz, 16-bit, Mono)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        AVAudioApplication.requestRecordPermission { [weak self] allowed in
            guard let self = self, allowed else { return }
            
            DispatchQueue.main.async {
                do {
                    self.audioRecorder = try AVAudioRecorder(url: self.audioURL!, settings: settings)
                    self.audioRecorder?.delegate = self
                    self.audioRecorder?.isMeteringEnabled = true
                    self.audioRecorder?.record()
                    self.isRecording = true
                    print("✓ Recording started: \(fileName)")
                } catch {
                    print("Could not start recording: \(error)")
                }
            }
        }
    }
    
    /// Stop recording audio
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        print("✓ Recording stopped")
    }
    
    /// Update audio level (call this repeatedly while recording)
    func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0
            return
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert dB to linear scale (0-1)
        let minDb: Float = -60
        let normalizedPower = max(0, (averagePower - minDb) / (0 - minDb))
        
        audioLevel = normalizedPower
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed.")
        }
    }
    
    // MARK: - Phoneme Recognition Methods
    
    /// Recognize phonemes from the last recorded audio file
    /// - Returns: Recognized phonemes as a string
    /// - Throws: Recognition errors
    func recognizePhonemesFromLastRecording() async throws -> [[PhonemePrediction]] {
        guard let url = audioURL else {
            throw AudioError.noRecordingAvailable
        }
        
        return try await recognizePhonemes(from: url)
    }
    
    /// Recognize phonemes from an audio file
    /// - Parameter url: URL to audio file
    /// - Returns: Recognized phonemes as a string
    /// - Throws: Recognition errors
    func recognizePhonemes(from url: URL) async throws -> [[PhonemePrediction]] {
        guard isPhonemeRecognitionReady else {
            throw AudioError.phonemeRecognitionNotReady
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AudioError.managerDeallocated)
                    return
                }
                
                do {
                    let result = try self.recognizePhonemesSync(from: url)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Recognize phonemes from raw audio samples
    /// - Parameter samples: Audio samples (16kHz, mono, normalized to [-1, 1])
    /// - Returns: Recognized phonemes as a string
    /// - Throws: Recognition errors
    func recognizePhonemes(from samples: [Float]) async throws -> [[PhonemePrediction]] {
        guard isPhonemeRecognitionReady else {
            throw AudioError.phonemeRecognitionNotReady
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AudioError.managerDeallocated)
                    return
                }
                
                do {
                    let result = try self.recognizePhonemesSync(from: samples)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Recognition Methods
    
    // DEBUG: TEST OUTPUTTING PREDICTIONS WITH CONFIDENCE INTERVALS
//    private func recognizePhonemesSync(from url: URL) throws -> String {
    private func recognizePhonemesSync(from url: URL) throws -> [[PhonemePrediction]] {
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingPhonemes = true
        }
        
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.isProcessingPhonemes = false
            }
        }
        
        // Load and preprocess audio
        let samples = try loadAndPreprocessAudio(from: url)
        
        // Split into chunks
        let chunks = splitIntoChunks(samples: samples)
        
        // Process each chunk
        var allLogits: [[[Float]]] = []
        
        for (index, chunk) in chunks.enumerated() {
            print("  Chunk \(index + 1)/\(chunks.count)")
            let logits = try processChunk(chunk)
            allLogits.append(logits)
        }
        
        // Decode
        guard let decoder = decoder else {
            throw AudioError.decoderNotInitialized
        }
        
        let phonemes = decoder.decodeChunks(allLogits)
        
        return phonemes
    }
    
    func recognizePhonemesSync(from samples: [Float]) throws -> [[PhonemePrediction]] {
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingPhonemes = true
        }
        
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.isProcessingPhonemes = false
            }
        }
        
        let chunks = splitIntoChunks(samples: samples)
        
        var allLogits: [[[Float]]] = []
        
        for (index, chunk) in chunks.enumerated() {
            print("  Chunk \(index + 1)/\(chunks.count)")
            let logits = try processChunk(chunk)
            allLogits.append(logits)
        }
        
        guard let decoder = decoder else {
            throw AudioError.decoderNotInitialized
        }
        
        let phonemes = decoder.decodeChunks(allLogits)
        
        return phonemes
    }
    
    // MARK: - Audio Processing Helpers
    
    private func loadAndPreprocessAudio(from url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        
        let minFrames: Int64 = 1600
        if audioFile.length < minFrames {
            print("✗ Audio file too short: \(audioFile.length) frames")
            throw AudioError.tooShort
        }
        
        let format = audioFile.processingFormat
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw AudioError.audioLoadFailed
        }
        
        try audioFile.read(into: buffer)
        
        var samples = convertToMono(buffer: buffer)
        
        if format.sampleRate != 16000 {
            print("  Resampling to 16kHz...")
            samples = try resample(samples: samples, fromRate: format.sampleRate, toRate: 16000)
        }
        
        normalize(&samples)
        
        if samples.allSatisfy({ $0 == 0.0 }) {
            print("✗ Audio file is silent.")
            throw AudioError.silentAudio
        }

        print("  Loaded: \(samples.count) samples (\(Double(samples.count)/16000.0)s)")
        
        return samples
    }
    
    private func convertToMono(buffer: AVAudioPCMBuffer) -> [Float] {
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        
        guard let channelData = buffer.floatChannelData else {
            return []
        }
        
        var monoSamples = [Float](repeating: 0, count: frameCount)
        
        if channelCount == 1 {
            for i in 0..<frameCount {
                monoSamples[i] = channelData[0][i]
            }
        } else {
            for i in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][i]
                }
                monoSamples[i] = sum / Float(channelCount)
            }
        }
        
        return monoSamples
    }
    
    private func resample(samples: [Float], fromRate: Double, toRate: Double) throws -> [Float] {
        let ratio = toRate / fromRate
        let outputLength = Int(Double(samples.count) * ratio)
        var outputSamples = [Float](repeating: 0, count: outputLength)
        
        for i in 0..<outputLength {
            let srcIndex = Double(i) / ratio
            let srcIndexInt = Int(srcIndex)
            let fraction = Float(srcIndex - Double(srcIndexInt))
            
            if srcIndexInt < samples.count - 1 {
                let sample1 = samples[srcIndexInt]
                let sample2 = samples[srcIndexInt + 1]
                outputSamples[i] = sample1 + (sample2 - sample1) * fraction
            } else if srcIndexInt < samples.count {
                outputSamples[i] = samples[srcIndexInt]
            }
        }
        
        return outputSamples
    }
    
    private func normalize(_ samples: inout [Float]) {
        guard let maxVal = samples.map({ abs($0) }).max(), maxVal > 0 else {
            return
        }
        
        for i in 0..<samples.count {
            samples[i] = samples[i] / maxVal
        }
    }
    
    private func splitIntoChunks(samples: [Float]) -> [[Float]] {
        if samples.count <= chunkSize {
            var chunk = samples
            if chunk.count < chunkSize {
                chunk.append(contentsOf: [Float](repeating: 0, count: chunkSize - chunk.count))
            }
            return [chunk]
        }
        
        let overlap = 8000 // 0.5 seconds
        let stride = chunkSize - overlap
        
        var chunks: [[Float]] = []
        var startIndex = 0
        
        while startIndex < samples.count {
            let endIndex = min(startIndex + chunkSize, samples.count)
            var chunk = Array(samples[startIndex..<endIndex])
            
            if chunk.count < chunkSize / 2 {
                break
            }
            
            if chunk.count < chunkSize {
                chunk.append(contentsOf: [Float](repeating: 0, count: chunkSize - chunk.count))
            }
            
            chunks.append(chunk)
            
            if endIndex >= samples.count {
                break
            }
            
            startIndex += stride
        }
        
        return chunks
    }
    
    private func processChunk(_ chunk: [Float]) throws -> [[Float]] {
        guard let model = model else {
            throw AudioError.modelNotLoaded
        }
        
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: chunkSize)], dataType: .float32)
        
        for i in 0..<chunk.count {
            inputArray[i] = NSNumber(value: chunk[i])
        }
        
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_values": MLFeatureValue(multiArray: inputArray)
        ])
        
        let output = try model.prediction(from: inputFeatures)
        
        guard let outputFeature = output.featureValue(for: "var_1659") ?? output.featureValue(for: "logits"),
              let outputArray = outputFeature.multiArrayValue else {
            throw AudioError.invalidOutput
        }
        
        let logits = convertToLogits(outputArray)
        
        return logits
    }
    
    private func convertToLogits(_ mlArray: MLMultiArray) -> [[Float]] {
        let shape = mlArray.shape.map { $0.intValue }
        
        let timeSteps: Int
        let vocabSize: Int
        
        if shape.count == 3 {
            timeSteps = shape[1]
            vocabSize = shape[2]
        } else if shape.count == 2 {
            timeSteps = shape[0]
            vocabSize = shape[1]
        } else {
            print("⚠️ Unexpected shape: \(shape)")
            return []
        }
        
        var logits = [[Float]](
            repeating: [Float](repeating: 0, count: vocabSize),
            count: timeSteps
        )
        
        for t in 0..<timeSteps {
            for v in 0..<vocabSize {
                let indices: [NSNumber]
                if shape.count == 3 {
                    indices = [0, NSNumber(value: t), NSNumber(value: v)]
                } else {
                    indices = [NSNumber(value: t), NSNumber(value: v)]
                }
                
                logits[t][v] = mlArray[indices].floatValue
            }
        }
        
        return logits
    }
    
    // MARK: - Info
    
    var phonemeRecognitionInfo: String {
        guard isPhonemeRecognitionReady else {
            return "Phoneme recognition not initialized"
        }
        return """
        Model: \(modelName)
        Vocabulary: \(vocabulary?.vocabSize ?? 0) tokens
        Chunk size: \(chunkSize) samples (5 seconds)
        Status: Ready
        """
    }
}
