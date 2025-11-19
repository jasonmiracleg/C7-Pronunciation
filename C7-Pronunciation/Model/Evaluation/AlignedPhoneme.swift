//
//  AlignedPhoneme.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//


// THIS FUCKING PAGE IS THE ONE THATS FOR PHONEME LEVEL ACCURACY

/// Represents an aligned phoneme result
struct AlignedPhoneme {
    enum AlignmentType: String {
        case match
        case replace
        case delete
        case insert
    }
    
    let type: AlignmentType
    let target: String?
    let actual: String?
    let score: Double
    let note: String?
}
