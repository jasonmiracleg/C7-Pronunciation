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
    
    @ViewBuilder
    func interactiveUnderlinedText(
        fullText: String,
        wordScores: [WordScore],
        onTap: @escaping (WordScore) -> Void
    ) -> some View {

        let words = fullText.split(separator: " ").map { String($0) }

        let scoreMap = Dictionary(uniqueKeysWithValues: wordScores.map {
            ($0.word.lowercased(), $0)
        })

        FlexibleFlowLayout(data: words.map { WordItem(word: $0) }) { wordItem in
            let cleaned = wordItem.word
                .trimmingCharacters(in: .punctuationCharacters)
                .lowercased()

            if let score = scoreMap[cleaned], score.score < 0.8 {
                Text(wordItem.word + " ")
                    .underline()
                    .foregroundColor(.red)
                    .onTapGesture { onTap(score) }
            } else {
                Text(wordItem.word + " ")
                    .foregroundColor(.primary)
            }
        }
    }
}
