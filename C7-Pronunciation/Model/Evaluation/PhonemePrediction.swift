//
//  PhonemePrediction.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//


/// Represents a phoneme with its top predictions and scores
struct PhonemePrediction {
    let topPrediction: PhonemeScore
    let score: Double
    let top3: [PhonemeScore]
}

/// Represents a top-3 alternative phoneme prediction
struct PhonemeScore {
    let phoneme: String
    let score: Double
}