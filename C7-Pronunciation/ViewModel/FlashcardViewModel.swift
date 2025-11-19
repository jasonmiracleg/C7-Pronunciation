//
//  FlashcardViewModel.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 13/11/25.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
class FlashcardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var targetSentence: String = ""
    @Published var wordScores: [WordScore] = []
    @Published var isRecording: Bool = false
    @Published var isLoading: Bool = false
    @Published var overallScore: Double = 0.0
    @Published var errorMessage: String?
    
    // MARK: - Internal Properties
    private var idealPhonemes: [[String]] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 1. Bind ViewModel's recording state to AudioManager's state
        AudioManager.shared.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        // 2. Initialize with default text
        updateTargetSentence("Hello world")
    }
    
    // MARK: - Setup Logic
    
    /// Updates the sentence and generates the required target phonemes using Espeak
    func updateTargetSentence(_ text: String) {
        self.targetSentence = text
        
        // Reset scores to neutral
        self.wordScores = text.split(separator: " ").map {
            WordScore(word: String($0), score: 0.0, alignedPhonemes: [])
        }
        self.overallScore = 0.0
        self.errorMessage = nil
        
        // Generate Ideal Phonemes (The "Truth")
        // EspeakManager returns [[String]], e.g. [["h","ə","l","oʊ"], ["w","ɜː","l","d"]]
        self.idealPhonemes = EspeakManager.shared.getPhonemes(for: text)
        
        print("Target: \(text)")
        print("Ideal Phonemes: \(self.idealPhonemes)")
    }
    
    // MARK: - User Actions
    
    func toggleRecording() {
        if AudioManager.shared.isRecording {
            stopRecordingAndEvaluate()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        self.errorMessage = nil
        self.isLoading = false
        
        // Reset colors to black/neutral before starting
        for i in 0..<wordScores.count {
            wordScores[i].setColor(.black)
        }
        
        do {
            // 2. Try to start, catch failure
            try AudioManager.shared.startRecording()
        } catch {
            print("Start failed: \(error)")
            // 3. Revert UI immediately if start failed
            self.isRecording = false
            self.errorMessage = "Could not access microphone"
        }
    }
    
    func stopRecordingAndEvaluate() {
        // 1. Stop the hardware recording
        AudioManager.shared.stopRecording()
        
        // 2. Start the Processing Pipeline
        self.isLoading = true
        
        Task {
            do {
                // A. Get Raw Predictions from CoreML Model
                // AudioManager returns chunks [[PhonemePrediction]], so we flatten them into one stream
                let chunkedPredictions = try await AudioManager.shared.recognizePhonemesFromLastRecording()
                let decodedPhonemes = chunkedPredictions.flatMap { $0 }
                
                // B. Align and Score (The "Math")
                let result = PronunciationScorer.shared.alignAndScore(
                    decodedPhonemes: decodedPhonemes,
                    targetSentence: self.targetSentence
                )
                
                // C. Update UI
                self.overallScore = result.totalScore
                
                // Update individual words with colors
                var processedWordScores = result.wordScores
                for i in 0..<processedWordScores.count {
                    let score = processedWordScores[i].score
                    let color = self.scoreColor(score)
                    processedWordScores[i].setColor(color)
                    processedWordScores[i].evaluated()
                }
                
                self.wordScores = processedWordScores
                self.isLoading = false
                
            } catch {
                print("Evaluation Error: \(error)")
                self.errorMessage = "Could not analyze audio. Please try again."
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Determines color based on score (0.0 - 1.0)
    private func scoreColor(_ score: Double) -> Color {
        let percentage = score * 100
        switch percentage {
        case 85...100: return .green
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}
