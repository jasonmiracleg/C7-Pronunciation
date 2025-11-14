//
//  WordScore.swift
//  PronunciationScorer
//
//  Created by Abelito Faleyrio Visese on 07/11/25.
//

import SwiftUI

struct WordScore: Codable, Identifiable {
    let id = UUID()
    let word: String
    let score: Double
    let phonemes: [String]
    
    enum CodingKeys: String, CodingKey {
        case word, score
        case phonemes 
    }
}
