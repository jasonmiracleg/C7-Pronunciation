//
//  FlashcardPhrase.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 14/11/25.
//
import SwiftUI

class FlashcardPhrase{
    
    let phrase: String
    var words: [WordScore] = []
    
    init(phrase: String){
        self.phrase = phrase
        
        let splitWords = phrase.split(separator: " ")
        
        self.words = splitWords.map { word in
            WordScore(word: String(word))
        }
    }
    
    func evaluatePhrase(){
        for i in words.indices {
            let randomColor: Color = [ .red, .green, .blue, .yellow, .orange ].randomElement()!
            words[i].setColor(randomColor)
        }
    }
    
}
