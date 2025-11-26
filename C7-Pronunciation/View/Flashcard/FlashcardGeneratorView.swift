import SwiftUI

struct FlashcardGeneratorView: View {
    @ObservedObject var viewModel: FlashcardViewModel
    
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
            
            // Logo
            Image("card_logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 48)
                .opacity(0.1)
            
            // Main Content
            VStack{
                Image("congratulations")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 100)

                VStack{
                    Text("Congratulations")
                        .font(.title3)
                        .bold()
                    
                    Text("You have successfully practiced ")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    + Text("\(viewModel.cardsPerCycle) flashcards")
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .bold()
                    
                    Text("Tap the button below to start a new set of flash cards")
                        .padding(.top, 32)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

            }
            .multilineTextAlignment(.center)   // centers all text inside
            .frame(maxWidth: .infinity)
            
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

    FlashcardGeneratorView(viewModel: vm)
        .padding(.top, 40)
        .padding(.horizontal, 24)
        .frame(height: 400)
}
