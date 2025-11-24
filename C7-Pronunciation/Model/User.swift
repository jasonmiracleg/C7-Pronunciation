//
//  User.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 17/11/25.
//

import Foundation
import Combine
import SwiftData

class User: ObservableObject {
    
    @Published var phonemeScores: [PhonemeRecommendationScore] = []
    @Published var phraseQueue: [Phrase] = []
    var successfullyLoadedPhonemes = true
    private var recentPhraseHistory: Set<String> = []
    
    init() {
        let context = DataBankManager.shared.context
        let descriptor = FetchDescriptor<PhonemeRecommendationScore>(
            sortBy: [SortDescriptor(\.phoneme)]
        )
        
        if let loaded = try? context.fetch(descriptor), !loaded.isEmpty {
            // Load stored scores
            self.phonemeScores = loaded
            return
        }

        // First launch: generate from vocab and insert into DB
        let vocab = loadVocabulary()
        self.phonemeScores = vocab.map {
            PhonemeRecommendationScore(phoneme: $0.phoneme)
        }

        for item in phonemeScores {
            context.insert(item)
        }

        try? context.save()
    }

    
    private func loadVocabulary() -> [VocabEntry] {
        guard let url = Bundle.main.url(forResource: "vocab_gpt_cleansed", withExtension: "json") else {
            print("vocab_gpt_cleansed.json not found in bundle")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            let decoded = try JSONDecoder().decode(VocabularyFile.self, from: data)
            
            // token_to_id contains: token → id
            let vocabList = decoded.token_to_id.map { token, id in
                VocabEntry(id: id, phoneme: token)
            }
            
            return vocabList
            
        } catch {
            print("Failed to decode vocab_gpt_cleansed.json: \(error)")
            return []
        }
    }

    // CALL THIS TO UPDATE GLOBAL PHONEME SCORES
    func updateScores(with phonemes: [AlignedPhoneme]) {
        objectWillChange.send()
        for entry in phonemes {
            
            if entry.type != .match && entry.type != .replace { continue }
            guard let target = entry.actual else { continue }
            
            if let index = phonemeScores.firstIndex(where: { $0.phoneme == target}) {
                let oldScore = phonemeScores[index].score
                phonemeScores[index].updateScore(evalScore: entry.score)
                print("✅ Updated [\(target)]: \(String(format: "%.2f", oldScore)) -> \(String(format: "%.2f", phonemeScores[index].score))")
            } else {
                let newPhoneme = PhonemeRecommendationScore(
                    phoneme: target
                )
                newPhoneme.updateScore(evalScore: entry.score)
                phonemeScores.append(newPhoneme)
            }
            
        }
        try? DataBankManager.shared.context.save()
    }
    
    func updateScore(for phoneme: String, evalScore: Double){
        // find the index of the phoneme
        if let index = phonemeScores.firstIndex(where: { $0.phoneme == phoneme }) {
            phonemeScores[index].updateScore(evalScore: evalScore)
            
            // saving into swift data
            try? DataBankManager.shared.context.save()
            
            print("Found the phoneme")
            return
        }
        print("Did not find the phoneme")
    }
    
    func addPhrasesToQueue(basedOn: PhraseSearchType = .mixed) {
        var targetPhonemes: [String] = []
        
        switch basedOn {
        case .urgency:
            targetPhonemes = getMostUrgentPhonemes()
        case .attempts:
            targetPhonemes = getLeastAttemptedPhonemes()
        case .mixed:
            targetPhonemes = getMixedUrgencyPhoneme()
        }
        
        var candidates: [Phrase] = []
        
        for phoneme in targetPhonemes {
            let matches = DataBankManager.shared.getPhrasesContainingPhoneme([phoneme])
            candidates.append(contentsOf: matches)
        }
        
        let uniqueCandidates = Array(Set(candidates))
        
        let availableCandidates = uniqueCandidates.filter { candidate in
            !phraseQueue.contains(where: { $0.text == candidate.text })
        }
        
        if availableCandidates.isEmpty {
            print("⚠️ Recommendation returned 0 results. Using fallback random phrases.")
            let randomPicks = DataBankManager.shared.getRandomPhrasePicks()
            
            var fallbackPhrases: [Phrase] = []
            fallbackPhrases.append(contentsOf: randomPicks.formal)
            fallbackPhrases.append(contentsOf: randomPicks.informal)
            
            phraseQueue.append(contentsOf: fallbackPhrases.shuffled())
        } else {
            let selectedPhrases = Array(availableCandidates.shuffled().prefix(5))
            phraseQueue.append(contentsOf: selectedPhrases)
        }
        
        print("✅ Added \(phraseQueue.count) phrases to queue. Strategy: \(basedOn)")
    }
    
    func nextCard() -> Phrase {
        let newPhrase = phraseQueue.removeFirst()
        if phraseQueue.count <= 2 {
            addPhrasesToQueue(basedOn: .attempts)
        }
        return newPhrase
    }
    
//    GETTING PHONEME SCORE SHIT AS A STRING ARRAY
    func getMixedUrgencyPhoneme(limit: Int = 3) -> [String]{
        let amountOfPhonemesBasedOnAttempt:Int = limit/3
        let amountOfPhonemesBasedOnScore:Int = limit - amountOfPhonemesBasedOnAttempt
        
        var mixedPhonemes: [String] = []
        mixedPhonemes.append(contentsOf: getMostUrgentPhonemes(limit: amountOfPhonemesBasedOnScore))
        mixedPhonemes.append(contentsOf: getLeastAttemptedPhonemes(limit: amountOfPhonemesBasedOnAttempt))
        
        return mixedPhonemes
    }
    
    func getMostUrgentPhonemes(limit: Int = 3) -> [String] {
        return phonemeScores
            .map { scoreObj -> (String, Double) in
                // If it's been a long time since last update, artificially lower the score to bubble it up to the top of the list.
                let daysSinceLastPractice = Date().timeIntervalSince(scoreObj.lastUpdated) / 86400
                let decayFactor = 0.05 * daysSinceLastPractice
                
                let adjustedScore = scoreObj.score - decayFactor
                return (scoreObj.phoneme, adjustedScore)
            }
            .sorted { $0.1 < $1.1 } // Sort by the Adjusted Score
            .prefix(limit)
            .map { $0.0 }
    }
    
    func getLeastAttemptedPhonemes(limit: Int = 3) -> [String]{
        return phonemeScores
            .sorted { $0.attempts < $1.attempts }
            .prefix(limit)
            .map { $0.phoneme }
    }
    
    func getRawMostAttemptedPhonemes(limit: Int = 3) -> [PhonemeRecommendationScore]{
        return Array(
            phonemeScores
                .sorted { $0.attempts > $1.attempts }
                .prefix(limit)
        )
    }

    func getRawHighestScoring(limit: Int = 3) -> [PhonemeRecommendationScore] {
        return Array(
            phonemeScores
                .sorted { $0.score > $1.score }   // highest first
                .prefix(limit)
        )
    }
    
    private func addToHistory(_ text: String) {
        recentPhraseHistory.insert(text)
        // Remember the last 50 phrases :D
        if recentPhraseHistory.count > 50 {
            recentPhraseHistory.removeFirst()
        }
    }

}

// Im making this cz idk the one in Espeak Manager
private struct VocabEntry: Codable {
    let id: Int
    let phoneme: String
}

private struct VocabularyFile: Codable {
    let id_to_token: [String: String]
    let token_to_id: [String: Int]
}

private struct VocabWrapper: Codable {
    let vocab: [VocabEntry]
}

enum PhraseSearchType: CaseIterable, Codable {
    case urgency
    case attempts
    case mixed
}
