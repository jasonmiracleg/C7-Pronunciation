//
//  EvaluationCardView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import SwiftUI

struct EvaluationCardView: View {
    // Changed input to the result object
    let result: PronunciationEvalResult
    var onTapWord: (WordScore) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Interactive Text
            interactiveUnderlinedText(
                fullText: result.sentenceText!,
                wordScores: result.wordScores,
                onTap: onTapWord
            )
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemGray6)))
    }
    
    func getColor(score: Double) -> Color {
        if score >= 85 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
    
    func clean(_ word: String) -> String {
        word
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
    }
    
    @ViewBuilder
    func interactiveUnderlinedText(
        fullText: String,
        wordScores: [WordScore],
        onTap: @escaping (WordScore) -> Void
    ) -> some View {

        var indexedScores: [Int: WordScore] = [:]
        var words: [String] = []

        let _ = {
            words = fullText
                .replacingOccurrences(of: "’", with: "'")
                .split(separator: " ")
                .map { String($0) }

            let cleanedWords = words.map { clean($0) }
            let cleanedScores = wordScores.map { clean($0.word) }

            // Logic to map scores to words; handles punctuation differences
            var scoreIndex = 0
            for (index, w) in cleanedWords.enumerated() {
                if scoreIndex < cleanedScores.count {
                     // Simple matching: checks if the cleaned words match
                    if cleanedScores[scoreIndex] == w {
                        indexedScores[index] = wordScores[scoreIndex]
                        scoreIndex += 1
                    }
                }
            }
        }()

        FlexibleFlowLayout(
            data: words.enumerated().map { WordItem(index: $0.offset, word: $0.element) }
        ) { item in
            if let score = indexedScores[item.index], score.score < 0.6 {
                Text(item.word + " ")
                    .underline()
                    .foregroundColor(score.score < 0.4 ? .red : .orange)
                    .onTapGesture { onTap(score) }
            } else {
                Text(item.word + " ")
            }
        }
    }
}
