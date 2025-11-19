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
    
    var onTapWord: (WordScore) -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card Background
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            // Content
            VStack {
                Spacer()
                
                // 2. Use FlowLayout instead of Text concatenation
                FlowLayout(spacing: 6) {
                    if viewModel.wordScores.isEmpty {
                        // Fallback if no scores yet (just raw text)
                        ForEach(viewModel.targetSentence.split(separator: " ").map(String.init), id: \.self) { word in
                            Text(word)
                                .font(.system(size: 28, weight: .medium))
                        }
                    } else {
                        // Render Evaluated/Scored words
                        ForEach(viewModel.wordScores, id: \.id) { wordScore in
                            wordView(for: wordScore)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Speaker            
            Button(action: onPlayAudio) {
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .glassEffect( .regular.tint(Color.accent))
            .padding(16)
        }
    }
    
    @ViewBuilder
    private func wordView(for wordScore: WordScore) -> some View {
        let isLowScore = wordScore.score <= 0.7
        
        Text(wordScore.word)
            .font(.system(size: 28, weight: .medium))
            // Color logic: If evaluated, use score color. If low score, ensure it's visible.
            .foregroundColor(Color.primary)
            // Underline logic: Only if evaluated and score is bad
            .underline(wordScore.isEvaluated && isLowScore, color: wordScore.color)
            // Interaction logic: Only tappable if evaluated and score is bad
            .onTapGesture {
                if wordScore.isEvaluated && isLowScore {
                    onTapWord(wordScore)
                }
            }
    }
}
