//
//  PhonemeRecommendationScore.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 17/11/25.
//

import Foundation
import SwiftData

@Model
final class PhonemeRecommendationScore {
    
    @Attribute(.unique) var id: UUID
    var phoneme: String
    
    // this if for decay
    var attempts: Int = 0
    
    var score: Double = 0.5
    
    init(
        phoneme: String,
        score: Double = 0.5,
        attempts: Int = 0
    ) {
        self.id = UUID()
        self.phoneme = phoneme
        self.score = score
        self.attempts = attempts
    }
    
    
    func updateScore(evalScore: Double, learningRate: Double = 0.4){
        let evalScoreNormalized = evalScore/100
        let newScore = score * (1 - learningRate) + evalScoreNormalized * learningRate
        attempts += 1
        score = newScore
    }
}
