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
    private let espeakManager = EspeakManager.shared
    private let scorer = PronunciationScorer.shared
    
    @Published var targetSentence: String = "Good morning. My name is Jason."
    @Published var decodedPhonemes: [[PhonemePrediction]] = [[]]
    @Published var idealPhonemes: [[String]] = [[]]
    @Published var evalResults: PronunciationEvalResult?
    
    // State vars
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRecording = false
    
    func toggleRecording() {
        if audioManager.isRecording {
            isRecording = false
            audioManager.stopRecording()
            // Automatically submit after stopping
            Task {
                await submitRecording()
            }
        } else {
            isRecording = true
            resetResults()
            audioManager.startRecording()
        }
    }
    
    private func submitRecording() async {
        guard let audioURL = audioManager.audioURL else {
            self.errorMessage = "Recording not found."
            return
        }
        
        self.isLoading = true
        
        // GET INFERED PHONEMES FROM MODEL; GET IDEAL PHONEMES FROM ESPEAK
        do {
            // Check if AudioManager is ready
            guard audioManager.isPhonemeRecognitionReady else {
                throw NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "AudioManager is not ready. Check model/vocab."])
            }
            
            print("Found test file: \(audioURL.lastPathComponent)")
            
            // 2. Call the new test method on AudioManager
            let result = try await audioManager.recognizePhonemes(from: audioURL)
            
            self.decodedPhonemes = result
            self.idealPhonemes = espeakManager.getPhonemes(for: self.targetSentence)
            print(self.idealPhonemes)
            self.isLoading = false
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            print("✗ Test failed: \(error.localizedDescription)")
        }
        
        self.isLoading = false
        self.evalResults = scorer.alignAndScore(decodedPhonemes: decodedPhonemes.flatMap { $0 }, idealPhonemes: idealPhonemes, targetSentence: self.targetSentence)
        
        print("Total Score: \(self.evalResults!.totalScore)")
        print("\nWord Scores:")
        for wordScore in self.evalResults!.wordScores {
            print("  \(wordScore.word): \(wordScore.score)")
        }
    }
    
    func resetResults() {
        evalResults = nil
        errorMessage = nil
    }
}
