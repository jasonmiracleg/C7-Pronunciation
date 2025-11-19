//
//  FlashcardView.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 17/11/25.
//

import SwiftUI

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
                
                // Using the updated styling logic
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
    
    // MARK: - Coloring Logic
    @ViewBuilder
    private func textFlow(words: [WordScore]) -> some View {
        if words.isEmpty {
            Text(viewModel.targetSentence)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.black)
        } else {
            // Concatenate Text views to allow wrapping
            words.reduce(Text("")) { (result, wordScore) -> Text in
                let separator = result == Text("") ? "" : " "
                
                var textSegment = Text(wordScore.word)
                    .font(.system(size: 28, weight: .medium))
                
                if wordScore.isEvaluated {
                    // Use the color set by the ViewModel based on score ranges
                    // 85-100% = green, 70-85% = blue, 50-70% = orange, <50% = red
                    textSegment = textSegment.foregroundColor(wordScore.color)
                    
                    // Optionally add underline for really poor scores (below 50%)
                    if wordScore.score < 0.5 {
                        textSegment = textSegment.underline(true, color: wordScore.color)
                    }
                } else {
                    // Not yet evaluated - show in neutral black
                    textSegment = textSegment.foregroundColor(.black)
                }
                
                return result + Text(separator) + textSegment
            }
        }
    }
}
