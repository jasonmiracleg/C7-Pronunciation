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
        let secondsPerWord = 60.0 / self.wordsPerMinute
        let expectedDuration = wordCount * secondsPerWord
        
        let minDuration = (expectedDuration * 0.5) + 1.0
        let maxDuration = (expectedDuration * 2.5) + 2.0
        
        let timeElapsed = Date().timeIntervalSince(startTime)
        
        // --- GATE 1: TOO EARLY ---
        if timeElapsed < minDuration { return }
        
        // --- GATE 2: TIMEOUT ---
        if timeElapsed > maxDuration {
            print("⏰ Auto-Advanced: Max duration exceeded")
            advanceSentence()
            return
        }
        
        // --- GATE 3: TEXT MATCHING ---
        checkForTextTriggers(spokenText: spokenText, currentSentence: currentSentence)
    }
    
    private func checkForTextTriggers(spokenText: String, currentSentence: String) {
        let currentWords = normalizeText(currentSentence).components(separatedBy: " ")
        let spokenWords = normalizeText(spokenText).components(separatedBy: " ")
        let recentSpokenWords = Array(spokenWords.suffix(20))
        
        var shouldAdvance = false
        
        // 1. Lookahead
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
        
        // 2. Suffix Match
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
        Task { @MainActor in
            withAnimation {
                currentSentenceIndex += 1
            }
            currentSentenceStartTime = Date()
            
            if autoScrollTimer == nil {
                shouldAutoScroll = true
            }
        }
    }

    // MARK: - Robust Speech Recognition
    
    func startSpeechRecognition() {
        // 1. Clean up any existing tasks first
        stopSpeechRecognition()
        
        // 2. Configure Audio Session (CRITICAL STEP TO PREVENT CRASH)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // .measurement mode optimizes for speech recognition (no signal processing like gain control)
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio Session Error: \(error.localizedDescription)")
            return
        }
        
        // 3. Request Authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }
            if authStatus != .authorized {
                print("❌ Speech recognition not authorized")
                return
            }
            
            // 4. Initialize Engine and Request
            self.audioEngine = AVAudioEngine()
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let audioEngine = self.audioEngine,
                  let recognitionRequest = self.recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            if #available(iOS 13.0, *) { recognitionRequest.requiresOnDeviceRecognition = true }
            
            let inputNode = audioEngine.inputNode
            
            // 5. Setup Recognition Task
            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    Task { @MainActor in
                        self.recognizedText = result.bestTranscription.formattedString
                        self.processTeleprompterLogic(spokenText: self.recognizedText)
                    }
                }
                
                if error != nil || (result?.isFinal ?? false) {
                    self.stopSpeechRecognition()
                }
            }
            
            // 6. Install Tap Safely
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // CRASH FIX: Ensure format is valid before installing tap
            if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
                print("❌ Hardware Error: Invalid Audio Format (0Hz).")
                self.stopSpeechRecognition()
                return
            }
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            // 7. Start Engine
            do {
                audioEngine.prepare()
                try audioEngine.start()
                print("🎙️ Speech Recognition Started")
            } catch {
                print("❌ Audio Engine Start Error: \(error.localizedDescription)")
                self.stopSpeechRecognition()
            }
        }
    }
    
    func stopSpeechRecognition() {
        // Safe Cleanup Order
        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            // Only remove tap if the node actually has one attached
            // Note: Removing tap on a node without one can sometimes throw warnings or errors
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        // Deactivate session to return control to other apps (optional, but good citizenship)
        try? AVAudioSession.sharedInstance().setActive(false)
        
        print("🛑 Speech Recognition Stopped")
    }

    // MARK: - Helpers
    
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
