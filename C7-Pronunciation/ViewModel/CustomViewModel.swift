//
//  CustomViewModel.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import Foundation
import SwiftUI
import Combine

class CustomViewModel: ObservableObject {
    
    // Dependencies
    private let audioManager = AudioManager.shared
    private let espeakManager = EspeakManager.shared
    private let scorer = PronunciationScorer.shared
    
    @Published var targetSentence: String = "I don't work simultaneously. I'm starting to think about it. But, I don't like it."
    @Published var decodedPhonemes: [[PhonemePrediction]] = [[]]
    @Published var idealPhonemes: [[String]] = [[]]
    @Published var evalResults: PronunciationEvalResult?
    
    // State vars
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRecording = false
    
    func setTargetSentence(_ sentence: String) {
        targetSentence = sentence
    }
    
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
