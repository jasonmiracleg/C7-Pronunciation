//
//  PronunciationRespeller.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 21/11/25.
//

import Foundation

/// Converts IPA phonetic transcriptions to human-readable respelling
/// Optimized for Indonesian speakers (Bahasa Indonesia phonology)
public class PronunciationRespeller {
    
    public static let shared = PronunciationRespeller()
    
    private init() {}
    
    // MARK: - IPA to Respelling Mappings
    
    /// Maps IPA symbols to respelling equivalents intuitive for Indonesian speakers
    private let ipaToRespelling: [String: String] = [
        // ═══════════════════════════════════════════════════════════════
        // VOWELS - Monophthongs
        // ═══════════════════════════════════════════════════════════════
        
        // KIT vowel
        // Indo: 'i' as in 'ikan'
        "ɪ": "i",
        "ᵻ": "i",
        
        // DRESS vowel
        // Indo: 'e' as in 'bebek'
        "ɛ": "e",
        "e": "e",
        
        // TRAP vowel
        // Indo: often approximated as 'e' (cat -> ket) or 'a' (bat -> bat).
        // 'e' is usually safer for Indo accent reduction on this vowel.
        "æ": "e",
        "a": "a",
        
        // LOT/PALM vowel
        // Indo: 'o' as in 'toko' / 'a' as in 'bapak'
        "ɒ": "o",
        "ɑ": "a",
        "ɑː": "a",
        
        // STRUT vowel (Cup, Bus)
        // Indo: 'a' is the closest intuitive sound. (Bus -> Bas)
        "ʌ": "a",
        "ɐ": "a",
        
        // FOOT vowel (Put, Good)
        // Indo: 'u' as in 'buku'
        "ʊ": "u",
        
        // Schwa (About, The)
        // Indo: 'e' (pepet) as in 'kelas'
        "ə": "e",
        "ɚ": "er",
        "ɝ": "er",
        
        // FLEECE vowel (See, Me)
        // Indo: 'ii' distinguishes length/tension from short 'i'
        "iː": "ii",
        "i": "ii",
        
        // GOOSE vowel (Moon, Food)
        // Indo: 'uu' (English 'oo' reads as 'o-o' in Indo)
        "uː": "uu",
        "u": "uu",
        
        // THOUGHT/NORTH vowel
        "ɔː": "o",
        "ɔ": "o",
        
        // NURSE vowel (Bird, Turn)
        // Indo: 'er' is the closest intuitive reading
        "ɜː": "er",
        "ɜ": "er",
        
        // ═══════════════════════════════════════════════════════════════
        // VOWELS - Diphthongs
        // ═══════════════════════════════════════════════════════════════
        
        // FACE (Day, Say)
        // Indo: 'ei' (survei) is more accurate than 'ay' (which reads like 'ai')
        "eɪ": "ei",
        "eː": "ei",
        
        // PRICE (My, Lie)
        // Indo: 'ai' (pantai)
        "aɪ": "ai",
        
        // CHOICE (Boy, Noise)
        // Indo: 'oi' (amboi)
        "ɔɪ": "oi",
        "oɪ": "oi",
        
        // GOAT (Go, No)
        // Indo: 'ou' captures the glide better than 'o'
        "oʊ": "ou",
        "əʊ": "ou",
        "oː": "ou",
        
        // MOUTH (Now, Out)
        // Indo: 'au' (kerbau)
        "aʊ": "au",
        
        // NEAR (Here)
        "ɪə": "ier",
        "ɪɹ": "ier",
        "iə": "ier",
        
        // SQUARE (Hair)
        "ɛə": "er",
        "eə": "er",
        "ɛɹ": "er",
        
        // CURE (Tour)
        "ʊə": "ur",
        "ʊɹ": "ur",
        
        // R-colored vowels
        "ɑːɹ": "ar",
        "ɔːɹ": "or",
        "ɑɹ": "ar",
        
        // ═══════════════════════════════════════════════════════════════
        // CONSONANTS
        // ═══════════════════════════════════════════════════════════════
        "p": "p",
        "b": "b",
        "t": "t",
        "d": "d",
        "k": "k",
        "ɡ": "g",
        "g": "g",
        "ʔ": "",
        
        "f": "f",
        "v": "v",
        "θ": "th",
        "ð": "th",
        "s": "s",
        "z": "z",
        "ʃ": "sh",   // 'sh' is better than Indo 'sy' for English context
        "ʒ": "zh",
        "h": "h",
        
        // Affricates
        "tʃ": "ch",  // 'ch' prevents confusion. Indo 'c' might be read as 'k'.
        "dʒ": "j",   // 'j' as in 'jalan' matches English 'j'
        
        // Nasals
        "m": "m",
        "n": "n",
        "ŋ": "ng",   // 'ng' as in 'pisang'
        
        // Approximants
        "l": "l",
        "ɫ": "l",
        "ɹ": "r",
        "r": "r",
        "ɾ": "r",
        "w": "w",
        "j": "y",    // Indo 'y' (yoyo) matches English /j/
        
        // ═══════════════════════════════════════════════════════════════
        // SYLLABIC CONSONANTS
        // ═══════════════════════════════════════════════════════════════
        "əl": "el",
        "l̩": "el",
        "ən": "en",
        "n̩": "en",
        "əm": "em",
        "m̩": "em",
    ]
    
    /// Multi-character IPA sequences that should be matched first (longest first)
    private lazy var sortedIPAKeys: [String] = {
        return ipaToRespelling.keys.sorted { $0.count > $1.count }
    }()
    
    // MARK: - Public API
    
    /// Converts an array of IPA phonemes to a respelling string
    public func respell(phonemes: [String]) -> String {
        let respelled = phonemes.map { convertPhoneme($0) }
        return respelled.joined(separator: "·")
    }
    
    /// Converts an array of IPA phonemes to a respelling string with word breaks
    public func respell(phonemesByWord: [[String]]) -> String {
        let wordRespellings = phonemesByWord.map { wordPhonemes in
            wordPhonemes.map { convertPhoneme($0) }.joined()
        }
        return wordRespellings.joined(separator: " ")
    }
    
    /// Converts a single IPA phoneme to its respelling
    public func convertPhoneme(_ phoneme: String) -> String {
        // Normalize the input
        let normalized = phoneme
            .precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "ˈ", with: "")
            .replacingOccurrences(of: "ˌ", with: "")
            .replacingOccurrences(of: "ː", with: "") // Handle length marks
        
        // Check for exact match first
        if let respelling = ipaToRespelling[normalized] {
            return respelling
        }
        
        // Try matching longest sequences first
        var result = normalized
        for ipaKey in sortedIPAKeys {
            if result.contains(ipaKey), let respelling = ipaToRespelling[ipaKey] {
                result = result.replacingOccurrences(of: ipaKey, with: respelling)
            }
        }
        
        return result
    }
    
    /// Creates a formatted pronunciation guide for display
    public func formatPronunciationGuide(word: String, phonemes: [String]) -> String {
        let respelling = phonemes.map { convertPhoneme($0) }.joined()
        return "\(word) (\(respelling.uppercased()))"
    }
    
    /// Creates a simple pronunciation guide without IPA
    public func simpleRespelling(phonemes: [String]) -> String {
        return phonemes.map { convertPhoneme($0) }.joined().uppercased()
    }
}

// MARK: - Extension for WordScore

extension WordScore {
    /// Returns a human-readable respelling of the target pronunciation
    var respelling: String {
        let targetPhonemes = alignedPhonemes.compactMap { $0.target }
        return PronunciationRespeller.shared.simpleRespelling(phonemes: targetPhonemes)
    }
}
