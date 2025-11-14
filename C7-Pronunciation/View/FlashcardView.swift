//
//  FlashcardPageView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 13/11/25.
//

import Foundation
import SwiftUI

struct FlashcardView: View{
    
    @StateObject var viewModel = FlashcardViewModel()
    
    var body: some View{
        
        VStack{
            coloredSentence(from: viewModel.dummyWords)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Evaluate"){
                viewModel.evaluateDummy()
            }
        }
        
    }
    
    func coloredSentence(from words: [WordScore]) -> Text {
        words.enumerated().map { index, word in
            // Add a space *after* every word except the last one
            let displayedText = index == words.count - 1 ? word.word : word.word + " "
            
            return Text(displayedText)
                .foregroundColor(word.color)
        }
        .reduce(Text(""), +)
    }
}

#Preview {
    FlashcardView()
}
