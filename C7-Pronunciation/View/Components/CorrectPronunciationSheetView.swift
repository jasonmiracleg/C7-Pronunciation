//
//  CorrectPronunciationSheetView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 18/11/25.
//

import SwiftUI
import AVFoundation

struct CorrectPronunciationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let wordScore: WordScore
    
    // TTS for the speaker button (Playback)
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 24) {
                Text(wordScore.word)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Button(action: {
                    speak(text: wordScore.word.lowercased())
                }) {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .glassEffect( .regular.tint(Color.interactive))
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("Correct Pronunciation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
    
    func speak(text: String) {
        // Stop any previous speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Slightly slower for practice
        synthesizer.speak(utterance)
    }
}
