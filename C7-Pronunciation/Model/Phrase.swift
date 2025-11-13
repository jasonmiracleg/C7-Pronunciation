//
//  Phrase.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//

import Foundation
import SwiftData

// Content tags (can add more in the future)
enum PhraseCategory: String, Codable, CaseIterable, Hashable {
    case formal
    case informal
    case userAdded
    
    var displayName: String {
        switch self {
        case .formal:
            return "Formal"
        case .informal:
            return "Informal"
        case .userAdded:
            return "User Added"
        }
    }
}


// SwiftData class to store phrases in the bank
@Model
final class Phrase {
    @Attribute(.unique) var id: UUID
    var text: String
    var phonemes: String
    var categoryRawValue: String
    var createdAt: Date
    
    var category: PhraseCategory {
        get {
            return PhraseCategory(rawValue: categoryRawValue) ?? .formal
        }
        set {
            self.categoryRawValue = newValue.rawValue
        }
    }
    
    init(text: String, phonemes: String, category: PhraseCategory) {
        self.id = UUID()
        self.text = text
        self.phonemes = phonemes
        self.categoryRawValue = category.rawValue
        self.createdAt = Date()
    }
}
