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
    
    // Changed: We now store an array of results (one per sentence)
    @Published var sentenceResults: [PronunciationEvalResult] = []
    
    // Keep the master result if needed for overall stats, or ignore
    @Published var overallResult: PronunciationEvalResult?
    
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
        
        do {
            guard audioManager.isPhonemeRecognitionReady else {
                throw NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "AudioManager is not ready."])
            }
            
            let result = try await audioManager.recognizePhonemes(from: audioURL)
            self.decodedPhonemes = result
            self.idealPhonemes = espeakManager.getPhonemes(for: self.targetSentence)
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            return
        }
        
        self.isLoading = false
        
        // 1. Get the master list of WordScores for the whole text
        let masterResult = scorer.alignAndScore(decodedPhonemes: decodedPhonemes.flatMap { $0 }, idealPhonemes: idealPhonemes, targetSentence: self.targetSentence)
        
        // 2. Process into sentences
        processSentences(fullText: self.targetSentence, allWordScores: masterResult.wordScores)
    }
    
    private func processSentences(fullText: String, allWordScores: [WordScore]) {
        var results: [PronunciationEvalResult] = []
        var wordIndexOffset = 0
        
        // Split full text by sentences
        fullText.enumerateSubstrings(in: fullText.startIndex..., options: .bySentences) { (substring, _, _, _) in
            guard let sentence = substring else { return }
            
            // Count how many words are in this specific sentence to slice the master array
            var wordCountInSentence = 0
            sentence.enumerateSubstrings(in: sentence.startIndex..., options: .byWords) { _, _, _, _ in
                wordCountInSentence += 1
            }
            
            // Safety check to prevent index out of bounds
            let endIndex = min(wordIndexOffset + wordCountInSentence, allWordScores.count)
            
            if wordIndexOffset < endIndex {
                // Extract the scores for this sentence
                let sentenceScores = Array(allWordScores[wordIndexOffset..<endIndex])
                
                // Calculate new average for this sentence
                let total = sentenceScores.reduce(0.0) { $0 + $1.score }
                let average = total / Double(sentenceScores.count)
                
                let result = PronunciationEvalResult(
                    totalScore: average,
                    wordScores: sentenceScores,
                    sentenceText: sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                results.append(result)
            }
            
            wordIndexOffset += wordCountInSentence
        }
        
        DispatchQueue.main.async {
            self.sentenceResults = results
        }
    }
    
    func resetResults() {
        sentenceResults = []
        errorMessage = nil
    }
}
