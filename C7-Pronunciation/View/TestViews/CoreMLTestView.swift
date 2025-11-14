//
//  CoreMLTestView.swift (Using Singleton Manager)
//  Clean test view using PhonemeRecognitionManager
//


import Combine
import SwiftUI
import AVFoundation

struct CoreMLTestView: View {
    @StateObject private var viewModel = CoreMLTestViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Card
                    statusCard
                    
                    // Recording Controls
                    recordingControls
                    
                    // Results Section
                    if !viewModel.recognizedPhonemes.isEmpty {
                        resultsSection
                    }
                    
                    // Error Display
                    if let error = viewModel.errorMessage {
                        errorSection(error)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Phoneme Recognition")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(viewModel.isRecording ? .red : .blue)
            
            Text(viewModel.statusText)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if viewModel.isProcessing {
                ProgressView()
                    .padding(.top, 8)
            }
            
            if viewModel.isRecording {
                Text(viewModel.recordingDuration)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Recording Controls
    
    private var recordingControls: some View {
        VStack(spacing: 16) {
            if !viewModel.isRecording {
                Button(action: {
                    viewModel.startRecording()
                }) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Start Recording")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isProcessing)
            } else {
                Button(action: {
                    viewModel.stopRecording()
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop & Recognize")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            if viewModel.hasRecording {
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.playRecording()
                    }) {
                        HStack {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            Text(viewModel.isPlaying ? "Pause" : "Play")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isProcessing || viewModel.isRecording)
                    
                    Button(action: {
                        viewModel.recognizeAgain()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Recognize")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isProcessing || viewModel.isRecording)
                }
            }
        }
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recognized Phonemes")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(viewModel.recognizedPhonemes)
                    .font(.system(.title3, design: .default))
                    .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if let duration = viewModel.processingDuration {
                HStack {
                    Image(systemName: "clock")
                    Text("Processing: \(String(format: "%.2f", duration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                UIPasteboard.general.string = viewModel.recognizedPhonemes
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy to Clipboard")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - View Model

class CoreMLTestViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isPlaying = false
    @Published var hasRecording = false
    @Published var recognizedPhonemes = ""
    @Published var statusText = "Ready to record"
    @Published var errorMessage: String?
    @Published var recordingDuration = "00:00"
    @Published var processingDuration: Double?
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    // Use singleton manager
    private let manager = Wav2Vec2ModelManager.shared
    
    // MARK: - Recording
    
    func startRecording() {
        // Check if manager is initialized
        guard manager.isInitialized else {
            errorMessage = "Recognition system not ready"
            return
        }
        
        errorMessage = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            recordingURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
            
            guard let url = recordingURL else { return }
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            hasRecording = true
            statusText = "Recording..."
            recordingStartTime = Date()
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateRecordingDuration()
            }
            
            print("✓ Recording started")
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("✗ Recording error: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        isRecording = false
        statusText = "Processing..."
        
        print("✓ Recording stopped")
        
        if let url = recordingURL {
            recognizeAudio(from: url)
        }
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        recordingDuration = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Playback
    
    func playRecording() {
        guard let url = recordingURL else { return }
        
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
            statusText = "Playback paused"
        } else {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
                
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                
                isPlaying = true
                statusText = "Playing..."
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) { [weak self] in
                    self?.isPlaying = false
                    self?.statusText = "Ready"
                }
                
            } catch {
                errorMessage = "Playback failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Recognition
    
    func recognizeAgain() {
        guard let url = recordingURL else { return }
        recognizeAudio(from: url)
    }
    
    private func recognizeAudio(from url: URL) {
        isProcessing = true
        statusText = "Recognizing..."
        errorMessage = nil
        recognizedPhonemes = ""
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let startTime = Date()
            
            do {
                // Use singleton manager
                let phonemes = try Wav2Vec2ModelManager.shared.recognizePhonemes(from: url)
                let duration = Date().timeIntervalSince(startTime)
                
                DispatchQueue.main.async {
                    self?.recognizedPhonemes = phonemes
                    self?.processingDuration = duration
                    self?.isProcessing = false
                    self?.statusText = "Complete!"
                    
                    print("✓ Recognition complete")
                    print("  Result: \(phonemes)")
                }
                
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                    self?.statusText = "Failed"
                    print("✗ Recognition failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CoreMLTestView()
}
