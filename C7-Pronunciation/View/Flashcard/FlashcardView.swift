import SwiftUI

struct FlashcardView: View {
    @ObservedObject var viewModel: FlashcardViewModel
    var onPlayAudio: () -> Void
    
    var onTapWord: (WordScore) -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.tertiarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.accentColor, lineWidth: 6)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            // Logo
            Image("card_logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 48)
                .opacity(0.15)
            
            // Main Content
            VStack {
                Spacer()
                
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
            
            // Speaker button
            Button(action: onPlayAudio) {
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .glassEffect(.regular.tint(Color.accent))
            .padding(16)
            
            // CTA Text
            if viewModel.isEvaluated {
                Text("Click on the underlined words to see evaluation details.")
                    .font(.subheadline)
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity)
            }
        }
    }
    
    @ViewBuilder
    private func wordView(for wordScore: WordScore) -> some View {
        let isLowScore = wordScore.score <= ERROR_THRESHOLD
        
        Text(wordScore.word)
            .font(.system(size: 28, weight: .medium))
            .foregroundColor(wordScore.color)
            .underline(wordScore.isEvaluated && isLowScore, color: wordScore.color)
            .onTapGesture {
                if wordScore.isEvaluated && isLowScore {
                    onTapWord(wordScore)
                }
            }
    }
}
