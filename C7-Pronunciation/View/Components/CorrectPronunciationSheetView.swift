//
//  CorrectPronunciationSheetView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 18/11/25.
//  Updated to show human-readable pronunciation respelling
//

import SwiftUI
import AVFoundation

struct CorrectPronunciationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let wordScore: WordScore
    
    /// Toggle between IPA and respelling display
    @State private var showIPA: Bool = false
    
    private let synthesizer = SpeechSynthesizer.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    // Word with color-coded letters
                    HStack(spacing: 0) {
                        let chars = Array(wordScore.word)
                        ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                            Text(String(char))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(getLetterColor(letterIndex: index, totalLetters: chars.count))
                        }
                    }
                    
                    Text("/ " + wordScore.respelling.lowercased() + " /")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Playback Button
                Button(action: {
                    SpeechSynthesizer.shared.speak(text: wordScore.word.lowercased())
                }) {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }
                .glassEffect(.regular.tint(Color.accentColor))
            }
            .navigationTitle("Evaluation Detail")
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
    
    // MARK: - Pronunciation Breakdown View
    
    /// Shows each sound with its IPA and respelling
    private var pronunciationBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sound by Sound")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(wordScore.alignedPhonemes.enumerated()), id: \.offset) { index, aligned in
                        if let target = aligned.target {
                            VStack(spacing: 4) {
                                // Respelling
                                Text(PronunciationRespeller.shared.convertPhoneme(target).uppercased())
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(colorForScore(aligned.score))
                                
                                // IPA (smaller)
                                Text(target)
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minWidth: 36)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorForScore(aligned.score).opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Functions
    
    /// Returns color based on phoneme score
    private func colorForScore(_ score: Double) -> Color {
        if score < ERROR_THRESHOLD / 2 {
            return .red
        } else if score < ERROR_THRESHOLD {
            return .orange
        } else {
            return .primary
        }
    }
    
    /// Maps a letter's position to the corresponding phoneme score
    func getLetterColor(letterIndex: Int, totalLetters: Int) -> Color {
        let phonemes = wordScore.alignedPhonemes
        guard !phonemes.isEmpty else { return .primary }
        
        let position = Double(letterIndex) / Double(totalLetters)
        let phonemeIndex = Int(position * Double(phonemes.count))
        let safeIndex = min(max(phonemeIndex, 0), phonemes.count - 1)
        let score = phonemes[safeIndex].score
        
        return colorForScore(score)
    }
}
