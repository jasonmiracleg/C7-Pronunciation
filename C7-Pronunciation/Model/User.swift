//
//  User.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 17/11/25.
//
import Foundation

class User {
    
    var phonemeScores: [PhonemeRecommendationScore] = []
    
    init(){
        let vocab = Self.loadVocab()
        phonemeScores = vocab.map { PhonemeRecommendationScore(id: $0.id, phoneme: $0.phoneme) }
    }
    
    private static func loadVocab() -> [VocabEntry] {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "json") else {
            print("vocab.json not found")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([VocabEntry].self, from:data)
        } catch {
            print("Failed to decode vocab.json: \(error)")
            return []
        }
    }
    
    // CALL THIS TO UPDATE GLOBAL PHONEME SCORES
    func updateScores(with phonemes: [AlignedPhoneme]) {
        for entry in phonemes {
            
            // checks only if the target and actual are actually valid to check
            if !(entry.type == .match && entry.type == .replace) { continue }
            guard let target = entry.target else { continue }
            
            // find the index of the existing phoneme
            if let index = phonemeScores.firstIndex(where: { $0.phoneme == target}) {
                phonemeScores[index].updateScore(evalScore: entry.score)
            } else { // this else is an edge case theres a completely new phoneme
                var newPhoneme = PhonemeRecommendationScore(
                    id: phonemeScores.count,
                    phoneme: target
                )
                newPhoneme.updateScore(evalScore: entry.score)
                phonemeScores.append(newPhoneme)
            }
            
        }
    }
    
    func getMixedUrgencyPhoneme(limit: Int = 3) -> [String]{
        let amountOfPhonemesBasedOnAttempt:Int = limit/3
        let amountOfPhonemesBasedOnScore:Int = limit - amountOfPhonemesBasedOnAttempt
        
        var mixedPhonemes: [String] = []
        mixedPhonemes.append(contentsOf: getMostUrgentPhonemes(limit: amountOfPhonemesBasedOnScore))
        mixedPhonemes.append(contentsOf: getLeastAttemptedPhonemes(limit: amountOfPhonemesBasedOnAttempt))
        
        return mixedPhonemes
    }
    
    private func getMostUrgentPhonemes(limit: Int = 3) -> [String]{
        return phonemeScores
            .sorted { $0.score < $1.score }
            .prefix(limit)
            .map { $0.phoneme }
    }
    
    private func getLeastAttemptedPhonemes(limit: Int = 3) -> [String]{
        return phonemeScores
            .sorted { $0.attempts < $1.attempts }
            .prefix(limit)
            .map { $0.phoneme }
    }
}

// Im making this cz idk the one in Espeak Manager
private struct VocabEntry: Codable {
    let id: Int
    let phoneme: String
}
