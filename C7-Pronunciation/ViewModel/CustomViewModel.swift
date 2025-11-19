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
    @Published var sentenceResults: [PronunciationEvalResult] = []
    
    // MARK: - Waveform State
    // 30 bars for the visualizer
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 30)
    private var meteringTimer: Timer?
    
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
            stopMetering() // Stop visualizer
            audioManager.stopRecording()
            Task {
                await submitRecording()
            }
        } else {
            isRecording = true
            resetResults()
            startMetering() // Start visualizer
            audioManager.startRecording()
        }
    }
    
    // MARK: - Metering Logic
    
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
        // Reset visualization to flat
        withAnimation {
            audioLevels = Array(repeating: 0.0, count: 30)
        }
    }
    
    private func updateAudioLevels() {
        // Get real data from AudioManager
        let newLevel = audioManager.currentAveragePower
        
        var current = audioLevels
        current.removeFirst()
        current.append(newLevel)
        
        DispatchQueue.main.async {
            self.audioLevels = current
        }
    }
    
    private func submitRecording() async {
        guard let audioURL = audioManager.audioURL else {
            self.errorMessage = "Recording not found."
            return
        }
        
        self.isLoading = true
        
        do {
            // No need to check isPhonemeRecognitionReady explicitly here if AudioManager handles it,
            // but good for safety.
            
            // Use the restored function
            let result = try await audioManager.recognizePhonemes(from: audioURL)
            
            self.decodedPhonemes = result
            self.idealPhonemes = espeakManager.getPhonemes(for: self.targetSentence)
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            print("✗ Test failed: \(error.localizedDescription)")
            return
        }
        
        self.isLoading = false
        let masterResult = scorer.alignAndScore(decodedPhonemes: decodedPhonemes.flatMap { $0 }, targetSentence: self.targetSentence)
        
        processSentences(fullText: self.targetSentence, allWordScores: masterResult.wordScores)
    }
    
    private func processSentences(fullText: String, allWordScores: [WordScore]) {
        var results: [PronunciationEvalResult] = []
        var phrasesToSave: [String] = []
        var wordIndexOffset = 0
        
        fullText.enumerateSubstrings(in: fullText.startIndex..., options: .bySentences) { (substring, _, _, _) in
            guard let sentence = substring else { return }
            
            var wordCountInSentence = 0
            sentence.enumerateSubstrings(in: sentence.startIndex..., options: .byWords) { _, _, _, _ in
                wordCountInSentence += 1
            }
            
            let endIndex = min(wordIndexOffset + wordCountInSentence, allWordScores.count)
            
            if wordIndexOffset < endIndex {
                let sentenceScores = Array(allWordScores[wordIndexOffset..<endIndex])
                let cleanSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Calculate average
                let total = sentenceScores.reduce(0.0) { $0 + $1.score }
                let average = sentenceScores.isEmpty ? 0.0 : total / Double(sentenceScores.count)
                
                // Auto-save low scores logic
                if average < 0.5 && !cleanSentence.isEmpty {
                    phrasesToSave.append(cleanSentence)
                }
                
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
            
            for phrase in phrasesToSave {
                print("Auto-saving low scoring phrase: \(phrase)")
                DataBankManager.shared.addUserPhrase(phrase)
            }
        }
    }
    
    func resetResults() {
        sentenceResults = []
        errorMessage = nil
    }
}
