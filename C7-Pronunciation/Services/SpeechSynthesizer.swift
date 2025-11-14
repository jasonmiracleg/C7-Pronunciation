//
//  SpeechSynthesizer.swift
//  PronunciationScorer
//
//  Created by Abelito Faleyrio Visese on 12/11/25.
//


import Foundation
import AVFoundation
import Combine

class SpeechSynthesizer: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    // 1. Get the shared audio session
    private let audioSession = AVAudioSession.sharedInstance()

    func speak(word: String, language: String = "en-US") {
        
        // 2. Set and activate the session for playback
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session for speech: \(error.localizedDescription)")
        }

        let utterance = AVSpeechUtterance(string: word)
        
        // Use a high-quality voice
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        
        // Add a fallback in case the voice isn't downloaded
        if utterance.voice == nil {
            print("Warning: Voice for \(language) not found. Using default en-US.")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8 // Speak slightly slower
        utterance.pitchMultiplier = 1.0

        // Stop any previous speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Speak the new word
        synthesizer.speak(utterance)
    }
}
