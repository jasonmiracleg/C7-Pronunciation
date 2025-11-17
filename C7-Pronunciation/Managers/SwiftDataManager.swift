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
class SwiftDataManager {
    // Singleton manager
    static let shared = SwiftDataManager()
    
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
            print("Database setup complete.")
            
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

    // *** NEW FUNCTION ***
    /// Converts text to phonemes using EspeakManager and saves it as a user-added phrase.
    func addUserPhrase(_ text: String) {
        // 1. Generate phonemes using your new manager
        // Note: Your file comment indicated this returns [String], so we join them.
        let phonemeArray = EspeakManager.shared.getPhonemes(for: text)
        
        // Handle potential failures (or empty results)
        guard !phonemeArray.isEmpty else {
            print("EspeakManager returned no phonemes for: \(text)")
            return
        }
        
        // 2. Convert array to a single string (e.g., "h ə l ˈ ə ʊ")
        let phonemeString = phonemeArray.joined(separator: " ")
        
        // 3. Save to database
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
    
    /// Fetches 3 random phrases from each of the main categories.
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

    /// Searches for phrases where the `text` field contains ALL of the provided query terms.
    func getPhrasesContainingText(_ queryTerms: [String], category: PhraseCategory? = nil) -> [Phrase] {
        // Sanitize the input terms
        let trimmedTerms = queryTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // If no valid terms, return empty
        guard !trimmedTerms.isEmpty else { return [] }

        // Start building an array of predicates
        var predicates: [Predicate<Phrase>] = []

        // 1. Add category predicate if provided
        if let category = category {
            // *** FIX ***
            // 1. Capture the rawValue string
            let categoryRawValue = category.rawValue
            // 2. Append a predicate that compares the stored string property
            predicates.append(#Predicate<Phrase> { $0.categoryRawValue == categoryRawValue })
        }

        // 2. Add a predicate for EACH query term
        // This ensures the phrase contains ALL terms (AND logic)
        for term in trimmedTerms {
            predicates.append(#Predicate<Phrase> { $0.text.localizedStandardContains(term) })
        }

        // 3. Combine all predicates using AND
        guard let firstPredicate = predicates.first else {
            // This can happen if the user only provides empty strings
            if category == nil { return [] }
            
            // If we *only* have a category, we need a predicate for just that.
            // But our logic above already added it.
            // A better guard: if predicates array is empty, just return.
            return []
        }
        
        // We 'reduce' the array of predicates into a single one.
        let combinedPredicate = predicates.dropFirst().reduce(firstPredicate) { (combined, next) in
            // Build a new predicate by combining the previous with the next
            return #Predicate<Phrase> {
                combined.evaluate($0) && next.evaluate($0)
            }
        }

        // 4. Create the final descriptor
        let descriptor = FetchDescriptor<Phrase>(
            predicate: combinedPredicate,
            sortBy: [SortDescriptor(\.text)] // Sort results alphabetically
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch phrases with text query: \(error)")
            return []
        }
    }
    
    /// Overload for `getPhrasesContainingPhoneme` to accept a single String.
    func getPhrasesContainingPhoneme(_ queryPhoneme: String, category: PhraseCategory? = nil) -> [Phrase] {
        return getPhrasesContainingPhoneme([queryPhoneme], category: category)
    }
    
    /// Searches for phrases where the `phonemes` field contains ALL of the provided query terms.
    func getPhrasesContainingPhoneme(_ queryPhonemes: [String], category: PhraseCategory? = nil) -> [Phrase] {
        let trimmedTerms = queryPhonemes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !trimmedTerms.isEmpty else { return [] }

        var predicates: [Predicate<Phrase>] = []

        // 1. Add category predicate
        if let category = category {
            // *** FIX ***
            // 1. Capture the rawValue string
            let categoryRawValue = category.rawValue
            // 2. Append a predicate that compares the stored string property
            predicates.append(#Predicate<Phrase> { $0.categoryRawValue == categoryRawValue })
        }

        // 2. Add a predicate for EACH phoneme term
        for term in trimmedTerms {
            // Using localizedStandardContains for consistency, though `contains`
            // would also work well for phoneme strings.
            predicates.append(#Predicate<Phrase> { $0.phonemes.localizedStandardContains(term) })
        }

        // 3. Combine with AND
        guard let firstPredicate = predicates.first else {
             if category == nil { return [] }
             // See note in function above.
             return []
        }
        
        // We 'reduce' the array of predicates into a single one.
        let combinedPredicate = predicates.dropFirst().reduce(firstPredicate) { (combined, next) in
            // Build a new predicate by combining the previous with the next
            return #Predicate<Phrase> {
                combined.evaluate($0) && next.evaluate($0)
            }
        }

        let descriptor = FetchDescriptor<Phrase>(
            predicate: combinedPredicate,
            sortBy: [SortDescriptor(\.phonemes)] // Sort results
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch phrases with phoneme query: \(error)")
            return []
        }
    }
}
