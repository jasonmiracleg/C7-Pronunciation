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
    
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 16) {
                VStack {
                    HStack(spacing: 0) {
                        let chars = Array(wordScore.word)
                        ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                            Text(String(char))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(getLetterColor(letterIndex: index, totalLetters: chars.count))
                        }
                    }
                    
                    Text("/ " + wordScore.allTargets() + " /")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.bottom)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                
                Divider()
                    .padding(.horizontal)

                // Playback Button
                Button(action: {
                    speak(text: wordScore.word.lowercased())
                }) {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .glassEffect( .regular.tint(Color.interactive))
            }
            .navigationTitle("Evaluation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Color(UIColor.systemGray))
                    }
                }
            }
        }
    }
    
    // MARK: - Letter Coloring Heuristic
    
    /// Maps a letter's position to the corresponding phoneme score
    func getLetterColor(letterIndex: Int, totalLetters: Int) -> Color {
        let phonemes = wordScore.alignedPhonemes
        guard !phonemes.isEmpty else { return .primary } // Fallback if no data
        
        // 1. Calculate percentage position of the letter (e.g., letter 2 of 4 is at 50%)
        // We add 0.5 to center the hit within the letter's duration roughly
        let position = Double(letterIndex) / Double(totalLetters)
        
        // 2. Find which phoneme covers this percentage
        // Example: 3 phonemes. Position 0.5 maps to index 1.5 -> Index 1 (Middle phoneme)
        let phonemeIndex = Int(position * Double(phonemes.count))
        
        // 3. Safety Clamp
        let safeIndex = min(max(phonemeIndex, 0), phonemes.count - 1)
        
        // 4. Get Score
        let score = phonemes[safeIndex].score
        
        // 5. Return Color based on your thresholds
        if score < 0.4 {
            return .red
        } else if score < 0.6 {
            return .orange
        } else {
            return .primary
        }
    }
    
    // MARK: - TTS Logic
    
    func speak(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en")
        utterance.rate = 0.4
        synthesizer.speak(utterance)
    }
}
