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
        
        // Reset scores to neutral - create initial WordScore objects without evaluation
        self.wordScores = text.split(separator: " ").map {
            var wordScore = WordScore(word: String($0), score: 0.0, alignedPhonemes: [])
            // Don't mark as evaluated yet
            return wordScore
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
        
        // Reset to unevaluated state before starting
        for i in 0..<wordScores.count {
            wordScores[i].isEvaluated = false
        }
        
        AudioManager.shared.startRecording()
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
                
                print("📊 Decoded Phonemes Count: \(decodedPhonemes.count)")
                print("📊 Decoded Phonemes: \(decodedPhonemes.map { $0.topPrediction.phoneme }.joined(separator: " "))")
                
                // B. Align and Score (The "Math")
                let result = PronunciationScorer.shared.alignAndScore(
                    decodedPhonemes: decodedPhonemes,
                    idealPhonemes: self.idealPhonemes,
                    targetSentence: self.targetSentence
                )
                
                print("📊 Total Score: \(result.totalScore)")
                print("📊 Word Scores: \(result.wordScores.map { "\($0.word): \($0.score)" }.joined(separator: ", "))")
                
                // C. Update UI
                self.overallScore = result.totalScore
                
                // FIXED: Update word scores with proper mutation
                self.wordScores = result.wordScores.map { originalWordScore in
                    var wordScore = originalWordScore
                    let color = self.scoreColor(wordScore.score)
                    wordScore.color = color
                    wordScore.isEvaluated = true
                    print("📊 Setting \(wordScore.word) - Score: \(wordScore.score), Color: \(color)")
                    return wordScore
                }
                
                self.isLoading = false
                
            } catch {
                print("❌ Evaluation Error: \(error)")
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
