import SwiftUI

struct FlashcardView: View {
    @ObservedObject var viewModel: FlashcardViewModel
    var onPlayAudio: () -> Void
    
    var onTapWord: (WordScore) -> Void
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.tertiarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.accentColor, lineWidth: 6)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            
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
            
            VStack {
                HStack {
                    Color.clear
                        .frame(height: 36)
                        .frame(width: 50)
                        .layoutPriority(1)
                    
                    Spacer()

                    Text("\(viewModel.currentCardNumber) of \(viewModel.cardsPerCycle)")
                        .foregroundColor(Color.secondary)
                    
                    Spacer()


                    Button(action: onPlayAudio) {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    .glassEffect(.regular.tint(Color.accent))

                }
                .padding(.top, 16)
                .padding(.horizontal, 16)

                Spacer()
            }
            
            // CTA Text
            if viewModel.isEvaluated {
                let hasErrors = viewModel.wordScores.contains { $0.score <= ERROR_THRESHOLD }
                
                VStack {
                    Spacer()
                    
                    if hasErrors {
                        // Default
                        Text("Tap on the underlined words to see evaluation details.")
                            .foregroundColor(Color.secondary)
                    } else {
                        // No errors
                        Text("Perfect Pronunciation! Great Job.")
                            .foregroundColor(.correctPronunciation)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color("SoftGreen"))
                            )
                    }
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)
                
                .padding(.bottom, 24)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
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

// MARK: - Preview Mock Data

private let mockWordScores: [WordScore] = [
    WordScore(word: "Hello", score: 0.9, alignedPhonemes: []),
    WordScore(word: "world", score: 0.3, alignedPhonemes: [])
]

// MARK: - Preview Provider

#Preview {
    let vm = FlashcardViewModel()
    vm.wordScores = mockWordScores
    vm.isEvaluated = true

    return FlashcardView(
        viewModel: vm,
        onPlayAudio: {},
        onTapWord: { _ in }
    )
    .padding(.top, 40)
    .padding(.horizontal, 24)
    .frame(height: 400)
}
