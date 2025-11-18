//
//  EvaluationCardView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import SwiftUI

struct EvaluationCardView: View {
    let sentence: String
    let wordScores: [WordScore]
    var onTapWord: (WordScore) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            interactiveUnderlinedText(fullText: sentence, wordScores: wordScores, onTap: onTapWord)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemGray6)))
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

            for (index, w) in cleanedWords.enumerated() {
                if index < cleanedScores.count, cleanedScores[index] == w {
                    indexedScores[index] = wordScores[index]
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
