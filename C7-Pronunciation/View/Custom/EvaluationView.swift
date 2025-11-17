//
//  EvaluationView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import SwiftUI

struct EvaluationView: View {
    @Environment(\.dismiss) private var dismiss

    let dummyWordScores: [WordScore] = [

        WordScore(
            word: "simultaneously",
            score: 0.52,  // ❌ will be underlined red
            alignedPhonemes: [
                AlignedPhoneme(
                    type: .replace,
                    target: "ˌsaɪ.məlˈteɪ.ni.əs.li",
                    actual: "sa.məl.te.ni.li",
                    score: 0.5,
                    note: "Mispronounced vowel"
                )
            ]
        ),

        WordScore(
            word: "excited",
            score: 0.93,  // ✅ correct
            alignedPhonemes: [
                AlignedPhoneme(
                    type: .match,
                    target: "ɪkˈsaɪ.tɪd",
                    actual: "ɪkˈsaɪ.tɪd",
                    score: 0.95,
                    note: nil
                )
            ]
        ),

        WordScore(
            word: "and",
            score: 0.99,
            alignedPhonemes: [
                AlignedPhoneme(
                    type: .match,
                    target: "ænd",
                    actual: "ænd",
                    score: 1.0,
                    note: nil
                )
            ]
        ),

        WordScore(
            word: "completely",
            score: 0.88,
            alignedPhonemes: [
                AlignedPhoneme(
                    type: .match,
                    target: "kəmˈpliːt.li",
                    actual: "kəmˈpliːt.li",
                    score: 0.9,
                    note: nil
                )
            ]
        ),

        WordScore(
            word: "anxious",
            score: 0.63,  // ❌ incorrect
            alignedPhonemes: [
                AlignedPhoneme(
                    type: .replace,
                    target: "ˈæŋk.ʃəs",
                    actual: "æŋ.səs",
                    score: 0.6,
                    note: "Incorrect consonant cluster"
                )
            ]
        ),
    ]

    let testSentence =
        "I’m in that strange phase of the prototype where I’m simultaneously excited and completely anxious."

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Press the underlined words to see the correct pronunciation")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(UIColor.systemGray2))
                
                // Scrollable cards
                ScrollView {
                    VStack() {
                        ForEach(0..<10) { _ in
                            EvaluationCardView(
                                sentence: testSentence,
                                wordScores: dummyWordScores
                            ) { selectedWord in
                                print("Tapped: \(selectedWord.word)")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .navigationTitle("Evaluation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    EvaluationView()
}
