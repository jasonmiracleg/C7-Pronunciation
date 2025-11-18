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
                            ) { selectedWord in
                                print("Tapped: \(selectedWord.word)")
                            }
//                        }
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
