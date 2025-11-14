//
//  FlashcardViewModel.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 14/11/25.
//

import Foundation
import SwiftUI
import Combine

class FlashcardViewModel: ObservableObject {
    
    init(){
        phrase = FlashcardPhrase(phrase: "Hello world")
    }
    
    @Published var dummyWords: [WordScore] = [
        WordScore(word: "Hello"),
        WordScore(word: "there"),
        WordScore(word: "im"),
        WordScore(word: "writing"),
        WordScore(word: "this"),
        WordScore(word: "shit"),
    ]
    
    //save the phrase
    @Published var phrase: FlashcardPhrase
    
    //save the recording
    // variable waiting
    
    
    func evaluateDummy(){
        for i in dummyWords.indices {
            let randomColor: Color = [ .red, .green, .blue, .yellow, .orange ].randomElement()!
            dummyWords[i].setColor(randomColor)
        }
    }
    
}
