//
//  PhonemeVocabulary.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//

import Foundation

struct PhonemeVocabulary {
    private let idToToken: [Int: String]
    let vocabSize: Int
    
    // Special token IDs (CTC blank is typically 0)
    static let blankId = 0
    
    init?(jsonFilename: String = "vocab") {
        guard let url = Bundle.main.url(forResource: jsonFilename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vocabSizeValue = json["vocab_size"] as? Int,
              let idToTokenDict = json["id_to_token"] as? [String: String] else {
            print("Failed to load vocabulary from \(jsonFilename).json")
            return nil
        }
        
        self.vocabSize = vocabSizeValue
        
        // Convert string keys to int keys
        var intDict: [Int: String] = [:]
        for (key, value) in idToTokenDict {
            if let id = Int(key) {
                intDict[id] = value
            }
        }
        
        self.idToToken = intDict
        
        print("Vocabulary loaded: \(vocabSize) tokens")
    }
    
    func token(for id: Int) -> String? {
        return idToToken[id]
    }
    
    func tokens(for ids: [Int]) -> [String] {
        return ids.compactMap { token(for: $0) }
    }
}
