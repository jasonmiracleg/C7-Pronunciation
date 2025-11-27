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
                    .padding(.vertical, 16)
                    
                    // Error details section
                    VStack(spacing: 0) {
                        Divider()
                                                
                        errorDetailsSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .padding(.top, 8)
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
            // Aligned phoneme display
            VStack(spacing: 8) {
                // Expected phonemes
                VStack {
                    Text("Expected: ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Text(alignedExpectedString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                
                // Actual phonemes
                VStack {
                    Text("You said: ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    alignedActualText
                        .font(.system(.body, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // Error messages (without cards)
            if hasErrors {
                VStack(spacing: 8) {
                    ForEach(majorErrors, id: \.offset) { index, aligned in
                        errorMessage(aligned: aligned)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding()
    }
    
    /// Aligned actual phonemes with proper spacing to match expected
    private var alignedActualText: some View {
        let segments = getAlignedSegments()
        
        return HStack(spacing: 0) {
            ForEach(Array(segments.actual.enumerated()), id: \.offset) { index, segment in
                Text(segment.text)
                    .foregroundStyle(segment.color)
                    .fontWeight(segment.isBold ? .semibold : .regular)
            }
        }
    }
    
    // MARK: - Alignment Logic
    
    struct PhonemeSegment {
        let text: String
        let color: Color
        let isBold: Bool
    }
    
    /// Calculate aligned segments for both expected and actual phonemes
    private func getAlignedSegments() -> (expected: [PhonemeSegment], actual: [PhonemeSegment]) {
        let phonemes = wordScore.alignedPhonemes
        var expectedSegments: [PhonemeSegment] = []
        var actualSegments: [PhonemeSegment] = []
        
        for (index, aligned) in phonemes.enumerated() {
            let isError = aligned.score < ERROR_THRESHOLD / 2 || aligned.type == .insert
            
            // Get respellings
            let targetRespelled = aligned.target.map { PronunciationRespeller.shared.convertPhoneme($0).lowercased() } ?? ""
            let actualRespelled = aligned.actual.map { PronunciationRespeller.shared.convertPhoneme($0).lowercased() } ?? ""
            
            // Determine max width for this position
            let maxWidth = max(targetRespelled.count, actualRespelled.count)
            
            switch aligned.type {
            case .delete:
                // Missing sound: expected shows phoneme, actual shows underscore
                let paddedTarget = targetRespelled.padding(toLength: maxWidth, withPad: " ", startingAt: 0)
                let paddedActual = "_".padding(toLength: maxWidth, withPad: " ", startingAt: 0)
                
                expectedSegments.append(PhonemeSegment(
                    text: paddedTarget + " ",
                    color: .primary,
                    isBold: false
                ))
                actualSegments.append(PhonemeSegment(
                    text: paddedActual + " ",
                    color: .red,
                    isBold: true
                ))
                
            case .insert:
                // Extra sound: expected shows spaces, actual shows phoneme
                let paddedTarget = "".padding(toLength: maxWidth, withPad: " ", startingAt: 0)
                let paddedActual = actualRespelled.padding(toLength: maxWidth, withPad: " ", startingAt: 0)
                
                expectedSegments.append(PhonemeSegment(
                    text: paddedTarget + " ",
                    color: .primary,
                    isBold: false
                ))
                actualSegments.append(PhonemeSegment(
                    text: paddedActual + " ",
                    color: .orange,
                    isBold: true
                ))
                
            case .match, .replace:
                // Normal or mispronounced: both show phonemes, padded to same width
                let paddedTarget = targetRespelled.padding(toLength: maxWidth, withPad: " ", startingAt: 0)
                let paddedActual = actualRespelled.padding(toLength: maxWidth, withPad: " ", startingAt: 0)
                
                expectedSegments.append(PhonemeSegment(
                    text: paddedTarget + " ",
                    color: .primary,
                    isBold: false
                ))
                actualSegments.append(PhonemeSegment(
                    text: paddedActual + " ",
                    color: isError ? .red : .primary,
                    isBold: isError
                ))
            }
        }
        
        return (expectedSegments, actualSegments)
    }
    
    /// Build aligned expected string
    private var alignedExpectedString: String {
        let segments = getAlignedSegments()
        return segments.expected.map { $0.text }.joined()
    }
    
    /// Simple error message without card
    private func errorMessage(aligned: AlignedPhoneme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: errorIcon(aligned: aligned))
                .foregroundStyle(errorColor(aligned: aligned))
                .font(.body)
            
            errorMessageText(aligned: aligned)
                .font(.body)
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
