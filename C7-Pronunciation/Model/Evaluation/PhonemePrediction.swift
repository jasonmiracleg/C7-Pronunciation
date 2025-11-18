//
//  PhonemePrediction.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//

// Ignore this page this is used solely for the model
// to be able to align the phonemes and predict the phonemes blah blah
// intie iki irrelevant to the front end use the other one

/// Represents a phoneme with its top predictions and scores
struct PhonemePrediction {
    let topPrediction: PhonemeEvaluationScore
    let score: Double
    let top3: [PhonemeEvaluationScore]
}

/// Represents a top-3 alternative phoneme prediction
struct PhonemeEvaluationScore {
    let phoneme: String
    let score: Double
}
