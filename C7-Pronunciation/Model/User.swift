//
//  User.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 17/11/25.
//
import Foundation
import Combine

class User: ObservableObject {
    
    @Published var phonemeScores: [PhonemeRecommendationScore] = []
    var successfullyLoadedPhonemes = true
    
    init(){
        let vocab = loadVocabulary()
        if vocab.count == 0 { successfullyLoadedPhonemes = false }
        phonemeScores = vocab.map { PhonemeRecommendationScore(id: $0.id, phoneme: $0.phoneme) }
    }
    
    private func loadVocabulary() -> [VocabEntry] {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "json") else {
            print("vocab.json not found in bundle")
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
    
    func updateScore(for phoneme: String, evalScore: Double){
        // find the index of the phoneme
        if let index = phonemeScores.firstIndex(where: { $0.phoneme == phoneme }) {
            phonemeScores[index].updateScore(evalScore: evalScore)
            print("Found the phoneme")
            return
        }
        print("Did not find the phoneme")
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
    
    func getMostUrgentPhonemes(limit: Int = 3) -> [String]{
        return phonemeScores
            .sorted { $0.score < $1.score }
            .prefix(limit)
            .map { $0.phoneme }
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
