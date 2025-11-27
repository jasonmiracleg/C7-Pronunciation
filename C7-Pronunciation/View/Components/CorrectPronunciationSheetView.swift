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
    
    /// Toggle for expandable breakdown
    @State private var showBreakdown: Bool = false
    
    private let synthesizer = SpeechSynthesizer.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        // Word with color-coded letters
                        HStack(spacing: 0) {
                            let chars = Array(wordScore.word)
                            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                                Text(String(char))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(getLetterColor(letterIndex: index, totalLetters: chars.count))
                            }
                        }
                        
                        // Ideal pronunciation (NOT spaced, original format)
                        Text("/ " + wordScore.respelling.lowercased() + " /")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
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
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Error details section
                    VStack(spacing: 0) {
                        Divider()
                        
                        // Expandable button with clear label
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                showBreakdown.toggle()
                            }
                        }) {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Error Details")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    
                                    Image(systemName: showBreakdown ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                                
                                if hasErrors {
                                    Text("\(majorErrorCount) issue\(majorErrorCount == 1 ? "" : "s") detected")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if showBreakdown {
                            errorDetailsSection
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("Evaluation Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
    
    // MARK: - Error Details Section
    
    /// Complete error details with phoneme comparison
    private var errorDetailsSection: some View {
        VStack(spacing: 16) {
            // Expected phonemes (spaced)
            VStack(spacing: 4) {
                Text("Expected:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Text(idealPhonemeStringSpaced)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            
            // Actual phonemes (spaced, with highlighting)
            VStack(spacing: 4) {
                Text("You said:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                actualPhonemesHighlighted
                    .font(.system(.body, design: .monospaced))
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Error messages (without cards)
            if hasErrors {
                VStack(spacing: 8) {
                    ForEach(majorErrors, id: \.offset) { index, aligned in
                        errorMessage(aligned: aligned)
                    }
                }
            }
        }
        .padding()
    }
    
    /// Highlighted actual phonemes with errors in color
    private var actualPhonemesHighlighted: some View {
        let phonemes = wordScore.alignedPhonemes
        
        return HStack(spacing: 4) {
            ForEach(Array(phonemes.enumerated()), id: \.offset) { index, aligned in
                if aligned.type == .delete {
                    // Skip deletions (missing sounds don't appear in "you said")
                    EmptyView()
                } else if let actual = aligned.actual {
                    let isError = aligned.score < ERROR_THRESHOLD / 2 || aligned.type == .insert
                    let respelled = PronunciationRespeller.shared.convertPhoneme(actual).lowercased()
                    
                    Text(respelled)
                        .foregroundStyle(isError ? .red : .primary)
                        .fontWeight(isError ? .semibold : .regular)
                }
            }
        }
    }
    
    /// Simple error message without card
    private func errorMessage(aligned: AlignedPhoneme) -> some View {
        HStack(spacing: 4) {
            Image(systemName: errorIcon(aligned: aligned))
                .foregroundStyle(errorColor(aligned: aligned))
                .font(.subheadline)
            
            errorMessageText(aligned: aligned)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Generate error message text
    @ViewBuilder
    private func errorMessageText(aligned: AlignedPhoneme) -> some View {
        switch aligned.type {
        case .match, .replace:
            if let target = aligned.target, let actual = aligned.actual {
                Text("Expected '\(PronunciationRespeller.shared.convertPhoneme(target).lowercased())', heard '\(PronunciationRespeller.shared.convertPhoneme(actual).lowercased())'")
            }
            
        case .delete:
            if let target = aligned.target {
                Text("Missing '\(PronunciationRespeller.shared.convertPhoneme(target).lowercased())'")
            }
            
        case .insert:
            if let actual = aligned.actual {
                Text("Heard an extra '\(PronunciationRespeller.shared.convertPhoneme(actual).lowercased())'")
            }
        }
    }
    
    /// Error icon
    private func errorIcon(aligned: AlignedPhoneme) -> String {
        switch aligned.type {
        case .match, .replace:
            return "xmark.circle.fill"
        case .delete:
            return "xmark.circle.fill"
        case .insert:
            return "plus.circle.fill"
        }
    }
    
    /// Error color
    private func errorColor(aligned: AlignedPhoneme) -> Color {
        switch aligned.type {
        case .match, .replace:
            return .red
        case .delete:
            return .red
        case .insert:
            return .orange
        }
    }
    
    // MARK: - Helper Properties
    
    /// Check if there are any major errors
    private var hasErrors: Bool {
        !majorErrors.isEmpty
    }
    
    /// Count of major errors
    private var majorErrorCount: Int {
        majorErrors.count
    }
    
    /// List of major errors (excluding minor differences)
    private var majorErrors: [(offset: Int, element: AlignedPhoneme)] {
        wordScore.alignedPhonemes.enumerated().filter { index, aligned in
            if aligned.type == .delete || aligned.type == .insert {
                return true
            }
            return aligned.score < ERROR_THRESHOLD / 2
        }
    }
    
    /// The ideal pronunciation with spaces between phonemes
    private var idealPhonemeStringSpaced: String {
        let targetPhonemes = wordScore.alignedPhonemes.compactMap { $0.target }
        return targetPhonemes.map { PronunciationRespeller.shared.convertPhoneme($0).lowercased() }.joined(separator: " ")
    }
    
    /// Returns color based on phoneme score
    private func colorForScore(_ score: Double) -> Color {
        if score >= ERROR_THRESHOLD {
            return .primary
        } else if score >= ERROR_THRESHOLD / 2 {
            return .orange
        } else {
            return .red
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
