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
    
    var lastUpdated: Date = Date()
    
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
    
    
    func updateScore(evalScore: Double){
        let dynamicRate = max(0.1, 0.5 - (Double(attempts) * 0.02))
        
        let evalScoreNormalized = evalScore/100
        let newScore = score * (1 - dynamicRate) + evalScore * dynamicRate // Using eval instead of normalized eval
        
        attempts += 1
        score = newScore
        
        lastUpdated = Date()
    }
}
