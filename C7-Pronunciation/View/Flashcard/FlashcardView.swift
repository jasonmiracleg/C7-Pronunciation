//
//  FlashcardView.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 17/11/25.
//

import SwiftUI

// MARK: - Card View
struct FlashcardView: View {
    @ObservedObject var viewModel: FlashcardViewModel
    var onPlayAudio: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card Background
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            // Content
            VStack {
                Spacer()
                textFlow(words: viewModel.wordScores)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Speaker
            Button(action: onPlayAudio) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding(24)
            }
        }
    }
    
    @ViewBuilder
    private func textFlow(words: [WordScore]) -> some View {
        if words.isEmpty {
            // Fallback if initialization is slow
            Text(viewModel.targetSentence)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.black)
        } else {
            words.reduce(Text("")) { (result, wordScore) -> Text in
                let separator = result == Text("") ? "" : " "
                return result +
                Text(separator) +
                Text(wordScore.word)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(wordScore.color)
            }
        }
    }
}
