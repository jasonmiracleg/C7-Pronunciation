//
//  PronunciationRespeller.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 21/11/25.
//

import Foundation

/// Converts IPA phonetic transcriptions to human-readable respelling
/// Optimized for clarity and distinctiveness
public class PronunciationRespeller {
    
    public static let shared = PronunciationRespeller()
    
    private init() {}
    
    // MARK: - IPA to Respelling Mappings
    
    private let ipaToRespelling: [String: String] = [
        // ═══════════════════════════════════════════════════════════════
        // VOWELS - Monophthongs (Short)
        // ═══════════════════════════════════════════════════════════════
        
        // KIT vowel (short i)
        "ɪ": "i",
        "ᵻ": "i",       // Unstressed KIT
        "ɨ": "i",       // Alternative notation
        
        // DRESS vowel
        "ɛ": "eh",
        "e": "e",       // Close-mid front (sometimes used for DRESS)
        
        // TRAP vowel
        "æ": "a",
        
        // Generic low vowels
        "a": "ah",      // Open front unrounded
        
        // LOT vowel (British)
        "ɒ": "o",       // Open back rounded
        
        // PALM/LOT vowel (American)
        "ɑ": "ah",      // Open back unrounded
        // Long version
        
        // STRUT vowel
        "ʌ": "u",       // Open-mid back unrounded
        "ɐ": "u",       // Near-open central
        
        // FOOT vowel
        "ʊ": "oo",      // Near-close near-back rounded
        "u": "oo",      // Close back rounded (short)
        
        // Schwa and unstressed vowels
        "ə": "uh",      // Mid central vowel
        "ɚ": "er",      // R-colored schwa (US)
        "ɝ": "er",      // R-colored mid central (US)
        
        // ═══════════════════════════════════════════════════════════════
        // VOWELS - Monophthongs (Long)
        // ═══════════════════════════════════════════════════════════════
        
        // FLEECE vowel
        "iː": "ee",     // Long close front unrounded
        "i": "ee",      // Sometimes written without length mark
        
        // GOOSE vowel
        "uː": "ooh",    // Long close back rounded
        
        // THOUGHT vowel
        // Long open-mid back rounded
        "ɔ": "aw",      // Short version
        
        // NURSE vowel
        "ɜː": "ur",     // Long open-mid central unrounded
        // Short version
        
        // Other long vowels
        "eː": "ay",     // Long close-mid front (sometimes for FACE)
        "oː": "oh",     // Long close-mid back rounded
        
        // ═══════════════════════════════════════════════════════════════
        // VOWELS - Diphthongs (Major)
        // ═══════════════════════════════════════════════════════════════
        
        // FACE (Day, Say, Make)
        "eɪ": "ay",
        
        // PRICE (My, Lie, High)
        "aɪ": "eye",
        
        // CHOICE (Boy, Noise, Join)
        "ɔɪ": "oy",
        "oɪ": "oy",     // Alternative notation
        
        // GOAT (Go, No, Show)
        "oʊ": "oh",     // American
        "əʊ": "oh",     // British
        
        // MOUTH (Now, Out, How)
        "aʊ": "ow",
        
        // ═══════════════════════════════════════════════════════════════
        // VOWELS - Centering Diphthongs (with R-coloring)
        // ═══════════════════════════════════════════════════════════════
        
        // NEAR (Here, Fear, Beer)
        "ɪə": "eer",
        "ɪɹ": "eer",    // With explicit R
        "iə": "eer",    // Alternative
        "iːə": "eer",   // Long version
        "iɹ": "eer",    // Short with R
        
        // SQUARE (Hair, There, Care)
        "ɛə": "air",
        "eə": "air",    // Alternative
        "ɛɹ": "air",    // With explicit R
        "eɹ": "air",    // Alternative with R
        // American (no diphthong, just long vowel)
        "ɛːɹ": "air",   // American with R
        "eːɹ": "air",   // Alternative
        
        // CURE (Tour, Pure, Sure)
        "ʊə": "oor",
        "ʊɹ": "oor",    // With explicit R
        "uə": "oor",    // Alternative
        "uːɹ": "oor",   // Alternative with R
        
        // START (Car, Far, Star)
        "ɑː": "aa",     // Already defined above
        "ɑːɹ": "ar",    // With R
        "ɑɹ": "ar",     // Short version with R
        
        // NORTH/FORCE (Or, For, Your)
        "ɔːɹ": "or",
        "ɔɹ": "or",     // Short version
        "oːɹ": "or",    // Alternative
        "oɹ": "or",     // Short alternative
        "oʊɹ": "or",    // American variant
        
        // LETTER (unstressed final R)
        "əɹ": "er",
        
        // ═══════════════════════════════════════════════════════════════
        // CONSONANTS - Plosives (Stops)
        // ═══════════════════════════════════════════════════════════════
        
        // Voiceless
        "p": "p",
        "t": "t",
        "k": "k",
        "ʔ": "",        // Glottal stop (silent)
        
        // Voiced
        "b": "b",
        "d": "d",
        "g": "g",
        "ɡ": "g",       // Alternative notation
        
        // ═══════════════════════════════════════════════════════════════
        // CONSONANTS - Fricatives
        // ═══════════════════════════════════════════════════════════════
        
        // Voiceless
        "f": "f",
        "θ": "th",      // Thin, Think
        "s": "s",
        "ʃ": "sh",      // Ship, Cash
        "h": "h",
        "x": "kh",      // Loch (rare in English)
        
        // Voiced
        "v": "v",
        "ð": "dh",      // This, That
        "z": "z",
        "ʒ": "zh",      // Measure, Vision
        
        // ═══════════════════════════════════════════════════════════════
        // CONSONANTS - Affricates
        // ═══════════════════════════════════════════════════════════════
        
        "tʃ": "ch",     // Church, Match
        "dʒ": "j",      // Judge, Age
        
        // ═══════════════════════════════════════════════════════════════
        // CONSONANTS - Nasals
        // ═══════════════════════════════════════════════════════════════
        
        "m": "m",
        "n": "n",
        "ŋ": "ng",      // Sing, Think
        
        // ═══════════════════════════════════════════════════════════════
        // CONSONANTS - Approximants
        // ═══════════════════════════════════════════════════════════════
        
        // Liquids
        "l": "l",
        "ɫ": "l",       // Dark L (as in "ball")
        "ɬ": "l",       // Voiceless lateral (rare)
        
        // Rhotics
        "ɹ": "r",       // Approximant R (most common in English)
        "r": "r",       // Trilled R
        "ɾ": "r",       // Tap/Flap (American T)
        
        // Glides
        "w": "w",
        "j": "y",       // Yes, Yellow
        "ʍ": "wh",      // Which (for dialects that distinguish from w)
        
        // ═══════════════════════════════════════════════════════════════
        // SYLLABIC CONSONANTS
        // ═══════════════════════════════════════════════════════════════
        
        "əl": "ul",     // Bottle
        "l̩": "ul",      // Syllabic L
        "ən": "un",     // Button
        "n̩": "un",      // Syllabic N
        "əm": "um",     // Rhythm
        "m̩": "um",      // Syllabic M
        
        // ═══════════════════════════════════════════════════════════════
        // SPECIAL CASES AND VARIANTS
        // ═══════════════════════════════════════════════════════════════
        
        // Stress markers (should be removed in preprocessing, but just in case)
        "ˈ": "",        // Primary stress
        "ˌ": "",        // Secondary stress
        "ː": "",        // Length mark (already handled in preprocessing)
        
        // Length variations
        "aː": "aa",
        "ɛː": "eh",
        "ɪː": "ee",
        "ɔː": "aw",     // Already defined
        "ʊː": "ooh",
        
        // Rare/archaic
        "ɜ": "ur",      // Short NURSE
        "ɒː": "o",      // Long LOT (rare)
        "ʊ̈": "oo",      // Centralized FOOT
        
        // Non-standard or loan words
        "y": "ue",      // French-like vowel (rare)
        "ø": "oe",      // Rounded front vowel (rare)
        "œ": "oe",      // Open-mid front rounded (rare)
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
        // Normalize the input - remove stress marks and diacritics we don't need
        let normalized = phoneme
            .precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "ˈ", with: "")   // Primary stress
            .replacingOccurrences(of: "ˌ", with: "")   // Secondary stress
            .replacingOccurrences(of: "ˑ", with: "")   // Half-long
            .replacingOccurrences(of: "̆", with: "")    // Extra-short
            .replacingOccurrences(of: "̃", with: "")    // Nasalization
            .replacingOccurrences(of: "̊", with: "")    // Voiceless
            .replacingOccurrences(of: "̥", with: "")    // Voiceless (alternative)
        
        // Try longest matches first (e.g., "aɪə" before "aɪ")
        for ipaKey in sortedIPAKeys {
            if normalized == ipaKey, let respelling = ipaToRespelling[ipaKey] {
                return respelling
            }
        }
        
        // If no exact match, try partial replacement for complex sequences
        var result = normalized
        for ipaKey in sortedIPAKeys {
            if result.contains(ipaKey), let respelling = ipaToRespelling[ipaKey] {
                result = result.replacingOccurrences(of: ipaKey, with: respelling)
            }
        }
        
        // If still no match, try fallback mappings for common patterns
        if result == normalized {
            // Handle length marks that might still be there
            if normalized.contains("ː") {
                let base = normalized.replacingOccurrences(of: "ː", with: "")
                if let respelling = ipaToRespelling[base] {
                    return respelling
                }
            }
            
            // Handle any remaining combining diacritics
            let stripped = normalized.unicodeScalars.filter { scalar in
                // Keep only base characters, not combining marks
                !CharacterSet(charactersIn: "\u{0300}"..."\u{036F}").contains(scalar)
            }
            let strippedString = String(String.UnicodeScalarView(stripped))
            
            if strippedString != normalized, let respelling = ipaToRespelling[strippedString] {
                return respelling
            }
        }
        
        // Last resort: return the original if we can't convert it
        // This helps us identify missing mappings
        return result.isEmpty ? normalized : result
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
