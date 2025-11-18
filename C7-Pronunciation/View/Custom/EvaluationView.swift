//
//  EvaluationView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import SwiftUI

struct EvaluationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: CustomViewModel
    @State private var selectedWord: WordScore? = nil
    @State private var showPopOver = false

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
//                        ForEach(0..<10) { _ in
                            EvaluationCardView(
                                sentence: viewModel.targetSentence,
                                wordScores: viewModel.evalResults?.wordScores ?? []
                            ) { tapped in
                                selectedWord = tapped
                                showPopOver = true
                            }
//                        }
                    }
                    .padding(.horizontal)
                }
            }
            .sheet(item: $selectedWord) { word in
                CorrectPronunciationSheetView(wordScore: word)
                    .presentationDetents([.fraction(0.25)])
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
