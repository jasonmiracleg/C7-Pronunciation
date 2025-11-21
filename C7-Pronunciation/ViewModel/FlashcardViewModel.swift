import Foundation
import SwiftUI
import Combine
import AVFoundation


class FlashcardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var targetSentence: String = ""
    @Published var wordScores: [WordScore] = []
    
    // State matching CustomViewModel
    @Published var isRecording: Bool = false
    @Published var isLoading: Bool = false
    @Published var overallScore: Double = 0.0
    @Published var errorMessage: String?
    @Published var isEvaluated: Bool = false
    
    // MARK: - Waveform State Variables
    // Displays the avg audio levels from audio manager
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 30)
    private var meteringTimer: Timer?
    
    // MARK: - Internal Properties
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        updateTargetSentence("Hello world")
    }
    
    // MARK: - Setup Logic
    
    func updateTargetSentence(_ text: String) {
        self.targetSentence = text
        
        // Reset scores to neutral
        self.wordScores = text.split(separator: " ").map {
            var wordScore = WordScore(word: String($0), score: 0.0, alignedPhonemes: [])
            return wordScore
        }
        self.overallScore = 0.0
        self.errorMessage = nil
        self.isEvaluated = false
        
        // Reset waveform
        self.audioLevels = Array(repeating: 0.0, count: 30)
    }
    
    // MARK: - User Actions
    
    func toggleRecording() {
        // Tak samano kayak custom ya
        if AudioManager.shared.isRecording {
            stopRecordingAndEvaluate()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        self.errorMessage = nil
        self.isLoading = false
        self.isEvaluated = false
        
        // Reset to unevaluated state
        for i in 0..<wordScores.count {
            wordScores[i].isEvaluated = false
        }
        
        startMetering()
        AudioManager.shared.startRecording()
        self.isRecording = true
    }
    
    func stopRecordingAndEvaluate() {
        // 1. Stop Metering
        stopMetering()
        
        // 2. Stop Hardware Recording
        AudioManager.shared.stopRecording()
        self.isRecording = false
        
        // 3. Start Processing
        self.isLoading = true
        
        Task {
            do {
                // A. Get Raw Predictions
                let chunkedPredictions = try await AudioManager.shared.recognizePhonemesFromLastRecording()
                let decodedPhonemes = chunkedPredictions.flatMap { $0 }
                
                // B. Align and Score
                let result = PronunciationScorer.shared.alignAndScore(
                    decodedPhonemes: decodedPhonemes,
                    targetSentence: self.targetSentence
                )
                
                // C. Update UI on MainActor
                self.overallScore = result.totalScore
                
                self.wordScores = result.wordScores.map { originalWordScore in
                    var wordScore = originalWordScore
                    let color = self.scoreColor(wordScore.score)
                    wordScore.color = color
                    wordScore.isEvaluated = true
                    return wordScore
                }
                
                self.isEvaluated = true
                self.isLoading = false
                
            } catch {
                print("Evaluation Error: \(error)")
                self.errorMessage = "Could not analyze audio. Please try again."
                self.isLoading = false
                self.isEvaluated = false
            }
        }
    }
    
    // MARK: - Metering Logic (Copied from CustomViewModel)
    
    private func startMetering() {
        // Update 20 times a second (0.05s)
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateAudioLevels()
        }
    }
    
    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        // Reset visualization to flat immediately
        DispatchQueue.main.async {
            self.audioLevels = Array(repeating: 0.0, count: 30)
        }
    }
    
    private func updateAudioLevels() {
        // Get real data from AudioManager
        let newLevel = AudioManager.shared.currentAveragePower
        
        var current = audioLevels
        current.removeFirst()
        current.append(newLevel)
        
        DispatchQueue.main.async {
            self.audioLevels = current
        }
    }
    
    // MARK: - Helpers
    
    private func scoreColor(_ score: Double) -> Color {
        let percentage = score * 100
        switch percentage {
        case 70...100: return Color.primary
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    func getCurrentPhonemes() -> [AlignedPhoneme] {
        return wordScores.flatMap { $0.alignedPhonemes }
    }
}
