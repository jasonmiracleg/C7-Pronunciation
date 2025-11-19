//
//  PronunciationViewModel.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//

import Foundation
import SwiftUI
import Combine


class PronunciationViewModel: ObservableObject {
    
    // Dependencies
    private let audioManager = AudioManager.shared
    private let scorer = PronunciationScorer.shared
    
    @Published var targetSentence: String = "Good morning. My name is Jason and I like older women."
    @Published var decodedPhonemes: [[PhonemePrediction]] = [[]]
    @Published var evalResults: PronunciationEvalResult?
    
    // State vars
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRecording = false
    
    func toggleRecording() {
        // 1. Check SELF.isRecording (User Intention), not audioManager.isRecording
        if self.isRecording {
            // STOP LOGIC
            self.isRecording = false
            audioManager.stopRecording()
            
            Task {
                await submitRecording()
            }
        } else {
            // START LOGIC
            self.isRecording = true // Optimistic UI update
            resetResults()
            
            do {
                // 2. Try to start, catch failure
                try audioManager.startRecording()
            } catch {
                print("Start failed: \(error)")
                // 3. Revert UI immediately if start failed
                self.isRecording = false
                self.errorMessage = "Could not access microphone"
            }
        }
    }
    
    private func submitRecording() async {
        guard let audioURL = audioManager.audioURL else {
            self.errorMessage = "Recording not found."
            return
        }
        
        // Verify file exists and has content
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            self.errorMessage = "Recording file not found. Please try again."
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil // Clear previous errors
        
        do {
            guard audioManager.isPhonemeRecognitionReady else {
                throw NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "AudioManager is not ready. Check model/vocab."])
            }
            
            print("Processing file: \(audioURL.lastPathComponent)")
            
            let result = try await audioManager.recognizePhonemes(from: audioURL)
            
            self.decodedPhonemes = result
            
            self.evalResults = scorer.alignAndScore(
                decodedPhonemes: decodedPhonemes.flatMap { $0 },
                targetSentence: self.targetSentence
            )
            
            print("Total Score: \(self.evalResults!.totalScore)")
            print("\nWord Scores:")
            for wordScore in self.evalResults!.wordScores {
                print("  \(wordScore.word): \(wordScore.score)")
            }
            
            self.isLoading = false
            
        } catch {
            self.errorMessage = "Processing failed: \(error.localizedDescription)"
            self.isLoading = false
            print("✗ Processing failed: \(error.localizedDescription)")
        }
    }
    
    func resetResults() {
        evalResults = nil
        errorMessage = nil
    }
}
