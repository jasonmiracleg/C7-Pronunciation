//
//  WordScore.swift
//  PronunciationScorer
//
//  Created by Abelito Faleyrio Visese on 07/11/25.
//

import SwiftUI

struct WordScore: Identifiable {
    let id = UUID()
    let word: String
    var score: Double 
    var alignedPhonemes: [AlignedPhoneme]
    
    // UI Purposes Variables
    var isEvaluated: Bool = false
    var color: Color = .black
    
    // Init with default empty array for phonemes
    init(word: String, score: Double = 0.0, alignedPhonemes: [AlignedPhoneme] = []) {
        self.word = word
        self.score = score
        self.alignedPhonemes = alignedPhonemes
        self.color = Color.primary
        self.isEvaluated = false
    }

    /// Returns an array containing just the 'target' strings.
    func allTargets() -> String {
        return self.alignedPhonemes.compactMap { $0.target }.joined(separator: " ")
    }
    
    /// Returns an array containing just the 'actual' strings.
    func allActuals() -> String {
        return self.alignedPhonemes.compactMap { $0.actual }.joined(separator: " ")
    }
    
    mutating func evaluated() {
        isEvaluated = true
    }
    
    mutating func setColor(_ color: Color) {
        self.color = color
    }
}
