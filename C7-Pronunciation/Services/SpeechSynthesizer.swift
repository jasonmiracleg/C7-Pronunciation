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
    static let shared = SpeechSynthesizer()
    
    private let synthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()

    private init() {}

    func speak(text: String, language: String = "en-US") {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session for speech: \(error.localizedDescription)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-US")
        
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.6
        utterance.pitchMultiplier = 1.0

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        synthesizer.speak(utterance)
    }
}
