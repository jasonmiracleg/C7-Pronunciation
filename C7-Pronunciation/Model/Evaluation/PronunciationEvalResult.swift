//
//  PronunciationEvalResult.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//

import Foundation

/// The main result of the alignment and scoring
struct PronunciationEvalResult: Identifiable {
    let id = UUID()
    let totalScore: Double
    let wordScores: [WordScore]
    var sentenceText: String? = ""
    var feedback: String {
        if totalScore >= 85 {
            return "Excellent pronunciation!"
        } else if totalScore >= 70 {
            return "Good pronunciation with minor issues"
        } else if totalScore >= 50 {
            return "Fair pronunciation, needs improvement"
        } else {
            return "Pronunciation needs significant work"
        }
    }
}
