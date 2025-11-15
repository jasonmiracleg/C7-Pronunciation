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
    let score: Double
    let alignedPhonemes: [AlignedPhoneme]

    /// Returns an array containing just the 'target' strings.
    func allTargets() -> String {
        return self.alignedPhonemes.compactMap { $0.target }.joined(separator: " ")
    }
    
    /// Returns an array containing just the 'actual' strings.
    func allActuals() -> String {
        return self.alignedPhonemes.compactMap { $0.actual }.joined(separator: " ")
    }
}
