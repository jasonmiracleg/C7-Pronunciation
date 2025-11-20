//
//  CustomViewModel+Teleprompter.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import Foundation
import Speech
import AVFoundation
import SwiftUI

extension CustomViewModel {
    
    // MARK: - Teleprompter Setup
    
    func prepareTeleprompter(with text: String) {
        teleprompterSentences = parseSentences(from: text)
        currentSentenceIndex = 0
        shouldAutoScroll = true
        recognizedText = ""
        
        // Initialize timing
        currentSentenceStartTime = Date()
        
        print("📝 Teleprompter prepared with \(teleprompterSentences.count) sentences")
    }
    
    func userIsScrolling() {
        shouldAutoScroll = false
        resetAutoScrollTimer()
    }
    
    func resetAutoScrollTimer() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.shouldAutoScroll = true
        }
    }

    // MARK: - The Time-Gated Logic Core
    
    func processTeleprompterLogic(spokenText: String) {
        guard !teleprompterSentences.isEmpty, currentSentenceIndex < teleprompterSentences.count else { return }
        
        // 1. Safety Check: Ensure we have a start time
        guard let startTime = currentSentenceStartTime else {
            currentSentenceStartTime = Date()
            return
        }
        
        // 2. Calculate Time Windows
        let currentSentence = teleprompterSentences[currentSentenceIndex]
        let wordCount = Double(currentSentence.components(separatedBy: .whitespaces).count)
        
        // Math: Calculate expected duration based on WPM
        // 60 seconds / WPM = Seconds per word
        let secondsPerWord = 60.0 / self.wordsPerMinute
        let expectedDuration = wordCount * secondsPerWord
        
        // MIN DURATION: 50% of expected time + 1s buffer.
        // (e.g., if sentence takes 4s, don't jump before 3s)
        let minDuration = (expectedDuration * 0.5) + 1.0
        
        // MAX DURATION: 250% of expected time + 2s buffer.
        // (e.g., if sentence takes 4s, force jump after 12s)
        let maxDuration = (expectedDuration * 2.5) + 2.0
        
        let timeElapsed = Date().timeIntervalSince(startTime)
        
        // --- GATE 1: TOO EARLY (The "Double Jump" Preventer) ---
        if timeElapsed < minDuration {
            // We haven't been on this sentence long enough.
            // Ignore all matching to prevent accidental double-jumps.
            return
        }
        
        // --- GATE 2: TIMEOUT (The "Stuck" Preventer) ---
        if timeElapsed > maxDuration {
            print("⏰ Auto-Advanced: Max duration exceeded")
            advanceSentence()
            return
        }
        
        // --- GATE 3: TEXT MATCHING (The Normal Flow) ---
        // Only if we are in the "Goldilocks Zone" (Between Min and Max time)
        // do we actually check the spoken text.
        
        checkForTextTriggers(spokenText: spokenText, currentSentence: currentSentence)
    }
    
    private func checkForTextTriggers(spokenText: String, currentSentence: String) {
        let currentWords = normalizeText(currentSentence).components(separatedBy: " ")
        let spokenWords = normalizeText(spokenText).components(separatedBy: " ")
        let recentSpokenWords = Array(spokenWords.suffix(20))
        
        var shouldAdvance = false
        
        // 1. Lookahead (Start of NEXT sentence)
        if currentSentenceIndex + 1 < teleprompterSentences.count {
            let nextSentence = teleprompterSentences[currentSentenceIndex + 1]
            let nextWords = normalizeText(nextSentence).components(separatedBy: " ")
            
            let checkCount = min(nextWords.count, 4)
            let nextPrefix = Array(nextWords.prefix(checkCount))
            let requiredMatches = min(2, nextWords.count)
            
            if countMatches(source: nextPrefix, target: recentSpokenWords) >= requiredMatches {
                shouldAdvance = true
                print("🚀 Advanced: Lookahead match")
            }
        }
        
        // 2. Suffix Match (End of CURRENT sentence)
        if !shouldAdvance {
            let suffixLength = min(currentWords.count, 5)
            let currentSuffix = Array(currentWords.suffix(suffixLength))
            let requiredSuffixMatches = max(2, suffixLength - 1)
            
            if countMatches(source: currentSuffix, target: recentSpokenWords) >= requiredSuffixMatches {
                shouldAdvance = true
                print("✅ Advanced: Suffix match")
            }
        }
        
        if shouldAdvance {
            advanceSentence()
        }
    }
    
    private func advanceSentence() {
        // Ensure UI updates on Main Thread
        Task { @MainActor in
            withAnimation {
                currentSentenceIndex += 1
            }
            // RESET THE CLOCK
            currentSentenceStartTime = Date()
            
            // Re-enable autoscroll if user wasn't manually holding it
            if autoScrollTimer == nil {
                shouldAutoScroll = true
            }
        }
    }

    // MARK: - Helpers & Boilerplate
    // (Keep these consistent with previous implementation)
    
    func startSpeechRecognition() {
        // ... (Copy from previous answer: Standard Speech Recognition Setup) ...
        // Ensure you call processTeleprompterLogic(spokenText: text) in the callback
        stopSpeechRecognition()
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine,
              let inputNode = audioEngine.inputNode as AVAudioInputNode? else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 13.0, *) { recognitionRequest.requiresOnDeviceRecognition = true }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                Task { @MainActor in
                    self.recognizedText = result.bestTranscription.formattedString
                    self.processTeleprompterLogic(spokenText: self.recognizedText)
                }
            }
            if error != nil { self.stopSpeechRecognition() }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    func stopSpeechRecognition() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }

    func parseSentences(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        return components.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func countMatches(source: [String], target: [String]) -> Int {
        var matches = 0
        var lastFoundIndex = -1
        for word in source {
            if let index = target.enumerated().first(where: { $0.offset > lastFoundIndex && isFuzzyMatch($0.element, word) })?.offset {
                matches += 1
                lastFoundIndex = index
            }
        }
        return matches
    }
    
    private func normalizeText(_ text: String) -> String {
        return text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func isFuzzyMatch(_ word1: String, _ word2: String) -> Bool {
        if word1 == word2 { return true }
        if abs(word1.count - word2.count) <= 1 && word1.first == word2.first { return true }
        return false
    }
}
