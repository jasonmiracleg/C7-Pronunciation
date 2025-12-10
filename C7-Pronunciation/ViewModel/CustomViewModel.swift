//
//  CustomViewModel.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import Foundation
import SwiftUI
import Combine
import Speech
import AVFoundation

class CustomViewModel: ObservableObject {
    
    // Dependencies
    private let audioManager = AudioManager.shared
    private let scorer = PronunciationScorer.shared
    
    @Published var targetSentence: String = "I don't work simultaneously. I'm starting to think about it. But, I don't like it."
    @Published var decodedPhonemes: [[PhonemePrediction]] = [[]]
    @Published var idealPhonemes: [[String]] = [[]]
    @Published var sentenceResults: [PronunciationEvalResult] = []
    
    // MARK: - Waveform State
    // 30 bars for the visualizer
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 30)
    private var meteringTimer: Timer?
    
    // MARK: - Teleprompter State
    @Published var teleprompterSentences: [String] = []
    @Published var currentSentenceIndex: Int = 0
    @Published var shouldAutoScroll: Bool = true
    @Published var recognizedText: String = ""
    
    private var recordingStartTime: Date?
    var autoScrollTimer: Timer?
    private var cumulativeWordBuffer: [String] = []
    
    @Published var wordsPerMinute: Double = 120.0
    var currentSentenceStartTime: Date? = nil
    var lastSentenceAdvanceTime: Date?
    private let minimumSecondsBetweenAdvances: TimeInterval = 2.5  // Minimum time between sentence advances
    private let averageWordsPerSecond: Double = 1

    
    // Speech recognition for teleprompter
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var audioEngine: AVAudioEngine?
    
    // MARK: - Initialization
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.defaultTaskHint = .dictation
        requestSpeechPermissions()
    }
    
    private func requestSpeechPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("❌ Speech recognition not authorized")
                @unknown default:
                    break
                }
            }
        }
    }
    
    // State vars
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRecording = false
    @Published var hasRecorded = false
    
    func setTargetSentence(_ sentence: String) {
        targetSentence = sentence
    }
    
    func resetTeleprompter() {
        teleprompterSentences = []
        currentSentenceIndex = 0
        shouldAutoScroll = true
        recognizedText = ""
        cumulativeWordBuffer = []
        recordingStartTime = nil
        hasRecorded = false
    }
    
    func toggleRecording() {
        HapticsManager.shared.playRecordHaptic()
        if audioManager.isRecording {
            isRecording = false
//            print("🎙️ Stopping recording...")
            
            stopMetering()
            stopSpeechRecognition()
            audioManager.stopRecording()
            
            isLoading = true
            
            Task {
                await submitRecording()
            }
        } else {
            isRecording = true
            hasRecorded = true
//            print("🎙️ Starting recording...")
            resetResults()
            startMetering()
            startSpeechRecognition()
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
        // Reset visualization to flat immediately
        audioLevels = Array(repeating: 0.0, count: 30)
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
        // Check if file exists
        guard let audioURL = audioManager.audioURL else {
            await MainActor.run {
                self.errorMessage = "Recording not found."
                // SAFETY: If we fail early, we must turn off loading
                self.isLoading = false
            }
            return
        }
        
        // NOTE: We removed "self.isLoading = true" from here because
        // we now do it in toggleRecording()
        
        do {
            let result = try await audioManager.recognizePhonemes(from: audioURL)
            
            await MainActor.run {
                self.decodedPhonemes = result
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("❌ Evaluation failed - isLoading = false")
            }
            print("✗ Test failed: \(error.localizedDescription)")
            return
        }
        
        let masterResult = scorer.alignAndScore(decodedPhonemes: decodedPhonemes.flatMap { $0 }, targetSentence: self.targetSentence)
        
        await MainActor.run {
            processSentences(fullText: self.targetSentence, allWordScores: masterResult.wordScores)
            print("✅ Evaluation complete - isLoading = false")
            
            // 4. Finally turn off loading, which triggers the Navigation in the View
            self.isLoading = false
        }
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
                if average < ERROR_THRESHOLD && !cleanSentence.isEmpty && cleanSentence.count >= 50 {
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
        
        // Directly update published property (Caller is already on MainActor)
        self.sentenceResults = results
        
        for phrase in phrasesToSave {
            print("Auto-saving low scoring phrase: \(phrase)")
            DataBankManager.shared.addUserPhrase(phrase)
        }
    }
    
    func resetResults() {
        sentenceResults = []
        errorMessage = nil
    }
}
