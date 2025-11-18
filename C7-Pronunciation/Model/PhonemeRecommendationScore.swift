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
    
    mutating func updateScore(evalScore: Double, learningRate: Double = 0.2){
        let newScore = score * (1 - learningRate) + evalScore * learningRate
        attempts += 1
    }
}
