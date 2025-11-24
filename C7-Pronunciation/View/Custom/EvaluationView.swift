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
                Text("Tap on the underlined words to see the correct pronunciation.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(UIColor.systemGray2))
                    .padding(.top)
                
                // Scrollable cards list
                ScrollView {
                    VStack(spacing: 20) {
                        // Iterate over the sentence results array
                        ForEach(viewModel.sentenceResults) { result in
                            EvaluationCardView(result: result) { tapped in
                                selectedWord = tapped
                                showPopOver = true
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
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
