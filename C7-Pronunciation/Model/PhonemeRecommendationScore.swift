//
//  PhonemeRecommendationScore.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 17/11/25.
//

import Foundation

struct PhonemeRecommendationScore {
    
    let id: Int
    var phoneme: String
    
    // this if for decay
    var attempts: Int = 0
    
    var score: Double = 0.5
    
    mutating func updateScore(evalScore: Double, learningRate: Double = 0.4){
        let evalScoreNormalized = evalScore/100
        let newScore = score * (1 - learningRate) + evalScoreNormalized * learningRate
        attempts += 1
        score = newScore
    }
}
