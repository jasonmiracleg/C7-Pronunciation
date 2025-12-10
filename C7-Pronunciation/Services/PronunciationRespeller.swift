//
//  PronunciationRespeller.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 21/11/25.
//  IMPROVED: More descriptive respellings for better user understanding
//

import Foundation

/// Converts IPA phonetic transcriptions to human-readable respelling
/// Optimized for clarity and user comprehension
public class PronunciationRespeller {
    
    public static let shared = PronunciationRespeller()
    
    private init() {}
    
    // MARK: - IPA to Respelling Mappings
    
    /// Maps IPA symbols to descriptive respelling equivalents
    /// Each respelling is designed to be distinctive and interpretable
    private let ipaToRespelling: [String: String] = [
        // VOWELS - Monophthongs (Short)
        "ɪ": "ih",          // KIT: bit, sit (short i)
        "ᵻ": "ih",          // Unstressed KIT
        "ɨ": "ih",
        
        "ɛ": "eh",          // DRESS: bet, set (short e)
        "e": "ay",          // Close-mid: sometimes for FACE
        
        "æ": "aa",          // TRAP: bat, cat (short a)
        "a": "ah",          // Generic open front
        
        "ɒ": "aw",          // LOT (British): got, hot
        
        "ɑ": "ah",          // PALM/LOT (American): father, hot
        "ɑː": "ahh",        // Long version
        
        "ʌ": "uh",          // STRUT: but, cup (short u)
        "ɐ": "uh",
        
        "ʊ": "uu",          // FOOT: put, good (short oo)
        "u": "uu",
        
        "ə": "uh",          // Schwa: about, comma (unstressed)
        "ɚ": "er",          // R-colored schwa (US)
        "ɝ": "er",
        
        // VOWELS - Monophthongs (Long)
        "iː": "ee",         // FLEECE: beat, see (long e)
        "i": "ee",
        
        "uː": "oo",         // GOOSE: boot, food (long oo)
        
        "ɔː": "aw",         // THOUGHT: caught, taught
        "ɔ": "aw",
        
        "ɜː": "ur",         // NURSE: bird, hurt
        "ɜ": "ur",
        
        "eː": "ay",
        "oː": "oh",
        
        // VOWELS - Diphthongs (Major)
        "eɪ": "ay",         // FACE: day, say, make
        
        "aɪ": "eye",        // PRICE: my, lie, high
        
        "ɔɪ": "oy",         // CHOICE: boy, join
        "oɪ": "oy",
        
        "oʊ": "oh",         // GOAT: go, show (American)
        "əʊ": "oh",         // GOAT: (British)
        
        "aʊ": "ow",         // MOUTH: now, out, how
        
        // VOWELS - R-colored Diphthongs
        "ɪə": "eer",        // NEAR: here, fear
        "ɪɹ": "eer",
        "iə": "eer",
        "iːə": "eer",
        "iɹ": "eer",
        
        "ɛə": "air",        // SQUARE: hair, there
        "eə": "air",
        "ɛɹ": "air",
        "eɹ": "air",
        
        "ɛːɹ": "air",
        "eːɹ": "air",
        
        "ʊə": "oor",        // CURE: tour, pure
        "ʊɹ": "oor",
        "uə": "oor",
        "uːɹ": "oor",
        
        "ɑːɹ": "ar",        // START: car, far
        "ɑɹ": "ar",
        
        "ɔːɹ": "or",        // NORTH: or, for
        "ɔɹ": "or",
        "oːɹ": "or",
        "oɹ": "or",
        "oʊɹ": "or",
        
        "əɹ": "er",
        
        // CONSONANTS - Plosives
        "p": "p",
        "b": "b",
        "t": "t",
        "d": "d",
        "k": "k",
        "ɡ": "g",
        "g": "g",
        "ʔ": "",            // Glottal stop (silent)
        
        // CONSONANTS - Fricatives
        "f": "f",
        "v": "v",
        "θ": "th",          // Thin, think (voiceless)
        "ð": "th",          // This, that (voiced) - same spelling for simplicity
        "s": "s",
        "z": "z",
        "ʃ": "sh",          // Ship, cash
        "ʒ": "zh",          // Measure, vision
        "h": "h",
        "x": "kh",
        
        // CONSONANTS - Affricates
        "tʃ": "ch",         // Church, match
        "dʒ": "j",          // Judge, age
        
        // CONSONANTS - Nasals
        "m": "m",
        "n": "n",
        "ŋ": "ng",          // Sing, think
        
        // CONSONANTS - Approximants
        "l": "l",
        "ɫ": "l",
        "ɬ": "l",
        
        "ɹ": "r",
        "r": "r",
        "ɾ": "r",           // Flap/tap
        
        "w": "w",
        "j": "y",
        "ʍ": "wh",
        
        // SYLLABIC CONSONANTS
        "əl": "ul",
        "l̩": "ul",
        "ən": "un",
        "n̩": "un",
        "əm": "um",
        "m̩": "um",
        
        // SPECIAL & RARE
        "ˈ": "",
        "ˌ": "",
        "ː": "",
        
        "aː": "ahh",
        "ɛː": "eh",
        "ɪː": "ee",
        "ʊː": "oo",
        "ɒː": "aw",
        "ʊ̈": "uu",
        
        "y": "ue",
        "ø": "oe",
        "œ": "oe",
    ]
    
    /// Examples for each phoneme (for UI hints/tooltips)
    private let phonemeExamples: [String: String] = [
        "ih": "bit, sit",
        "eh": "bet, set",
        "aa": "bat, cat",
        "ah": "father, hot",
        "uh": "but, cup",
        "uu": "put, good",
        "ee": "beat, see",
        "oo": "boot, food",
        "aw": "caught, taught",
        "ur": "bird, hurt",
        "ay": "day, say",
        "eye": "my, lie",
        "oy": "boy, join",
        "oh": "go, show",
        "ow": "now, out",
        "eer": "here, fear",
        "air": "hair, there",
        "oor": "tour, pure",
        "ar": "car, far",
        "or": "or, for",
        "er": "better, father",
    ]
    
    /// Multi-character IPA sequences (longest first for proper matching)
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
        let normalized = phoneme
            .precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "ˈ", with: "")
            .replacingOccurrences(of: "ˌ", with: "")
            .replacingOccurrences(of: "ˑ", with: "")
            .replacingOccurrences(of: "̆", with: "")
            .replacingOccurrences(of: "̃", with: "")
            .replacingOccurrences(of: "̊", with: "")
            .replacingOccurrences(of: "̥", with: "")
        
        for ipaKey in sortedIPAKeys {
            if normalized == ipaKey, let respelling = ipaToRespelling[ipaKey] {
                return respelling
            }
        }
        
        var result = normalized
        for ipaKey in sortedIPAKeys {
            if result.contains(ipaKey), let respelling = ipaToRespelling[ipaKey] {
                result = result.replacingOccurrences(of: ipaKey, with: respelling)
            }
        }
        
        if result == normalized {
            if normalized.contains("ː") {
                let base = normalized.replacingOccurrences(of: "ː", with: "")
                if let respelling = ipaToRespelling[base] {
                    return respelling
                }
            }
            
            let stripped = normalized.unicodeScalars.filter { scalar in
                !CharacterSet(charactersIn: "\u{0300}"..."\u{036F}").contains(scalar)
            }
            let strippedString = String(String.UnicodeScalarView(stripped))
            
            if strippedString != normalized, let respelling = ipaToRespelling[strippedString] {
                return respelling
            }
        }
        
        return result.isEmpty ? normalized : result
    }
    
    /// Get example words for a phoneme (for UI hints)
    public func getExample(for phoneme: String) -> String? {
        let respelled = convertPhoneme(phoneme)
        return phonemeExamples[respelled]
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
