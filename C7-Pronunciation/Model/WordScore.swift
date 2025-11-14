//
//  WordScore.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 14/11/25.
//
import SwiftUI

struct WordScore: Identifiable, Hashable {
    let id = UUID()
    let word: String
    let score: Double = 0.0
    let phonemes: [String] = []
    
    // for ui purposes
    var isEvaluated: Bool = false
    var color: Color = .black
    
    mutating func evaluated() {
        isEvaluated = true
    }
    
    mutating func setColor(_ color: Color) {
        self.color = color
    }
}
