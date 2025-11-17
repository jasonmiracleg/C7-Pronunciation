//
//  SwiftDataManager.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//


import Foundation
import SwiftData

/// A singleton manager to handle all SwiftData operations for the app.
@MainActor
class DataBankManager {
    // Singleton manager
    static let shared = DataBankManager()
    
    let modelContainer: ModelContainer

    private var context: ModelContext {
        modelContainer.mainContext
    }
    
    private init() {
        do {
            let schema = Schema([
                Phrase.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // If database is empty, try seeding (bank of phrases)
            let seedContext = modelContainer.mainContext
            DataSeeder.seed(context: seedContext)
            
            if seedContext.hasChanges {
                try seedContext.save()
                print("Database seeded and saved.")
            } else {
                print("Database already seeded.")
            }
            
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Add Operations
        
    /// Adds a new user-defined phrase to the database.
    func addPhrase(text: String, phonemes: String, category: PhraseCategory) {
        let newPhrase = Phrase(text: text, phonemes: phonemes, category: category)
        context.insert(newPhrase)
        
        do {
            try context.save()
            print("Successfully saved new phrase.")
        } catch {
            print("Failed to save new phrase: \(error)")
        }
    }

    /// Converts text to phonemes (en - international) and saves it to the database in the .userAdded category
    func addUserPhrase(_ text: String) {
        let phonemeString = EspeakManager.shared.getPhonemesAsString(for: text)
        
        // Handle potential failures (or empty results)
        guard phonemeString != "" else {
            print("Espeak returned no phonemes for: \(text)")
            return
        }
        
        // Save to database
        addPhrase(text: text, phonemes: phonemeString, category: .userAdded)
    }
    
    // MARK: - Fetch Operations
    
    /// Fetches a specified number of random phrases for a given category.
    private func getRandomPhrases(category: PhraseCategory, count: Int) -> [Phrase] {
        do {
            let categoryRawValue = category.rawValue
            
            let descriptor = FetchDescriptor<Phrase>(
                predicate: #Predicate { $0.categoryRawValue == categoryRawValue }
            )
            
            let allMatching = try context.fetch(descriptor)
        
            return Array(allMatching.shuffled().prefix(count))
            
        } catch {
            print("Failed to fetch random phrases for category \(category.displayName): \(error)")
            return []
        }
    }
    
    /// Fetches a single random phrase from the specified category.
    func getRandomPhrase(category: PhraseCategory) -> Phrase? {
        do {
            let categoryRawValue = category.rawValue
            
            let descriptor = FetchDescriptor<Phrase>(
                predicate: #Predicate { $0.categoryRawValue == categoryRawValue }
            )
            
            let allMatching = try context.fetch(descriptor)
            
            return allMatching.randomElement()
            
        } catch {
            print("Failed to fetch random phrase for category \(category.displayName): \(error)")
            return nil
        }
    }
    
    //  DEBUG : Fetch 3 phrases from each category
    func getRandomPhrasePicks() -> (formal: [Phrase], informal: [Phrase], userAdded: [Phrase]) {
        let formal = getRandomPhrases(category: .formal, count: 3)
        let informal = getRandomPhrases(category: .informal, count: 3)
        let userAdded = getRandomPhrases(category: .userAdded, count: 3)
        
        return (formal, informal, userAdded)
    }

    // MARK: - Search Functions
    
    /// Overload for `getPhrasesContainingText` to accept a single String.
    func getPhrasesContainingText(_ queryText: String, category: PhraseCategory? = nil) -> [Phrase] {
        // Simply call the array version.
        return getPhrasesContainingText([queryText], category: category)
    }

    /// Searches for phrases where the `text` field contains the query terms with weighted ranking.
    /// Terms are ranked by importance based on their index (lower index = higher weight).
    /// Returns phrases sorted by score, with the highest scoring phrase first.
    func getPhrasesContainingText(_ queryTerms: [String], category: PhraseCategory? = nil) -> [Phrase] {
        // Sanitize the input terms
        let trimmedTerms = queryTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // If no valid terms, return empty
        guard !trimmedTerms.isEmpty else { return [] }

        // Try progressively with fewer terms (removing least important)
        var currentTerms = trimmedTerms
        
        while !currentTerms.isEmpty {
            // Fetch all phrases that match the current term set
            let matchingPhrases = fetchPhrasesWithTextTerms(currentTerms, category: category)
            
            if !matchingPhrases.isEmpty {
                // Calculate scores for each phrase
                let scoredPhrases = matchingPhrases.map { phrase -> (phrase: Phrase, score: Double) in
                    var score: Double = 0.0
                    
                    // For each term, count occurrences and add weighted score
                    for (index, term) in currentTerms.enumerated() {
                        // Weight decreases with index (index 0 has highest weight)
                        let weight = Double(currentTerms.count - index)
                        
                        // Count occurrences of this term in the phrase text
                        let occurrences = countOccurrences(of: term, in: phrase.text)
                        
                        // Add to score: occurrences * weight
                        score += Double(occurrences) * weight
                    }
                    
                    return (phrase: phrase, score: score)
                }
                
                // Sort by score (highest first) and return the phrases
                let sortedPhrases = scoredPhrases
                    .sorted { $0.score > $1.score }
                    .map { $0.phrase }
                
                return sortedPhrases
            }
            
            // No matches found, remove the least important term (last one) and try again
            currentTerms.removeLast()
        }
        
        // No matches found at all
        return []
    }
    
    /// Helper method to fetch phrases containing ALL specified text terms.
    private func fetchPhrasesWithTextTerms(_ terms: [String], category: PhraseCategory? = nil) -> [Phrase] {
        var predicates: [Predicate<Phrase>] = []

        // Add category predicate if provided
        if let category = category {
            let categoryRawValue = category.rawValue
            predicates.append(#Predicate<Phrase> { $0.categoryRawValue == categoryRawValue })
        }

        // Add a predicate for EACH query term (AND logic)
        for term in terms {
            predicates.append(#Predicate<Phrase> { $0.text.localizedStandardContains(term) })
        }

        guard let firstPredicate = predicates.first else {
            return []
        }
        
        let combinedPredicate = predicates.dropFirst().reduce(firstPredicate) { (combined, next) in
            return #Predicate<Phrase> {
                combined.evaluate($0) && next.evaluate($0)
            }
        }

        let descriptor = FetchDescriptor<Phrase>(predicate: combinedPredicate)

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch phrases with text terms: \(error)")
            return []
        }
    }
    
    /// Helper method to count occurrences of a substring in a string (case-insensitive).
    private func countOccurrences(of substring: String, in string: String) -> Int {
        let lowercasedString = string.lowercased()
        let lowercasedSubstring = substring.lowercased()
        
        var count = 0
        var searchRange = lowercasedString.startIndex..<lowercasedString.endIndex
        
        while let range = lowercasedString.range(of: lowercasedSubstring, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<lowercasedString.endIndex
        }
        
        return count
    }
    
    /// Overload for `getPhrasesContainingPhoneme` to accept a single String.
    func getPhrasesContainingPhoneme(_ queryPhoneme: String, category: PhraseCategory? = nil) -> [Phrase] {
        return getPhrasesContainingPhoneme([queryPhoneme], category: category)
    }
    
    /// Searches for phrases where the `phonemes` field contains the query phonemes with weighted ranking.
    /// Phonemes are ranked by importance based on their index (lower index = higher weight).
    /// Returns phrases sorted by score, with the highest scoring phrase first.
    func getPhrasesContainingPhoneme(_ queryPhonemes: [String], category: PhraseCategory? = nil) -> [Phrase] {
        let trimmedTerms = queryPhonemes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !trimmedTerms.isEmpty else { return [] }

        // Try progressively with fewer phonemes (removing least important)
        var currentPhonemes = trimmedTerms
        
        while !currentPhonemes.isEmpty {
            // Fetch all phrases that match the current phoneme set
            let matchingPhrases = fetchPhrasesWithPhonemeTerms(currentPhonemes, category: category)
            
            if !matchingPhrases.isEmpty {
                // Calculate scores for each phrase
                let scoredPhrases = matchingPhrases.map { phrase -> (phrase: Phrase, score: Double) in
                    var score: Double = 0.0
                    
                    // For each phoneme, count occurrences and add weighted score
                    for (index, phoneme) in currentPhonemes.enumerated() {
                        // Weight decreases with index (index 0 has highest weight)
                        let weight = Double(currentPhonemes.count - index)
                        
                        // Count occurrences of this phoneme in the phrase phonemes
                        let occurrences = countOccurrences(of: phoneme, in: phrase.phonemes)
                        
                        // Add to score: occurrences * weight
                        score += Double(occurrences) * weight
                    }
                    
                    return (phrase: phrase, score: score)
                }
                
                // Sort by score (highest first) and return the phrases
                let sortedPhrases = scoredPhrases
                    .sorted { $0.score > $1.score }
                    .map { $0.phrase }
                
                return sortedPhrases
            }
            
            // No matches found, remove the least important phoneme (last one) and try again
            currentPhonemes.removeLast()
        }
        
        // No matches found at all
        return []
    }
    
    /// Helper method to fetch phrases containing ALL specified phoneme terms.
    private func fetchPhrasesWithPhonemeTerms(_ terms: [String], category: PhraseCategory? = nil) -> [Phrase] {
        var predicates: [Predicate<Phrase>] = []

        // Add category predicate if provided
        if let category = category {
            let categoryRawValue = category.rawValue
            predicates.append(#Predicate<Phrase> { $0.categoryRawValue == categoryRawValue })
        }

        // Add a predicate for EACH phoneme term (AND logic)
        for term in terms {
            predicates.append(#Predicate<Phrase> { $0.phonemes.localizedStandardContains(term) })
        }

        guard let firstPredicate = predicates.first else {
            return []
        }
        
        let combinedPredicate = predicates.dropFirst().reduce(firstPredicate) { (combined, next) in
            return #Predicate<Phrase> {
                combined.evaluate($0) && next.evaluate($0)
            }
        }

        let descriptor = FetchDescriptor<Phrase>(predicate: combinedPredicate)

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch phrases with phoneme terms: \(error)")
            return []
        }
    }
}
