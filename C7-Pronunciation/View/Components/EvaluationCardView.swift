//
//  EvaluationCardView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import SwiftUI

struct EvaluationCardView: View {
    let result: PronunciationEvalResult
    var onTapWord: (WordScore) -> Void
    
    private var errorCount: Int {
        result.wordScores.filter { $0.score < 0.6 }.count
    }
    
    private var hasErrors: Bool {
        errorCount > 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                interactiveUnderlinedText(
                    fullText: result.sentenceText!,
                    wordScores: result.wordScores,
                    onTap: onTapWord
                )
                
                Spacer(minLength: 0)
                
                // Speaker (TTS) button
                Button(action: {
                    SpeechSynthesizer.shared.speak(text: result.sentenceText ?? "")
                }) {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.white)
                }
                .glassEffect(.regular.tint(Color.accentColor))
                .padding(.leading, 4)
            }
            
            // Caption
            HStack {
                Spacer()
                Text(hasErrors ? "\(errorCount) Error\(errorCount == 1 ? "" : "s")" : "Perfect Pronunciation!")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(hasErrors ? Color("SoftOrange") : Color("SoftGreen"))
        )
    }
        
    func clean(_ word: String) -> String {
        word
            .replacingOccurrences(of: "â€™", with: "'")
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
                .replacingOccurrences(of: "â€™", with: "'")
                .split(separator: " ")
                .map { String($0) }

            let cleanedWords = words.map { clean($0) }
            let cleanedScores = wordScores.map { clean($0.word) }

            var scoreIndex = 0
            for (index, w) in cleanedWords.enumerated() {
                if scoreIndex < cleanedScores.count {
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
                    .font(.title3)
                    .underline(true, color: .red)
                    .foregroundColor(Color.red)
                    .onTapGesture { onTap(score) }
            } else {
                Text(item.word + " ")
                    .font(.title3)
            }
        }
    }
}
