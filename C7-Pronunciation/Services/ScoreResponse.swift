//
//  ScoreResponse.swift
//  PronunciationScorer
//
//  Created by Abelito Faleyrio Visese on 07/11/25.
//

import Foundation
import SwiftUI

struct ScoreResponse: Codable {
    let overallScore: Double
    let wordScores: [WordScore]
    let feedback: String
    let recognizedPhonemes: String // Mapped from "transcription"
    
    enum CodingKeys: String, CodingKey {
        case overallScore = "total_score"
        case wordScores = "word_level_scores"
        case feedback
        case recognizedPhonemes = "transcription"
    }
}
