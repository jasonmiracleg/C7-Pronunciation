//
//  DataSeeder.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//

import Foundation
import SwiftData

// Helper structs for initialization (how to read base_data.json)
fileprivate struct JSONPhrase: Codable {
    let text: String
    let phonemes: String
}

fileprivate struct JSONDataStore: Codable {
    let formal: [JSONPhrase]
    let informal: [JSONPhrase]
}


// Parser for base_data.json
class DataSeeder {
    static func seed(context: ModelContext) {
        // Ignore after initial install
        guard needsSeeding(context: context) else {
            return
        }
        
        // Safety (base_data needs to be included in the project's bundles)
        guard let url = Bundle.main.url(forResource: "base_data", withExtension: "json") else {
            fatalError("Failed to find base_data.json in bundle.")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Failed to load data from base_data.json.")
        }
        
        // Load data from json
        do {
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode(JSONDataStore.self, from: data)
            
            // Formal phrases
            for phraseData in jsonData.formal {
                let phrase = Phrase(
                    text: phraseData.text,
                    phonemes: phraseData.phonemes,
                    category: .formal
                )
                context.insert(phrase)
            }
            
            // Informal phrases
            for phraseData in jsonData.informal {
                let phrase = Phrase(
                    text: phraseData.text,
                    phonemes: phraseData.phonemes,
                    category: .informal
                )
                context.insert(phrase)
            }
            
        } catch {
            fatalError("Failed to decode base_data.json: \(error)")
        }
    }
    
    // Helper function to check if database setup is needed
    static func needsSeeding(context: ModelContext) -> Bool {
        let fetchDescriptor = FetchDescriptor<Phrase>(predicate: #Predicate { _ in true })
        
        do {
            let count = try context.fetchCount(fetchDescriptor)
            return count == 0
        } catch {
            print("Failed to fetch phrase count: \(error)")
            return false
        }
    }
}
