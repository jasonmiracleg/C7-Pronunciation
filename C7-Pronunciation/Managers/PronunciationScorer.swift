//
//  PronunciationScorer.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//  v10.7: True dual-dialect scoring per word
//      - v4-v9: Base functionality, rhotic matching, coarticulation, gemination
//      - v10-v10.6: Two-tier scoring, dialect equivalences, expanded whitelist
//      - v10.7 NEW: Scores against BOTH UK and US dialects for each word
//          * Takes the HIGHER score for each word (not pre-selecting one dialect)
//          * Allows mixed dialect usage (e.g., US "privacy" /praɪvəsi/ vs UK /prɪvəsi/)
//          * Users can naturally mix British and American pronunciations
//      - v10.7 FIX: Added safety checks for empty/short recordings
//
//  DESIGN PHILOSOPHY:
//  - Function words (whitelisted): LENIENT - accept dialect variants, reductions
//  - All other words: STRICT - only accept eSpeak's two dialect outputs + core equivalences
//  - DUAL DIALECT: Each word scored against BOTH UK and US, best score wins
//

import Foundation

// MARK: - Pronunciation Scorer Singleton

public class PronunciationScorer {
    public static let shared = PronunciationScorer()
    
    private let espeakManager = EspeakManager.shared
    
    /// Toggle to enable/disable phoneme similarity groups
    public var usePhonemeSimilarityGroups: Bool = false
    
    /// Minimum confidence score to accept a "similar variant"
    /// If the model's confidence is below this, don't accept the variant
    private let minimumVariantConfidence: Double = 0.30
    
    /// Penalty factor for excessive insertions (extra sounds)
    /// Each insertion beyond the threshold reduces the word score
    private let insertionPenaltyFactor: Double = 0.05
    private let insertionPenaltyThreshold: Int = 1  // Allow 1 free insertion per word
    
    /// Penalty for actual mispronunciations (not variants)
    /// Each mispronounced phoneme adds this penalty to the word
    private let mispronunciationPenaltyFactor: Double = 0.15
    
    /// NEW: Higher penalty for vowel mispronunciations (vowels are "crucial")
    private let vowelMispronunciationPenaltyFactor: Double = 0.25
    
    /// NEW: Minimum penalty for any mispronunciation in strict mode
    private let strictModeMispronunciationPenalty: Double = 0.20
    
    private init() { }
    
    // MARK: - Core Dialect Equivalences (Accepted in Strict Mode)
    
    /// These are FUNDAMENTAL UK/US vowel differences that must be accepted even in strict mode.
    /// CRITICAL: These must be TRUE EQUIVALENCES - the same phoneme category across dialects,
    /// NOT "similar sounding" phonemes that happen to be confused.
    ///
    /// Word-specific variations (like "what" using ʌ in US) should go in functionWordReductions,
    /// not here, to maintain strictness for other words.
    private let coreDialectEquivalences: [String: Set<String>] = [
        // ══════════════════════════════════════════════════════════════════════
        // NOTATION DIFFERENCES - Same exact sound, different IPA symbols
        // ══════════════════════════════════════════════════════════════════════
        
        // GOAT diphthong: UK əʊ = US oʊ (IDENTICAL sound, notation only!)
        "əʊ": ["oʊ", "o", "oː"],
        "oʊ": ["əʊ", "o", "oː"],
        
        // TRAP vowel notation variants
        "æ": ["a"],
        "a": ["æ"],
        
        // Schwa notation variants (always equivalent)
        "ə": ["ɐ", "ᵻ"],
        "ɐ": ["ə"],
        "ᵻ": ["ə", "ɪ"],
        
        // R sound variants (all equivalent)
        "ɹ": ["r", "ɾ"],
        "r": ["ɹ", "ɾ"],
        
        // ══════════════════════════════════════════════════════════════════════
        // TRUE UK/US PHONEME CATEGORY DIFFERENCES
        // These represent the same lexical set across dialects
        // ══════════════════════════════════════════════════════════════════════
        
        // LOT vowel: UK ɒ = US ɑː/ɑ (e.g., "lot", "hot", "policy", "problem")
        // NOTE: Does NOT include ʌ - that's word-specific (what, was, because)
        "ɒ": ["ɑː", "ɑ", "ɔ"],
        "ɑː": ["ɒ", "ɑ"],
        "ɑ": ["ɒ", "ɑː"],
        
        // SQUARE vowel: UK eə/ɛə = US ɛ (+ rhotic ɹ follows)
        // In American English, "aware" = /əˈwɛɹ/, "care" = /kɛɹ/
        // The centering diphthong becomes a monophthong before /r/
        "eə": ["ɛ", "ɛə", "e"],
        "ɛə": ["ɛ", "eə", "e"],
        
        // T-flapping: In American English, /t/ and /d/ between vowels become [ɾ]
        "ɾ": ["t", "d"],
        "t": ["ɾ"],
        "d": ["ɾ"],
        
        // Vowel length - same quality, different length
        "iː": ["i"],
        "i": ["iː"],
        "u": ["uː"],
        "uː": ["u"],
        
        // ══════════════════════════════════════════════════════════════════════
        // RHOTIC VOWEL EQUIVALENCES (handled separately in isRhoticVowelVariant)
        // Listed here as backup for direct lookups
        // ══════════════════════════════════════════════════════════════════════
        
        // CURE vowel: UK ʊə = US ʊɹ/ɚ (sure, poor, tour)
        "ʊə": ["ɚ", "ʊɹ", "ɔː", "ɔːɹ", "uː", "uːɹ"],
        "ɚ": ["ʊə", "ə", "ɜː", "ʊɹ"],
        
        // ══════════════════════════════════════════════════════════════════════
        // SYLLABIC CONSONANTS (model segmentation differences)
        // ══════════════════════════════════════════════════════════════════════
        "əl": ["l̩", "ᵊl", "l"],
        "əm": ["m̩", "ᵊm", "m"],
        "ən": ["n̩", "ᵊn", "n"],
    ]
    
    /// Word-final voicing neutralization - very common in natural speech
    /// The voicing distinction is often lost at word boundaries
    private let wordFinalVoicingPairs: [String: Set<String>] = [
        "z": ["s"],
        "s": ["z"],
        "v": ["f"],
        "f": ["v"],
        "ð": ["θ"],
        "θ": ["ð"],
        "ʒ": ["ʃ"],
        "ʃ": ["ʒ"],
        "b": ["p"],
        "p": ["b"],
        "d": ["t"],
        "t": ["d"],
        "g": ["k"],
        "k": ["g"],
        "ɡ": ["k"],
        "dʒ": ["tʃ"],
        "tʃ": ["dʒ"],
    ]
    
    /// Unstressed vowel reductions - these are common in natural connected speech
    /// BUT should be LIMITED to avoid being too lenient.
    ///
    /// BIDIRECTIONAL for schwa/KIT: In unstressed syllables, ə and ɪ are often
    /// interchangeable (e.g., "meticulous" final syllable, "possible", "difficult")
    private let unstressedVowelReductions: [String: Set<String>] = [
        // Schwa ↔ KIT (bidirectional in unstressed syllables)
        "ɪ": ["ə", "ɨ", "ᵻ"],
        "ə": ["ɪ", "ɨ", "ᵻ"],  // NEW: schwa can be realized as KIT
        
        // DRESS → schwa/KIT (in prefixes like "en-", "ex-")
        "ɛ": ["ə", "ɪ"],
        
        // STRUT/schwa equivalence
        "ʌ": ["ə", "ɐ"],
        "ɐ": ["ə"],
        
        // FOOT ↔ GOOSE (these are very close and often interchangeable)
        // e.g., "meticulous" can be /mɪˈtɪkjʊləs/ or /mɪˈtɪkjuːləs/
        "ʊ": ["ə", "uː", "u"],
        "uː": ["ʊ", "u"],
        "u": ["ʊ", "uː"],
    ]
    
    // MARK: - Phonetic Similarity Data
    
    /// Dialect-specific phoneme mappings - GLOBAL equivalences for ALL words
    /// BIDIRECTIONAL - both rhotic→non-rhotic AND non-rhotic→rhotic must be covered
    /// This ensures that regardless of which dialect eSpeak generates, we accept the other
    ///
    /// NOTE: In v10, these are ONLY used for whitelisted function words.
    /// Non-function words use STRICT matching (dialect variants from eSpeak only)
    private let dialectPhonemeEquivalents: [String: Set<String>] = [
        // ══════════════════════════════════════════════════════════════════════
        // R-COLORED VOWELS (US rhotic ↔ UK non-rhotic) - BIDIRECTIONAL
        // ══════════════════════════════════════════════════════════════════════
        
        // NURSE vowel: ɝ (US) ↔ ɜː (UK)
        "ɝ": ["ɜː", "ɜ", "ɜːɹ", "ɚ"],
        "ɜː": ["ɝ", "ɚ", "ɜ", "ɜːɹ", "ɪɹ", "ɪə"],
        "ɜːɹ": ["ɜː", "ɝ", "ɜ", "ɚ"],
        "ɜ": ["ɜː", "ɝ", "ɚ", "ɜːɹ"],
        
        // Schwa-R: ɚ (US) ↔ ə (UK)
        "ɚ": ["ə", "əɹ", "ɜː", "ɜ", "ɝ"],
        
        // START vowel: ɑːɹ (US) ↔ ɑː (UK)
        "ɑːɹ": ["ɑː", "ɑ", "ɑɹ", "ɔːɹ", "ɔː"],  // FIXED: Added ɔːɹ, ɔː - these merge in some dialects
        "ɑː": ["ɑːɹ", "ɑ", "ɑɹ", "ɔː"],
        
        // NORTH/FORCE vowel: ɔːɹ (US) ↔ ɔː (UK)
        // KEY FIX: Added ɑːɹ, ɑː - "or" can be /ɔːɹ/ or /ɑːɹ/ in American English
        "ɔːɹ": ["ɔː", "ɔ", "oː", "oːɹ", "ɔɹ", "oʊ", "oʊɹ", "ɑːɹ", "ɑː"],
        "ɔː": ["ɔːɹ", "ɔ", "oː", "oːɹ", "ɔɹ", "oʊ", "oʊɹ", "ɑːɹ", "ɑː"],
        "oːɹ": ["oː", "ɔː", "ɔːɹ", "ɔ", "oʊ", "oʊɹ"],
        "oː": ["oːɹ", "ɔː", "ɔːɹ", "ɔ", "oʊ"],
        "ɔɹ": ["ɔː", "ɔːɹ", "ɔ", "oʊɹ", "ɑːɹ"],
        "oʊɹ": ["ɔːɹ", "ɔː", "oːɹ", "oː", "oʊ"],
        
        // SQUARE vowel: ɛɹ (US) ↔ ɛə (UK)
        "ɛɹ": ["ɛə", "eə", "ɛː", "eɹ"],
        "ɛə": ["ɛɹ", "eɹ", "ɛː", "eə"],
        "eə": ["ɛɹ", "eɹ", "ɛə", "ɛː"],
        "eɹ": ["ɛə", "eə", "ɛɹ"],
        
        // NEAR vowel: ɪɹ (US) ↔ ɪə (UK)
        "ɪɹ": ["ɪə", "iə", "ɜː", "ɜ", "ɪ", "iɹ"],
        "ɪə": ["ɪɹ", "iɹ", "ɜː", "ɜ", "ɪ"],
        "iɹ": ["ɪə", "iə", "ɜː", "ɪɹ"],
        "iə": ["ɪɹ", "iɹ", "ɪə", "ɜː"],
        
        // CURE vowel: ʊɹ (US) ↔ ʊə (UK)
        "ʊɹ": ["ʊə", "uə", "ɔː", "ɔːɹ", "ʊ"],
        "ʊə": ["ʊɹ", "uɹ", "ɔː", "ɔːɹ"],
        "uɹ": ["ʊə", "uə", "ʊɹ"],
        "uə": ["ʊɹ", "uɹ", "ʊə"],
        
        // ══════════════════════════════════════════════════════════════════════
        // SCHWA VARIANTS (notation differences, same phoneme)
        // ══════════════════════════════════════════════════════════════════════
        "ə": ["ɐ", "ᵻ", "ɚ"],
        "ɐ": ["ə", "ʌ"],
        "ᵻ": ["ə", "ɪ", "ɐ"],
        
        // ══════════════════════════════════════════════════════════════════════
        // LOT-CLOTH-THOUGHT vowels (US/UK differences)
        // ══════════════════════════════════════════════════════════════════════
        "ɑ": ["ɒ", "ɔ", "ɑː"],
        "ɒ": ["ɑ", "ɔ", "ʌ", "ɑː"],
        "ɔ": ["ɔː", "ɒ", "ɑ"],
        
        // ══════════════════════════════════════════════════════════════════════
        // OTHER VOWEL VARIATIONS
        // ══════════════════════════════════════════════════════════════════════
        
        // TRAP vowel notation
        "æ": ["a"],
        "a": ["æ"],
        
        // KIT vowel (notation only)
        "ɪ": ["i", "ɪ̈", "ɨ"],
        "i": ["ɪ"],
        
        // GOAT diphthong
        "oʊ": ["əʊ", "o", "oː", "ɔː"],
        "əʊ": ["oʊ", "o", "oː", "ɔː"],
        
        // FLEECE vowel (length variants)
        "iː": ["i", "ɪ"],
        
        // FOOT vowel
        "ʊ": ["u", "ɷ"],
        "u": ["ʊ"],
        
        // GOOSE vowel
        "uː": ["u", "ʊ"],
        
        // ══════════════════════════════════════════════════════════════════════
        // DIPHTHONG PARTIAL MATCHES
        // When model hears only part of a diphthong, accept the partial
        // This happens with fast speech or model segmentation issues
        // NOTE: These are ONE-WAY - we accept partial as full, not vice versa
        // ══════════════════════════════════════════════════════════════════════
        "aɪ": ["a", "æ", "ɑ", "aː"],
        "aʊ": ["a", "æ", "ɑ"],
        "ɔɪ": ["ɔ", "ɔː", "o"],
        "eɪ": ["e", "ɛ", "eː"],
        
        // ══════════════════════════════════════════════════════════════════════
        // CONSONANT VARIATIONS
        // ══════════════════════════════════════════════════════════════════════
        "ɾ": ["t", "d"],
        "t": ["ɾ"],
        "ɹ": ["r", "ɾ"],
        "r": ["ɹ", "ɾ"],
        "l": ["ɫ", "ɫ̩"],
        "ɫ": ["l"],
        "ʌ": ["ɐ", "ə"],
        
        // ══════════════════════════════════════════════════════════════════════
        // COARTICULATION PATTERNS (cross-word sound merging)
        // ══════════════════════════════════════════════════════════════════════
        "j": ["dʒ", "tʃ"],
        "dʒ": ["j"],
        "tʃ": ["j"],
    ]
    
    /// Function word reductions - ONLY for specific words
    /// ENHANCED: Now includes rhotic ↔ non-rhotic vowel variants for common words
    ///
    /// v10: These words get LENIENT scoring - the full dialectPhonemeEquivalents apply
    private let functionWordReductions: [String: [String: Set<String>]] = [
        // Articles
        "a": ["eɪ": ["ə"], "æ": ["ə"]],
        "an": ["æ": ["ə"], "a": ["ə"]],
        "the": [
            "iː": ["ə", "ɪ", "i"],
            "i": ["ə", "ɪ", "iː"],
            "ə": ["iː", "ɪ", "i"],
            "ɪ": ["ə", "iː", "i"],
        ],
        
        // ══════════════════════════════════════════════════════════════════════
        // PREPOSITIONS - Enhanced with rhotic variants
        // ══════════════════════════════════════════════════════════════════════
        "to": ["uː": ["ə", "ʊ", "u"], "u": ["ə", "ʊ"]],
        
        // "for" - KEY FIX: Can be /fɔː/, /fɔːɹ/, /fɜː/, /fɜːɹ/, /fə/, /fɑːɹ/
        "for": [
            "ɔː": ["ə", "ɔ", "ɔːɹ", "ɔɹ", "ɜː", "ɜːɹ", "ɝ", "ɑːɹ", "ɑː"],
            "ɔːɹ": ["ə", "ɚ", "ər", "ɔː", "ɜː", "ɜːɹ", "ɝ", "ɑːɹ", "ɑː"],
            "ɔ": ["ə", "ɔː", "ɔːɹ", "ɜː", "ɑː"],
            "ɜː": ["ə", "ɔː", "ɔːɹ", "ɜːɹ", "ɝ", "ɚ", "ɑːɹ"],
            "ɜːɹ": ["ə", "ɔː", "ɔːɹ", "ɜː", "ɝ", "ɑːɹ"],
        ],
        
        "of": ["ʌ": ["ə"], "ɒ": ["ə"], "ɑ": ["ə"]],
        "from": ["ʌ": ["ə"], "ɒ": ["ə"], "ɑ": ["ə"]],
        "at": ["æ": ["ə"], "a": ["ə"]],
        "as": ["æ": ["ə"], "a": ["ə"]],
        "with": ["ɪ": ["ə", "ɪ̈"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // CONJUNCTIONS
        // ══════════════════════════════════════════════════════════════════════
        "and": ["æ": ["ə", "ɛ"], "a": ["ə"], "ɛ": ["ə"]],
        "but": ["ʌ": ["ə"], "ɐ": ["ə"]],
        // "or" - KEY FIX: Can be /ɔː/, /ɔːɹ/, /ɑːɹ/
        "or": [
            "ɔː": ["ə", "ɔːɹ", "ɔɹ", "ɑːɹ", "ɑː"],
            "ɔːɹ": ["ə", "ɚ", "ɔː", "ɑːɹ", "ɑː"],
            "ɑːɹ": ["ɔː", "ɔːɹ", "ɑː", "ə"],
            "ɑː": ["ɔː", "ɔːɹ", "ɑːɹ", "ə"],
        ],
        "than": ["æ": ["ə"], "a": ["ə"]],
        "that": ["æ": ["ə"], "a": ["ə"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // INTERROGATIVES - LOT-STRUT variation (UK ɒ = US ʌ in these words)
        // ══════════════════════════════════════════════════════════════════════
        "what": [
            "ɒ": ["ʌ", "ɑ", "ə"],  // UK "wɒt" = US "wʌt"
            "ʌ": ["ɒ", "ɑ", "ə"],  // Reverse mapping
        ],
        "want": [
            "ɒ": ["ɑː", "ɑ", "ʌ"],  // UK "wɒnt" = US "wɑːnt" or "wʌnt"
            "ɑː": ["ɒ", "ɑ"],
        ],
        "was": [
            "ɒ": ["ʌ", "ə", "ɑ"],  // UK "wɒz" = US "wʌz"
            "ʌ": ["ɒ", "ə", "ɑ"],
        ],
        "watch": [
            "ɒ": ["ɑː", "ɑ", "ʌ"],
        ],
        "because": [
            "ɒ": ["ɔː", "ʌ", "ə"],
            "ɔː": ["ɒ", "ʌ", "ə"],
        ],
        
        // ══════════════════════════════════════════════════════════════════════
        // AUXILIARIES - Enhanced with rhotic variants
        // ══════════════════════════════════════════════════════════════════════
        "is": ["ɪ": ["ə"]],
        "am": ["æ": ["ə"], "a": ["ə"]],
        "are": [
            "ɑː": ["ə", "ɑːɹ", "ɑɹ"],
            "ɑːɹ": ["ə", "ɚ", "ɑː"],
            "ɑ": ["ə", "ɑː"],
        ],
        "were": [
            "ɜː": ["ə", "ɜːɹ", "ɝ"],
            "ɝ": ["ə", "ɚ", "ɜː"],
            "ɜːɹ": ["ə", "ɜː", "ɝ"],
        ],
        "been": ["iː": ["ɪ", "i"], "i": ["ɪ"]],
        "can": ["æ": ["ə", "ɛ"], "a": ["ə"]],
        "could": ["ʊ": ["ə"]],
        "would": ["ʊ": ["ə"]],
        "should": ["ʊ": ["ə"]],
        "will": ["ɪ": ["ə"]],
        "have": ["æ": ["ə", "ɛ"], "a": ["ə"]],
        "has": ["æ": ["ə"], "a": ["ə"]],
        "had": ["æ": ["ə"], "a": ["ə"]],
        "do": ["uː": ["ə", "ʊ", "u"], "u": ["ə", "ʊ"]],
        "does": ["ʌ": ["ə"], "ɐ": ["ə"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // PRONOUNS - Enhanced with rhotic variants
        // ══════════════════════════════════════════════════════════════════════
        "you": ["uː": ["ə", "ʊ", "u"], "u": ["ə", "ʊ"]],
        
        // "your" - KEY FIX: Can be /jɔː/, /jɔːɹ/, /jʊə/, /jʊɹ/, /jɜː/, /jɜːɹ/, /jɑːɹ/
        "your": [
            "ɔː": ["ə", "ɜː", "ɚ", "ɔːɹ", "ɔɹ", "ɜːɹ", "ʊɹ", "ʊə", "oʊ", "oʊɹ", "ɑːɹ", "ɑː"],
            "ɔːɹ": ["ə", "ɚ", "ɜː", "ɜːɹ", "ɔː", "ʊɹ", "ʊə", "ɝ", "oʊ", "oʊɹ", "ɑːɹ", "ɑː"],
            "ʊɹ": ["ɔː", "ɔːɹ", "ɜː", "ɜːɹ", "ə", "ʊə", "oʊ", "ɑːɹ"],
            "ʊə": ["ʊɹ", "ɔː", "ɔːɹ", "ɜː", "ə", "oʊ", "ɑːɹ"],
            "ɔ": ["ə", "ɜː", "ɔː", "ɔːɹ", "oʊ", "ɑː"],
            "ɜː": ["ə", "ɔː", "ɔːɹ", "ɜːɹ", "ɝ", "oʊ", "ɑːɹ"],
            "ɜːɹ": ["ɜː", "ɔː", "ɔːɹ", "ə", "ɝ", "oʊ", "ɑːɹ"],
        ],
        
        // "our" - similar to "your"
        "our": [
            "aʊ": ["ɑː", "ɑːɹ", "aʊɹ", "aʊə"],
            "aʊə": ["aʊ", "aʊɹ", "ɑː", "ɑːɹ"],
            "aʊɹ": ["aʊ", "aʊə", "ɑː", "ɑːɹ"],
            "ɑː": ["aʊ", "aʊɹ", "ɑːɹ"],
            "ɑːɹ": ["aʊ", "aʊɹ", "ɑː"],
        ],
        
        "he": ["iː": ["ɪ", "i"]],
        "she": ["iː": ["ɪ", "i"]],
        "we": ["iː": ["ɪ", "i"]],
        "me": ["iː": ["ɪ", "i"]],
        "be": ["iː": ["ɪ", "i"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // CONTRACTIONS - Handle common contractions with rhotic variants
        // ══════════════════════════════════════════════════════════════════════
        "we're": [
            "iə": ["ɪɹ", "ɪ", "iɹ", "ɪə", "ɜː"],
            "ɪɹ": ["iə", "ɪ", "ɪə", "iɹ", "ɜː"],
            "ɪ": ["ɪɹ", "iə", "ɪə"],
            "iɹ": ["iə", "ɪɹ", "ɪə"],
        ],
        "you're": [
            "ɔː": ["ɔːɹ", "ʊə", "ʊɹ", "ɜː", "ɜːɹ", "ɑːɹ"],
            "ɔːɹ": ["ɔː", "ʊə", "ʊɹ", "ɜː", "ɜːɹ", "ɑːɹ"],
            "ʊə": ["ʊɹ", "ɔː", "ɔːɹ", "ɑːɹ"],
            "ʊɹ": ["ʊə", "ɔː", "ɔːɹ", "ɑːɹ"],
        ],
        "they're": [
            "ɛ": ["ɛə", "ɛɹ", "eɪ"],
            "ɛə": ["ɛɹ", "eɹ", "ɛ"],
            "ɛɹ": ["ɛə", "eə", "ɛ"],
        ],
        "there's": [
            "ɛ": ["ɛə", "ɛɹ"],
            "ɛə": ["ɛɹ", "eɹ"],
            "ɛɹ": ["ɛə", "eə"],
        ],
        "here's": [
            "ɪ": ["ɪə", "ɪɹ"],
            "ɪə": ["ɪɹ", "iɹ"],
            "ɪɹ": ["ɪə", "iə"],
        ],
        
        "her": [
            "ɜː": ["ə", "ɜːɹ", "ɝ", "ɚ"],
            "ɝ": ["ə", "ɚ", "ɜː", "ɜːɹ"],
            "ɜːɹ": ["ə", "ɜː", "ɝ"],
        ],
        
        "him": ["ɪ": ["ə"]],
        "his": ["ɪ": ["ə"]],
        "them": ["ɛ": ["ə"], "e": ["ə"]],
        "us": ["ʌ": ["ə"], "ɐ": ["ə"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // OTHER FUNCTION WORDS - Enhanced with rhotic variants
        // ══════════════════════════════════════════════════════════════════════
        "there": [
            "ɛ": ["ə", "ɛə", "ɛɹ"],
            "ɛə": ["ə", "ɛɹ", "eɹ"],
            "ɛɹ": ["ə", "ɛə", "eə"],
            "e": ["ə"],
        ],
        "their": [
            "ɛ": ["ə", "ɛə", "ɛɹ"],
            "ɛə": ["ə", "ɛɹ", "eɹ"],
            "ɛɹ": ["ə", "ɛə", "eə"],
        ],
        "where": [
            "ɛ": ["ɛə", "ɛɹ"],
            "ɛə": ["ɛɹ", "eɹ"],
            "ɛɹ": ["ɛə", "eə"],
        ],
        "here": [
            "ɪ": ["ɪə", "ɪɹ"],
            "ɪə": ["ɪɹ", "iɹ"],
            "ɪɹ": ["ɪə", "iə"],
        ],
        "some": ["ʌ": ["ə"], "ɐ": ["ə"]],
        "just": ["ʌ": ["ə"], "ɐ": ["ə"]],
        
        // Additional common words with rhotic variation
        "more": [
            "ɔː": ["ɔːɹ", "oːɹ", "ɔɹ", "ɑːɹ"],
            "ɔːɹ": ["ɔː", "oː", "ɑːɹ"],
        ],
        "before": [
            "ɔː": ["ɔːɹ", "oːɹ", "ɑːɹ"],
            "ɔːɹ": ["ɔː", "oː", "ɑːɹ"],
        ],
        "after": [
            "ɑː": ["ɑːɹ", "ɑɹ", "æ"],
            "æ": ["ɑː", "a"],
        ],
        
        // ══════════════════════════════════════════════════════════════════════
        // DETERMINERS & DEMONSTRATIVES
        // ══════════════════════════════════════════════════════════════════════
        "this": ["ɪ": ["ə"]],
        "these": ["iː": ["i", "ɪ"]],
        "those": ["əʊ": ["oʊ", "ə"], "oʊ": ["əʊ", "ə"]],
        "my": ["aɪ": ["ə", "a"]],
        "its": ["ɪ": ["ə"]],
        "any": ["ɛ": ["ə", "ɪ"], "e": ["ə", "ɪ"]],
        "all": [
            "ɔː": ["ɔ", "ɑː", "ɑ"],
            "ɔ": ["ɔː", "ɑ"],
        ],
        "each": ["iː": ["i", "ɪ"]],
        "every": ["ɛ": ["ə", "ɪ"]],
        
        "not": [
            "ɒ": ["ɑ", "ɑː", "ʌ"],
            "ɑ": ["ɒ", "ɑː"],
        ],
        
        // ══════════════════════════════════════════════════════════════════════
        // PREPOSITIONS
        // ══════════════════════════════════════════════════════════════════════
        "in": ["ɪ": ["ə", "ɨ"]],
        "on": [
            "ɒ": ["ɑ", "ɔ"],
            "ɑ": ["ɒ", "ɔ"],
        ],
        "by": ["aɪ": ["a", "ə"]],
        "into": ["ɪ": ["ə"], "uː": ["u", "ə"]],
        "about": ["ə": ["ɐ"], "aʊ": ["ə", "æʊ"]],
        "through": ["uː": ["u", "ʊ"]],
        "during": [
            "ʊə": ["ɔː", "ɔːɹ", "ʊɹ", "uː"],
            "ɔː": ["ʊə", "ɔːɹ"],
        ],
        "without": ["ɪ": ["ə"], "aʊ": ["ə"]],
        "within": ["ɪ": ["ə"]],
        "over": [
            "əʊ": ["oʊ"],
            "oʊ": ["əʊ"],
            "ə": ["ɚ", "ɐ"],
        ],
        "under": ["ʌ": ["ə"], "ə": ["ɚ", "ɐ"]],
        "between": ["ɪ": ["ə"], "iː": ["i", "ɪ"]],
        "against": ["ə": ["ɪ", "ɛ"], "ɛ": ["ə", "ɪ"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // CONJUNCTIONS
        // ══════════════════════════════════════════════════════════════════════
        "so": ["əʊ": ["oʊ", "ə"], "oʊ": ["əʊ", "ə"]],
        "if": ["ɪ": ["ə"]],
        "when": ["ɛ": ["ə", "ɪ"], "e": ["ə", "ɪ"]],
        "while": ["aɪ": ["a"]],
        "although": ["əʊ": ["oʊ"], "oʊ": ["əʊ"]],
        "unless": ["ə": ["ʌ", "ɪ"], "ɛ": ["ə", "ɪ"]],
        "since": ["ɪ": ["ə"]],
        "until": ["ə": ["ʌ"], "ɪ": ["ə"]],
        
        
        // ══════════════════════════════════════════════════════════════════════
        // PRONOUNS
        // ══════════════════════════════════════════════════════════════════════
        "it": ["ɪ": ["ə"]],
        "they": ["eɪ": ["e", "ə"]],
        "who": ["uː": ["u", "ʊ"]],
        "which": ["ɪ": ["ə"]],
        "whose": ["uː": ["u", "ʊ"]],
        "whom": ["uː": ["u", "ʊ"]],
        "myself": ["aɪ": ["ə"], "ɛ": ["ə"]],
        "yourself": ["ɔː": ["ɔːɹ", "ʊə", "ɚ"], "ɛ": ["ə"]],
        "itself": ["ɪ": ["ə"], "ɛ": ["ə"]],
        "themselves": ["ɛ": ["ə"]],
        "something": ["ʌ": ["ə"], "ɪ": ["ə"]],
        "anything": ["ɛ": ["ə", "ɪ"], "ɪ": ["ə"]],
        "nothing": ["ʌ": ["ə"], "ɪ": ["ə"]],
        "everything": ["ɛ": ["ə", "ɪ"], "ɪ": ["ə"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // AUXILIARIES & MODALS
        // ══════════════════════════════════════════════════════════════════════
        "must": ["ʌ": ["ə"], "ɐ": ["ə"]],
        "may": ["eɪ": ["e", "ə"]],
        "might": ["aɪ": ["a"]],
        "shall": ["æ": ["ə"], "a": ["ə"]],
        "being": ["iː": ["i", "ɪ"], "ɪ": ["ə"]],
        "did": ["ɪ": ["ə"]],
        "don't": ["əʊ": ["oʊ"], "oʊ": ["əʊ"]],
        "won't": ["əʊ": ["oʊ"], "oʊ": ["əʊ"]],
        "can't": [
            "ɑː": ["æ", "ɑ"],  // UK /kɑːnt/ vs US /kænt/
            "æ": ["ɑː", "ɑ"],
        ],
        "couldn't": ["ʊ": ["ə"]],
        "wouldn't": ["ʊ": ["ə"]],
        "shouldn't": ["ʊ": ["ə"]],
        "haven't": ["æ": ["ə"], "ə": ["ɪ"]],
        "hasn't": ["æ": ["ə"]],
        "hadn't": ["æ": ["ə"]],
        "isn't": ["ɪ": ["ə"]],
        "aren't": [
            "ɑː": ["ɑːɹ", "ɑ"],
            "ɑːɹ": ["ɑː"],
        ],
        "wasn't": ["ɒ": ["ʌ", "ə"], "ʌ": ["ɒ", "ə"]],
        "weren't": [
            "ɜː": ["ɜːɹ", "ɝ"],
            "ɝ": ["ɜː", "ɜːɹ"],
        ],
        "doesn't": ["ʌ": ["ə"]],
        "didn't": ["ɪ": ["ə"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // COMMON ADVERBS
        // ══════════════════════════════════════════════════════════════════════
        "very": ["ɛ": ["ə"]],
        "also": [
            "ɔː": ["ɔ", "ɑː"],
            "əʊ": ["oʊ", "ə"],
            "oʊ": ["əʊ"],
        ],
        "only": ["əʊ": ["oʊ"], "oʊ": ["əʊ"]],
        "even": ["iː": ["i", "ɪ"]],
        "still": ["ɪ": ["ə"]],
        "again": ["ə": ["ɪ"], "ɛ": ["eɪ", "ə"]],
        "always": ["ɔː": ["ɔ", "ɑː"], "eɪ": ["ə", "ɪ"]],
        "never": ["ɛ": ["ə"], "ə": ["ɚ"]],
        "now": ["aʊ": ["æʊ"]],
        "then": ["ɛ": ["ə"]],
        "well": ["ɛ": ["e"]],
        "already": ["ɔː": ["ɔ", "ɑː"], "ɛ": ["ə"]],
        "often": [
            "ɒ": ["ɔ", "ɑ"],
            "ə": ["ɪ"],
        ],
        "perhaps": [
            "ə": ["ɜː", "ɚ"],
            "æ": ["ə"],
        ],
        "however": ["aʊ": ["ə"], "ə": ["ɚ"]],
        "therefore": [
            "ɛ": ["ɛə", "ɛɹ"],
            "ɔː": ["ɔːɹ"],
        ],
        
        // ══════════════════════════════════════════════════════════════════════
        // OTHER COMMON FUNCTION WORDS
        // ══════════════════════════════════════════════════════════════════════
        "other": ["ʌ": ["ə"], "ə": ["ɚ"]],
        "another": ["ə": ["ɐ"], "ʌ": ["ə"]],
        "such": ["ʌ": ["ə"]],
        "both": ["əʊ": ["oʊ"], "oʊ": ["əʊ"]],
        "either": ["aɪ": ["iː", "i"], "iː": ["aɪ", "i"], "ə": ["ɚ"]],
        "neither": ["aɪ": ["iː", "i"], "iː": ["aɪ", "i"], "ə": ["ɚ"]],
        "whether": ["ɛ": ["ə"], "ə": ["ɚ"]],
        "rather": ["ɑː": ["æ"], "æ": ["ɑː"], "ə": ["ɚ"]],
        "together": ["ə": ["ʊ", "ɪ"], "ɛ": ["ə"]],
        "able": ["eɪ": ["ə"]],
        "upon": ["ə": ["ʌ"], "ɒ": ["ɔ", "ɑ"]],
        "per": ["ɜː": ["ɚ", "ɝ"], "ɝ": ["ɜː"]],
        
        // ══════════════════════════════════════════════════════════════════════
        // COMMON GREETINGS (vowel variations are common in casual speech)
        // ══════════════════════════════════════════════════════════════════════
        "hello": [
            "ə": ["ɛ", "ɪ"],  // First vowel can be schwa, DRESS, or KIT
            "ɛ": ["ə", "ɪ"],
        ],
        "hi": ["aɪ": ["a"]],
        "hey": ["eɪ": ["e", "ɛ"]],
        "yeah": ["ɛ": ["e", "æ"]],
        "yes": ["ɛ": ["e"]],
        "no": ["əʊ": ["oʊ"], "oʊ": ["əʊ"]],
        "okay": [
            "əʊ": ["oʊ"],
            "oʊ": ["əʊ"],
            "eɪ": ["e"],
        ],
        "thanks": ["æ": ["a"]],
        "please": ["iː": ["i"], "z": ["s"]],
    ]
    
    /// Voicing pairs - consonants differing only in voicing
    /// Only accepted at word boundaries or for specific function words
    private let voicingPairs: [Set<String>] = [
        ["z", "s"],
        ["v", "f"],
        ["ð", "θ"],
        ["ʒ", "ʃ"],
        ["b", "p"],
        ["d", "t"],
        ["g", "k"],
        ["ɡ", "k"],
        ["dʒ", "tʃ"],
    ]
    
    /// Words where voicing variants are commonly acceptable
    private let voicingVariantWords: Set<String> = [
        // Auxiliaries and common verbs
        "is", "was", "has", "does", "his", "cause", "caused",
        // Function words
        "of", "with", "the", "as", "because", "these", "those",
        // Additional common words where final voicing varies
        "please", "use", "used", "always", "sometimes", "perhaps",
        "is", "has", "was", "does", "says", "goes",
    ]
    
    // MARK: - NEW: Strict Mode Configuration
    
    /// Words that get lenient scoring (function words)
    /// All other words use STRICT mode - only dialect variants from eSpeak are accepted
    private var lenientScoringWords: Set<String> {
        return Set(functionWordReductions.keys)
    }
    
    /// Check if a word should use strict scoring
    private func shouldUseStrictScoring(for word: String) -> Bool {
        return !lenientScoringWords.contains(word.lowercased())
    }
    
    // MARK: - Helper Methods
    
    private func stripModifiers(_ phoneme: String) -> String {
        return phoneme.replacingOccurrences(of: "[ːˌˈʲ]", with: "", options: .regularExpression)
    }
    
    private func areVoicingPair(phoneme1: String, phoneme2: String) -> Bool {
        let clean1 = stripModifiers(phoneme1)
        let clean2 = stripModifiers(phoneme2)
        
        for pair in voicingPairs {
            if pair.contains(clean1) && pair.contains(clean2) {
                return true
            }
        }
        return false
    }
    
    private func isWordSpecificVariant(word: String, target: String, actual: String) -> Bool {
        let wordLower = word.lowercased()
        
        guard let wordVariants = functionWordReductions[wordLower] else {
            return false
        }
        
        if let acceptableVariants = wordVariants[target], acceptableVariants.contains(actual) {
            return true
        }
        
        let cleanTarget = stripModifiers(target)
        let cleanActual = stripModifiers(actual)
        
        if let acceptableVariants = wordVariants[cleanTarget], acceptableVariants.contains(cleanActual) {
            return true
        }
        
        return false
    }
    
    /// Main similarity check - does not consider word context
    private func checkPhonemeSimilarity(target: String, actual: String) -> Bool {
        return checkPhonemeSimilarityWithContext(target: target, actual: actual, word: nil, strictMode: false)
    }
    
    /// NEW: Similarity check with strict mode option
    /// In strict mode, only exact matches or explicit dialect variants are accepted
    private func checkPhonemeSimilarityWithContext(
        target: String,
        actual: String,
        word: String?,
        strictMode: Bool = false,
        isWordFinal: Bool = false
    ) -> Bool {
        let normalizedTarget = target.precomposedStringWithCanonicalMapping
        let normalizedActual = actual.precomposedStringWithCanonicalMapping
        
        // 1. Exact match - always accept
        if normalizedTarget == normalizedActual {
            return true
        }
        
        // 2. Strip modifiers and check exact match
        let cleanTarget = stripModifiers(target)
        let cleanActual = stripModifiers(actual)
        if cleanTarget == cleanActual { return true }
        
        // 3. Word-specific variants (function word reductions) - always accept
        if let word = word, isWordSpecificVariant(word: word, target: target, actual: actual) {
            return true
        }
        
        // ══════════════════════════════════════════════════════════════════════
        // STRICT MODE GATE: After this point, if strict mode is enabled,
        // we only accept rhotic variants (dialect differences), NOT general similarity
        // ══════════════════════════════════════════════════════════════════════
        
        // 4. Rhotic vowel handling - accept in both modes (these are true dialect differences)
        if isRhoticVowelVariant(target: normalizedTarget, actual: normalizedActual) {
            return true
        }
        
        // 5. Dynamic rhotic handling (vowel + ɹ)
        let rhoticSuffixes = ["ɹ", "r", "ɚ"]
        for suffix in rhoticSuffixes {
            if normalizedActual == normalizedTarget + suffix {
                return true
            }
            if normalizedTarget == normalizedActual + suffix {
                return true
            }
        }
        
        // 5b. Check if actual ends with ɹ and base matches target
        if normalizedActual.hasSuffix("ɹ") || normalizedActual.hasSuffix("r") {
            let actualBase = String(normalizedActual.dropLast())
            if actualBase == normalizedTarget || actualBase == cleanTarget {
                return true
            }
            // Check if base is a rhotic variant of target
            if isRhoticVowelVariant(target: normalizedTarget, actual: actualBase) {
                return true
            }
        }
        
        // 5c. Check if target ends with ɹ and base matches actual
        if normalizedTarget.hasSuffix("ɹ") || normalizedTarget.hasSuffix("r") {
            let targetBase = String(normalizedTarget.dropLast())
            if targetBase == normalizedActual || targetBase == cleanActual {
                return true
            }
            if isRhoticVowelVariant(target: targetBase, actual: normalizedActual) {
                return true
            }
        }
        
        // ══════════════════════════════════════════════════════════════════════
        // 6. CORE DIALECT EQUIVALENCES - Accept in BOTH strict and lenient modes
        // These are fundamental UK/US vowel category differences (e.g., LOT vowel)
        // ══════════════════════════════════════════════════════════════════════
        if let equivalents = coreDialectEquivalences[normalizedTarget], equivalents.contains(normalizedActual) {
            return true
        }
        if let equivalents = coreDialectEquivalences[normalizedActual], equivalents.contains(normalizedTarget) {
            return true
        }
        if let equivalents = coreDialectEquivalences[cleanTarget], equivalents.contains(cleanActual) {
            return true
        }
        if let equivalents = coreDialectEquivalences[cleanActual], equivalents.contains(cleanTarget) {
            return true
        }
        
        // ══════════════════════════════════════════════════════════════════════
        // 7. UNSTRESSED VOWEL REDUCTIONS - Accept in BOTH modes
        // Natural speech reduces unstressed vowels; this shouldn't be penalized
        // ══════════════════════════════════════════════════════════════════════
        if let reductions = unstressedVowelReductions[normalizedTarget], reductions.contains(normalizedActual) {
            return true
        }
        if let reductions = unstressedVowelReductions[cleanTarget], reductions.contains(cleanActual) {
            return true
        }
        
        // ══════════════════════════════════════════════════════════════════════
        // 8. WORD-FINAL VOICING NEUTRALIZATION - Accept in BOTH modes
        // z→s, v→f at end of words is extremely common (e.g., "please" → [pliːs])
        // ══════════════════════════════════════════════════════════════════════
        if isWordFinal && isWordFinalVoicingVariant(target: normalizedTarget, actual: normalizedActual) {
            return true
        }
        if isWordFinal && isWordFinalVoicingVariant(target: cleanTarget, actual: cleanActual) {
            return true
        }
        
        // ══════════════════════════════════════════════════════════════════════
        // STRICT MODE STOPS HERE
        // The following checks are ONLY applied in lenient mode
        // ══════════════════════════════════════════════════════════════════════
        
        if strictMode {
            // In strict mode, we've already checked all acceptable variants
            // If we get here, it's a mispronunciation
            return false
        }
        
        // LENIENT MODE ONLY: General dialect equivalents
        if let equivalents = dialectPhonemeEquivalents[target], equivalents.contains(actual) {
            return true
        }
        if let equivalents = dialectPhonemeEquivalents[actual], equivalents.contains(target) {
            return true
        }
        
        if let equivalents = dialectPhonemeEquivalents[cleanTarget], equivalents.contains(cleanActual) {
            return true
        }
        if let equivalents = dialectPhonemeEquivalents[cleanActual], equivalents.contains(cleanTarget) {
            return true
        }
        
        // LENIENT MODE ONLY: Check base variants in dialect equivalents
        if normalizedActual.hasSuffix("ɹ") || normalizedActual.hasSuffix("r") {
            let actualBase = String(normalizedActual.dropLast())
            if let equivalents = dialectPhonemeEquivalents[actualBase], equivalents.contains(normalizedTarget) {
                return true
            }
            if let equivalents = dialectPhonemeEquivalents[normalizedTarget], equivalents.contains(actualBase) {
                return true
            }
        }
        
        if normalizedTarget.hasSuffix("ɹ") || normalizedTarget.hasSuffix("r") {
            let targetBase = String(normalizedTarget.dropLast())
            if let equivalents = dialectPhonemeEquivalents[targetBase], equivalents.contains(normalizedActual) {
                return true
            }
            if let equivalents = dialectPhonemeEquivalents[normalizedActual], equivalents.contains(targetBase) {
                return true
            }
        }
        
        return false
    }
    
    /// Check if voicing variant is acceptable for this word
    private func isAcceptableVoicingVariant(word: String, position: Int, totalPhonemes: Int) -> Bool {
        let wordLower = word.lowercased()
        
        // Accept voicing variants for known words
        if voicingVariantWords.contains(wordLower) {
            return true
        }
        
        // Accept voicing variants at word-final position (common in natural speech)
        if position == totalPhonemes - 1 {
            return true
        }
        
        return false
    }
    
    private func isImportantPhoneme(_ phoneme: String) -> Bool {
        let unimportantPhonemes: Set<String> = ["ə", "ɚ", "ᵻ", "ʔ"]
        return !unimportantPhonemes.contains(phoneme)
    }
    
    /// Checks if target and actual represent a rhotic/non-rhotic vowel pair
    /// These are extremely common dialect differences and should be accepted
    /// even with low model confidence
    private func isRhoticVowelVariant(target: String, actual: String) -> Bool {
        // Define rhotic vowel pairs (non-rhotic ↔ rhotic)
        // ENHANCED v10.5: Added oːɹ for CURE, ɛ for SQUARE
        let rhoticPairs: [(nonRhotic: String, rhotic: Set<String>)] = [
            ("ɔː", ["ɔːɹ", "ɔɹ", "oːɹ", "oʊɹ", "ɑːɹ"]),  // NORTH/FORCE: "your", "for", "or"
            ("ɑː", ["ɑːɹ", "ɑɹ", "ɔːɹ"]),                 // START: "car", "far"
            ("ɜː", ["ɜːɹ", "ɝ", "ɚ"]),                    // NURSE: "her", "were"
            ("ɪə", ["ɪɹ", "iɹ"]),                          // NEAR: "here", "we're"
            ("ɛə", ["ɛɹ", "eɹ", "ɛ", "ɛːɹ"]),             // SQUARE: "there", "where", "aware" - US can be just ɛ+ɹ
            ("eə", ["eɹ", "ɛɹ", "ɛ", "eːɹ"]),             // SQUARE alternate notation
            ("ʊə", ["ʊɹ", "uɹ", "ɚ", "ɝ", "ɔːɹ", "uː", "uːɹ", "oːɹ", "oɹ"]),  // CURE: added oːɹ
            ("ə", ["ɚ", "əɹ"]),                            // Schwa-R: unstressed syllables
            ("oː", ["oːɹ", "oʊɹ"]),                        // Alternative FORCE notation
        ]
        
        for pair in rhoticPairs {
            // Non-rhotic target, rhotic actual
            if target == pair.nonRhotic && pair.rhotic.contains(actual) {
                return true
            }
            // Rhotic target, non-rhotic actual
            if pair.rhotic.contains(target) && actual == pair.nonRhotic {
                return true
            }
            // Both rhotic but different notation (or both in the same equivalence class)
            if pair.rhotic.contains(target) && pair.rhotic.contains(actual) {
                return true
            }
        }
        
        // Also check if one is the other + ɹ/r suffix
        if actual == target + "ɹ" || actual == target + "r" {
            return true
        }
        if target == actual + "ɹ" || target == actual + "r" {
            return true
        }
        
        return false
    }
    
    /// NEW: Check if this is a core dialect equivalence (LOT vowel, etc.)
    /// These should be accepted in strict mode and get good credit
    private func isCoreDialectEquivalent(target: String, actual: String) -> Bool {
        let cleanTarget = stripModifiers(target)
        let cleanActual = stripModifiers(actual)
        
        if let equivalents = coreDialectEquivalences[target], equivalents.contains(actual) {
            return true
        }
        if let equivalents = coreDialectEquivalences[actual], equivalents.contains(target) {
            return true
        }
        if let equivalents = coreDialectEquivalences[cleanTarget], equivalents.contains(cleanActual) {
            return true
        }
        if let equivalents = coreDialectEquivalences[cleanActual], equivalents.contains(cleanTarget) {
            return true
        }
        return false
    }
    
    /// NEW: Check if this is an unstressed vowel reduction
    /// Very common in natural speech and should be accepted
    private func isUnstressedVowelReduction(target: String, actual: String) -> Bool {
        let cleanTarget = stripModifiers(target)
        let cleanActual = stripModifiers(actual)
        
        if let reductions = unstressedVowelReductions[target], reductions.contains(actual) {
            return true
        }
        if let reductions = unstressedVowelReductions[cleanTarget], reductions.contains(cleanActual) {
            return true
        }
        return false
    }
    
    /// NEW: Check if this is word-final voicing neutralization
    /// z→s, v→f, etc. at end of words is very common
    private func isWordFinalVoicingVariant(target: String, actual: String) -> Bool {
        if let variants = wordFinalVoicingPairs[target], variants.contains(actual) {
            return true
        }
        if let variants = wordFinalVoicingPairs[actual], variants.contains(target) {
            return true
        }
        return false
    }
    
    /// Checks if a deleted phoneme is due to coarticulation with the next sound
    private func checkCoarticulationDeletion(
        deletedPhoneme: String,
        nextTargetIndex: Int,
        targetPhonemes: [String],
        actualPhonemes: [String],
        currentActualIndex: Int
    ) -> Bool {
        let coarticulationPatterns: [(deleted: String, nextTarget: String, coalescedResult: String)] = [
            ("d", "j", "dʒ"),
            ("t", "j", "tʃ"),
            ("s", "j", "ʃ"),
            ("z", "j", "ʒ"),
        ]
        
        guard nextTargetIndex < targetPhonemes.count else { return false }
        let nextTargetPhoneme = targetPhonemes[nextTargetIndex]
        
        let searchRange = max(0, currentActualIndex - 1)...min(actualPhonemes.count - 1, currentActualIndex + 2)
        
        for pattern in coarticulationPatterns {
            if deletedPhoneme == pattern.deleted && nextTargetPhoneme == pattern.nextTarget {
                for idx in searchRange {
                    if idx < actualPhonemes.count && actualPhonemes[idx] == pattern.coalescedResult {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Checks if a deleted phoneme is due to cross-word consonant gemination
    private func checkGeminateAssimilation(
        deletedPhoneme: String,
        nextTargetIndex: Int,
        targetPhonemes: [String]
    ) -> Bool {
        guard nextTargetIndex < targetPhonemes.count else { return false }
        let nextTargetPhoneme = targetPhonemes[nextTargetIndex]
        
        if deletedPhoneme == nextTargetPhoneme {
            if !isVowelPhoneme(deletedPhoneme) {
                return true
            }
        }
        
        let assimilationPairs: Set<Set<String>> = [
            ["d", "t"],
            ["b", "p"],
            ["g", "k"],
            ["ɡ", "k"],
            ["v", "f"],
            ["z", "s"],
            ["ð", "θ"],
        ]
        
        for pair in assimilationPairs {
            if pair.contains(deletedPhoneme) && pair.contains(nextTargetPhoneme) {
                return true
            }
        }
        
        return false
    }
    
    /// NEW: Check if a phoneme following a vowel is a bare rhotic that should be merged
    /// This handles cases like model outputting "ɔː" + "ɹ" separately instead of "ɔːɹ"
    private func isSplitRhoticPattern(
        vowelPhoneme: String,
        nextPhoneme: String,
        targetPhoneme: String
    ) -> Bool {
        // Check if next phoneme is a bare rhotic
        guard nextPhoneme == "ɹ" || nextPhoneme == "r" else { return false }
        
        // Check if vowel + ɹ would match the target
        let combinedRhotic = vowelPhoneme + "ɹ"
        
        // Direct match
        if combinedRhotic == targetPhoneme {
            return true
        }
        
        // Check if combined form is a rhotic variant of target
        if isRhoticVowelVariant(target: targetPhoneme, actual: combinedRhotic) {
            return true
        }
        
        // Check if the vowel alone is a variant of the target (rhotic dropped)
        if isRhoticVowelVariant(target: targetPhoneme, actual: vowelPhoneme) {
            return true
        }
        
        return false
    }
    
    /// Filters consecutive duplicate phonemes that are likely model artifacts
    /// AND merges split rhotic vowels (e.g., "oʊ r" → "oʊɹ")
    ///
    /// IMPROVED v10.7: More aggressive filtering of obvious duplicates
    private func filterConsecutiveDuplicates(_ phonemes: [PhonemePrediction]) -> [PhonemePrediction] {
        guard !phonemes.isEmpty else { return [] }
        
        var filtered: [PhonemePrediction] = []
        var lastPhoneme: String? = nil
        var i = 0
        
        while i < phonemes.count {
            let prediction = phonemes[i]
            let currentPhoneme = prediction.topPrediction.phoneme
            
            // ══════════════════════════════════════════════════════════════
            // 1. Check for split rhotic vowels: vowel followed by standalone "r" or "ɹ"
            // ══════════════════════════════════════════════════════════════
            if i + 1 < phonemes.count {
                let nextPhoneme = phonemes[i + 1].topPrediction.phoneme
                
                if isVowelPhoneme(currentPhoneme) && (nextPhoneme == "r" || nextPhoneme == "ɹ") {
                    filtered.append(prediction)
                    lastPhoneme = currentPhoneme
                    i += 2
                    continue
                }
            }
            
            let isVowel = isVowelPhoneme(currentPhoneme)
            
            // ══════════════════════════════════════════════════════════════
            // 2. Duplicate detection with improved heuristics
            // ══════════════════════════════════════════════════════════════
            if currentPhoneme == lastPhoneme {
                // Check surrounding context
                let nextIsVowel = (i + 1 < phonemes.count) &&
                    isVowelPhoneme(phonemes[i + 1].topPrediction.phoneme)
                
                let twoBackWasVowel = filtered.count >= 2 &&
                    isVowelPhoneme(filtered[filtered.count - 2].topPrediction.phoneme)
                
                let prevWasVowel = filtered.count >= 1 &&
                    isVowelPhoneme(filtered[filtered.count - 1].topPrediction.phoneme)
                
                // CASE 1: Duplicate vowel (ALWAYS REMOVE - very rare in English)
                if isVowel {
                    i += 1
                    continue
                }
                
                // CASE 2: Word boundary gemination pattern V C C V (KEEP)
                // e.g., "us successful" → ʌ s s ə
                if !isVowel && twoBackWasVowel && nextIsVowel {
                    filtered.append(prediction)
                    lastPhoneme = currentPhoneme
                    i += 1
                    continue
                }
                
                // CASE 3: Pattern V C C (no vowel after) - likely duplicate (REMOVE)
                // e.g., "hello" → h ɛ l l (no vowel after second l)
                if !isVowel && prevWasVowel && !nextIsVowel {
                    i += 1
                    continue
                }
                
                // CASE 4: Duplicate at word START (filtered.count ≤ 2) (REMOVE)
                if filtered.count <= 2 {
                    i += 1
                    continue
                }
                
                // CASE 5: Consonant at END with no following vowel (REMOVE)
                // e.g., trailing "h" in "h ɛ l oʊ h"
                if !isVowel && i == phonemes.count - 1 {
                    i += 1
                    continue
                }
                
                // CASE 6: Default - still looks suspicious, skip it
                i += 1
                continue
            }
            
            // Not a duplicate, keep it
            filtered.append(prediction)
            lastPhoneme = currentPhoneme
            i += 1
        }
        
        return filtered
    }
    
    /// Check if a phoneme is a vowel (for duplicate filtering and vowel emphasis)
    private func isVowelPhoneme(_ phoneme: String) -> Bool {
        let vowelChars: Set<Character> = [
            "a", "e", "i", "o", "u",
            "ɪ", "ʊ", "ɛ", "ɔ", "æ", "ʌ", "ə", "ɑ", "ɒ",
            "ɜ", "ɝ", "ɚ", "ᵻ", "ɐ"
        ]
        
        guard let firstChar = phoneme.first else { return false }
        return vowelChars.contains(firstChar)
    }
    
    // MARK: - Scoring Methods
    
    func alignAndScore(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String
    ) -> PronunciationEvalResult {
        // Debug: Show before filtering
        print("\n🔍 DEBUG - Before filtering:")
        print("   Raw: \(decodedPhonemes.map { $0.topPrediction.phoneme }.joined(separator: " "))")
        
        // Apply filtering
        let filtered = filterConsecutiveDuplicates(decodedPhonemes)
        
        // Debug: Show after filtering
        print("🔍 DEBUG - After filtering:")
        print("   Filtered: \(filtered.map { $0.topPrediction.phoneme }.joined(separator: " "))")
        print("")
        
        return alignAndScoreMultiDialect(
            decodedPhonemes: filtered,
            targetSentence: targetSentence
        )
    }
    
    private func alignAndScoreMultiDialect(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String
    ) -> PronunciationEvalResult {
        
        // SAFETY CHECK: Handle empty or very short recordings
        if decodedPhonemes.isEmpty {
            print("⚠️ WARNING: No phonemes detected in recording (too short or silent)")
            var targetWords: [String] = []
            targetSentence.enumerateSubstrings(in: targetSentence.startIndex..., options: .byWords) { (substring, _, _, _) in
                if let word = substring {
                    targetWords.append(word)
                }
            }
            // Return zero scores for all words
            let wordScores = targetWords.map { word in
                WordScore(word: word, score: 0.0, alignedPhonemes: [
                    AlignedPhoneme(type: .delete, target: "(no audio)", actual: nil, score: 0.0, note: "Recording too short")
                ])
            }
            return PronunciationEvalResult(totalScore: 0.0, wordScores: wordScores)
        }
        
        let allDialectPhonemes = espeakManager.getPhonemesForAllDialects(for: targetSentence)
        
        var targetWords: [String] = []
        targetSentence.enumerateSubstrings(in: targetSentence.startIndex..., options: .byWords) { (substring, _, _, _) in
            if let word = substring {
                targetWords.append(word)
            }
        }
        
        // Debug output
        print("═══════════════════════════════════════════════════════════════")
        print("🎤 TARGET SENTENCE: \"\(targetSentence)\"")
        print("═══════════════════════════════════════════════════════════════")
        print("")
        print("📥 USER INPUT (Decoded Phonemes):")
        let userPhonemes = decodedPhonemes.map { $0.topPrediction.phoneme }
        print("   \(userPhonemes.joined(separator: " "))")
        print("")
        
        print("📚 IDEAL PHONEMES BY DIALECT:")
        for (dialect, phonemes) in allDialectPhonemes {
            let flatPhonemes = phonemes.flatMap { $0 }
            print("   [\(dialect.rawValue)]: \(flatPhonemes.joined(separator: " "))")
        }
        print("")
        
        // NEW: Show which words will use strict vs lenient scoring
        print("📋 SCORING MODE BY WORD:")
        for word in targetWords {
            let mode = shouldUseStrictScoring(for: word) ? "STRICT" : "LENIENT"
            print("   \(word): \(mode)")
        }
        print("")
        
        // Per-word dialect matching
        guard let genericPhonemes = allDialectPhonemes[.generic],
              let usPhonemes = allDialectPhonemes[.us],
              genericPhonemes.count == usPhonemes.count,
              genericPhonemes.count == targetWords.count else {
            return scoreAgainstBestDialect(
                decodedPhonemes: decodedPhonemes,
                targetSentence: targetSentence,
                allDialectPhonemes: allDialectPhonemes,
                targetWords: targetWords
            )
        }
        
        // Build merged ideal phonemes using best dialect per word
        // NOTE: We pre-select based on a quick match, but the actual scoring
        // will compare against BOTH dialects and use the better result
        var mergedIdealPhonemes: [[String]] = []
        var bothDialectPhonemes: [([String], [String])] = []  // NEW: Store both for later
        var phonemeIndex = 0
        
        for wordIndex in 0..<targetWords.count {
            let genericWordPhonemes = genericPhonemes[wordIndex]
            let usWordPhonemes = usPhonemes[wordIndex]
            
            // Store both dialects for this word
            bothDialectPhonemes.append((genericWordPhonemes, usWordPhonemes))
            
            let wordPhonemeCount = max(genericWordPhonemes.count, usWordPhonemes.count)
            
            // SAFETY CHECK: Ensure valid range bounds
            let safeStartIndex = min(phonemeIndex, decodedPhonemes.count)
            let endIndex = min(phonemeIndex + wordPhonemeCount + 1, decodedPhonemes.count)
            let safeEndIndex = max(safeStartIndex, endIndex)  // Ensure lowerBound <= upperBound
            
            let userWordPhonemes = safeStartIndex < safeEndIndex
                ? Array(decodedPhonemes[safeStartIndex..<safeEndIndex])
                : []
            
            let genericScore = scoreWordPhonemes(target: genericWordPhonemes, actual: userWordPhonemes, word: targetWords[wordIndex])
            let usScore = scoreWordPhonemes(target: usWordPhonemes, actual: userWordPhonemes, word: targetWords[wordIndex])
            
            // Pre-select best dialect for alignment (but we'll verify later)
            mergedIdealPhonemes.append(usScore > genericScore ? usWordPhonemes : genericWordPhonemes)
            phonemeIndex += genericWordPhonemes.count
        }
        
        // Score against BOTH dialects and take the better result for each word
        let resultUK = scoreAgainstDialect(
            decodedPhonemes: decodedPhonemes,
            targetSentence: targetSentence,
            idealPhonemes: genericPhonemes,
            targetWords: targetWords
        )
        
        let resultUS = scoreAgainstDialect(
            decodedPhonemes: decodedPhonemes,
            targetSentence: targetSentence,
            idealPhonemes: usPhonemes,
            targetWords: targetWords
        )
        
        // Merge results: for each word, take the higher scoring dialect
        var finalWordScores: [WordScore] = []
        for i in 0..<targetWords.count {
            let ukWordScore = i < resultUK.wordScores.count ? resultUK.wordScores[i] : nil
            let usWordScore = i < resultUS.wordScores.count ? resultUS.wordScores[i] : nil
            
            if let uk = ukWordScore, let us = usWordScore {
                // Take whichever dialect scored higher for this word
                if us.score > uk.score {
                    finalWordScores.append(us)
                } else if uk.score > us.score {
                    finalWordScores.append(uk)
                } else {
                    // Equal scores - prefer US (arbitrary choice, or could prefer merged)
                    finalWordScores.append(us)
                }
            } else if let uk = ukWordScore {
                finalWordScores.append(uk)
            } else if let us = usWordScore {
                finalWordScores.append(us)
            }
        }
        
        // Calculate final total score
        let finalTotalScore = finalWordScores.isEmpty ? 0.0
            : finalWordScores.map { $0.score }.reduce(0, +) / Double(finalWordScores.count)
        
        let result = PronunciationEvalResult(totalScore: finalTotalScore, wordScores: finalWordScores)
        
        printAlignmentDetails(result: result)
        return result
    }
    
    private func scoreWordPhonemes(target: [String], actual: [PhonemePrediction], word: String) -> Double {
        guard !target.isEmpty else { return 0 }
        
        var matches = 0
        let actualPhonemes = actual.map { $0.topPrediction.phoneme }
        let strictMode = shouldUseStrictScoring(for: word)
        
        for targetPhoneme in target {
            for actualPhoneme in actualPhonemes {
                if checkPhonemeSimilarityWithContext(target: targetPhoneme, actual: actualPhoneme, word: word, strictMode: strictMode) {
                    matches += 1
                    break
                }
            }
        }
        
        return Double(matches) / Double(target.count)
    }
    
    private func scoreAgainstBestDialect(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String,
        allDialectPhonemes: [EspeakManager.Dialect: [[String]]],
        targetWords: [String]
    ) -> PronunciationEvalResult {
        var bestResult: PronunciationEvalResult?
        var bestScore: Double = -1.0
        
        for (_, dialectPhonemes) in allDialectPhonemes {
            let result = scoreAgainstDialect(
                decodedPhonemes: decodedPhonemes,
                targetSentence: targetSentence,
                idealPhonemes: dialectPhonemes,
                targetWords: targetWords
            )
            
            if result.totalScore > bestScore {
                bestScore = result.totalScore
                bestResult = result
            }
        }
        
        if let result = bestResult {
            printAlignmentDetails(result: result)
            return result
        }
        
        return PronunciationEvalResult(totalScore: 0, wordScores: [])
    }
    
    private func scoreAgainstDialect(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String,
        idealPhonemes: [[String]],
        targetWords: [String]
    ) -> PronunciationEvalResult {
        
        // Preprocessing: Filter consecutive duplicate phonemes
        let filteredPhonemes = filterConsecutiveDuplicates(decodedPhonemes)
        
        let targetPhonemesFlat = idealPhonemes.flatMap { $0 }.map { $0.precomposedStringWithCanonicalMapping }
        let actualPhonemes = filteredPhonemes.map { $0.topPrediction.phoneme.precomposedStringWithCanonicalMapping }
        
        let opcodes = levenshteinOpcodes(
            from: targetPhonemesFlat,
            to: actualPhonemes,
            similarityChecker: checkPhonemeSimilarity
        )
        
        var alignedScores: [AlignedPhoneme] = []
        var totalScore: Double = 0
        var scoreCount: Int = 0
        var gopIndex: Int = 0
        
        var wordScores: [Double] = []
        var currentWordScoreTotal: Double = 0
        var currentWordPhonemeCount: Int = 0
        var currentWordInsertionCount: Int = 0
        var currentWordMispronunciationCount: Int = 0
        var currentWordVowelMispronunciationCount: Int = 0  // NEW: Track vowel mispronunciations separately
        var targetPhonemeIndex: Int = 0
        var phonemePositionInWord: Int = 0
        
        let wordLengths = idealPhonemes.map { $0.count }
        guard !wordLengths.isEmpty else {
            return PronunciationEvalResult(totalScore: 0, wordScores: [])
        }
        
        var currentWordBoundary = wordLengths[0]
        var currentWordIndex = 0
        
        func getCurrentWord() -> String {
            guard currentWordIndex < targetWords.count else { return "" }
            return targetWords[currentWordIndex]
        }
        
        func getCurrentWordLength() -> Int {
            guard currentWordIndex < wordLengths.count else { return 1 }
            return wordLengths[currentWordIndex]
        }
        
        /// NEW: Check if current word should use strict scoring
        func isCurrentWordStrict() -> Bool {
            return shouldUseStrictScoring(for: getCurrentWord())
        }
        
        func checkWordBoundary() {
            if targetPhonemeIndex == currentWordBoundary {
                // Calculate base average score
                var avgScore = currentWordPhonemeCount > 0
                    ? currentWordScoreTotal / Double(currentWordPhonemeCount)
                    : 0.0
                
                // Penalize excessive insertions
                let excessInsertions = max(0, currentWordInsertionCount - insertionPenaltyThreshold)
                let insertionPenalty = Double(excessInsertions) * insertionPenaltyFactor
                avgScore = max(0, avgScore - insertionPenalty)
                
                // NEW: Apply different penalties based on strict vs lenient mode
                let isStrict = shouldUseStrictScoring(for: getCurrentWord())
                
                if isStrict {
                    // STRICT MODE: Higher penalties
                    // Vowel mispronunciations are especially costly
                    let vowelPenalty = Double(currentWordVowelMispronunciationCount) * vowelMispronunciationPenaltyFactor
                    let consonantPenalty = Double(currentWordMispronunciationCount - currentWordVowelMispronunciationCount) * strictModeMispronunciationPenalty
                    avgScore = max(0, avgScore - vowelPenalty - consonantPenalty)
                } else {
                    // LENIENT MODE: Standard penalties
                    let mispronunciationPenalty = Double(currentWordMispronunciationCount) * mispronunciationPenaltyFactor
                    avgScore = max(0, avgScore - mispronunciationPenalty)
                }
                
                wordScores.append(avgScore)
                
                currentWordScoreTotal = 0
                currentWordPhonemeCount = 0
                currentWordInsertionCount = 0
                currentWordMispronunciationCount = 0
                currentWordVowelMispronunciationCount = 0
                phonemePositionInWord = 0
                currentWordIndex += 1
                
                if currentWordIndex < wordLengths.count {
                    currentWordBoundary += wordLengths[currentWordIndex]
                }
            }
        }
        
        for opcode in opcodes {
            switch opcode.type {
            case .equal:
                for i in opcode.targetRange {
                    let targetPhoneme = targetPhonemesFlat[i]
                    let actualItem = filteredPhonemes[gopIndex]
                    
                    alignedScores.append(AlignedPhoneme(
                        type: .match,
                        target: targetPhoneme,
                        actual: actualItem.topPrediction.phoneme,
                        score: actualItem.score,
                        note: nil
                    ))
                    
                    totalScore += actualItem.score
                    scoreCount += 1
                    gopIndex += 1
                    
                    currentWordScoreTotal += actualItem.score
                    currentWordPhonemeCount += 1
                    phonemePositionInWord += 1
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .replace:
                for i in opcode.targetRange {
                    let targetPhoneme = targetPhonemesFlat[i]
                    var phonemeScoreToAdd: Double = 0.0
                    let currentWord = getCurrentWord()
                    let wordLength = getCurrentWordLength()
                    let strictMode = isCurrentWordStrict()
                    
                    // Check if this is the last phoneme of the current word
                    let isLastPhonemeOfWord = (phonemePositionInWord == wordLength - 1)
                    
                    if gopIndex < filteredPhonemes.count {
                        let actualItem = filteredPhonemes[gopIndex]
                        let actualPhoneme = actualItem.topPrediction.phoneme
                        let confidence = actualItem.score
                        
                        // NEW: Check for split rhotic pattern
                        // If the actual phoneme is a vowel and the next is a bare ɹ,
                        // treat them together as a rhotic vowel
                        var isSplitRhotic = false
                        if gopIndex + 1 < filteredPhonemes.count {
                            let nextActual = filteredPhonemes[gopIndex + 1].topPrediction.phoneme
                            if isSplitRhoticPattern(vowelPhoneme: actualPhoneme, nextPhoneme: nextActual, targetPhoneme: targetPhoneme) {
                                isSplitRhotic = true
                            }
                        }
                        
                        // Check similarity with word context, strict mode, and word-final position
                        let isSimilar = isSplitRhotic || checkPhonemeSimilarityWithContext(
                            target: targetPhoneme,
                            actual: actualPhoneme,
                            word: currentWord,
                            strictMode: strictMode,
                            isWordFinal: isLastPhonemeOfWord
                        )
                        
                        let isVoicing = areVoicingPair(phoneme1: targetPhoneme, phoneme2: actualPhoneme)
                        let isWordFinalVoicing = isLastPhonemeOfWord && isWordFinalVoicingVariant(target: targetPhoneme, actual: actualPhoneme)
                        let isFunctionWordReduction = isWordSpecificVariant(
                            word: currentWord,
                            target: targetPhoneme,
                            actual: actualPhoneme
                        )
                        
                        if isSimilar {
                            let isRhoticVariant = isRhoticVowelVariant(target: targetPhoneme, actual: actualPhoneme) || isSplitRhotic
                            let isCoreDialect = isCoreDialectEquivalent(target: targetPhoneme, actual: actualPhoneme)
                            let isUnstressedReduction = isUnstressedVowelReduction(target: targetPhoneme, actual: actualPhoneme)
                            
                            let effectiveMinConfidence: Double
                            if isRhoticVariant || isFunctionWordReduction || isCoreDialect || isUnstressedReduction || isWordFinalVoicing {
                                effectiveMinConfidence = 0.10
                            } else {
                                effectiveMinConfidence = minimumVariantConfidence
                            }
                            
                            if confidence >= effectiveMinConfidence {
                                let maxCredit: Double
                                let minCredit: Double
                                let note: String
                                
                                if isSplitRhotic {
                                    maxCredit = 0.85
                                    minCredit = 0.55
                                    note = "Split rhotic (merged)"
                                } else if isFunctionWordReduction {
                                    maxCredit = 0.85
                                    minCredit = 0.50
                                    note = "Function word reduction"
                                } else if isRhoticVariant {
                                    maxCredit = 0.85
                                    minCredit = 0.55
                                    note = "Rhotic variant"
                                } else if isCoreDialect {
                                    // NEW: Core dialect differences (LOT vowel etc.) get high credit
                                    maxCredit = 0.90
                                    minCredit = 0.60
                                    note = "Dialect variant (UK/US)"
                                } else if isUnstressedReduction {
                                    // NEW: Unstressed vowel reductions are natural
                                    maxCredit = 0.80
                                    minCredit = 0.50
                                    note = "Unstressed reduction"
                                } else if isWordFinalVoicing {
                                    // NEW: Word-final voicing neutralization (z→s in "please")
                                    maxCredit = 0.85
                                    minCredit = 0.55
                                    note = "Word-final devoicing"
                                } else if isVoicing && isAcceptableVoicingVariant(word: currentWord, position: phonemePositionInWord, totalPhonemes: wordLength) {
                                    maxCredit = 0.80
                                    minCredit = 0.45
                                    note = "Voicing variant"
                                } else if isVoicing {
                                    maxCredit = 0.60
                                    minCredit = 0.35
                                    note = "Voicing variant (mid-word)"
                                } else {
                                    // NEW: In strict mode, give less credit for "similar" variants
                                    if strictMode {
                                        maxCredit = 0.50
                                        minCredit = 0.30
                                        note = "Similar variant (strict)"
                                    } else {
                                        maxCredit = 0.70
                                        minCredit = 0.40
                                        note = "Similar variant"
                                    }
                                }
                                
                                phonemeScoreToAdd = max(minCredit, min(confidence, maxCredit))
                                
                                alignedScores.append(AlignedPhoneme(
                                    type: .match,
                                    target: targetPhoneme,
                                    actual: actualPhoneme,
                                    score: phonemeScoreToAdd,
                                    note: note
                                ))
                                totalScore += phonemeScoreToAdd
                            } else {
                                // Low confidence - don't accept as variant
                                alignedScores.append(AlignedPhoneme(
                                    type: .replace,
                                    target: targetPhoneme,
                                    actual: actualPhoneme,
                                    score: 0.0,
                                    note: "Low confidence variant (said '\(actualPhoneme)')"
                                ))
                                currentWordMispronunciationCount += 1
                                if isVowelPhoneme(targetPhoneme) {
                                    currentWordVowelMispronunciationCount += 1
                                }
                            }
                        } else {
                            // Real mispronunciation
                            let isVowelMispronunciation = isVowelPhoneme(targetPhoneme)
                            let notePrefix = strictMode ? "[STRICT] " : ""
                            let vowelNote = isVowelMispronunciation ? " (VOWEL)" : ""
                            
                            alignedScores.append(AlignedPhoneme(
                                type: .replace,
                                target: targetPhoneme,
                                actual: actualPhoneme,
                                score: 0.0,
                                note: "\(notePrefix)Mispronounced\(vowelNote) (said '\(actualPhoneme)')"
                            ))
                            currentWordMispronunciationCount += 1
                            if isVowelMispronunciation {
                                currentWordVowelMispronunciationCount += 1
                            }
                        }
                        
                        scoreCount += 1
                        gopIndex += 1
                        currentWordScoreTotal += phonemeScoreToAdd
                        currentWordPhonemeCount += 1
                        phonemePositionInWord += 1
                        
                    } else {
                        alignedScores.append(AlignedPhoneme(
                            type: .delete,
                            target: targetPhoneme,
                            actual: nil,
                            score: 0.0,
                            note: nil
                        ))
                        if isImportantPhoneme(targetPhoneme) {
                            scoreCount += 1
                            currentWordPhonemeCount += 1
                        }
                    }
                    
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .delete:
                for i in opcode.targetRange {
                    let targetPhoneme = targetPhonemesFlat[i]
                    
                    let isCoarticulationDeletion = checkCoarticulationDeletion(
                        deletedPhoneme: targetPhoneme,
                        nextTargetIndex: i + 1,
                        targetPhonemes: targetPhonemesFlat,
                        actualPhonemes: filteredPhonemes.map { $0.topPrediction.phoneme },
                        currentActualIndex: gopIndex
                    )
                    
                    let isGeminateAssimilation = checkGeminateAssimilation(
                        deletedPhoneme: targetPhoneme,
                        nextTargetIndex: i + 1,
                        targetPhonemes: targetPhonemesFlat
                    )
                    
                    if isCoarticulationDeletion {
                        alignedScores.append(AlignedPhoneme(
                            type: .match,
                            target: targetPhoneme,
                            actual: "(coalesced)",
                            score: 0.60,
                            note: "Coarticulation"
                        ))
                        totalScore += 0.60
                        scoreCount += 1
                        currentWordScoreTotal += 0.60
                        currentWordPhonemeCount += 1
                    } else if isGeminateAssimilation {
                        alignedScores.append(AlignedPhoneme(
                            type: .match,
                            target: targetPhoneme,
                            actual: "(geminated)",
                            score: 0.70,
                            note: "Cross-word gemination"
                        ))
                        totalScore += 0.70
                        scoreCount += 1
                        currentWordScoreTotal += 0.70
                        currentWordPhonemeCount += 1
                    } else {
                        alignedScores.append(AlignedPhoneme(
                            type: .delete,
                            target: targetPhoneme,
                            actual: nil,
                            score: 0.0,
                            note: isImportantPhoneme(targetPhoneme) ? "Missing sound" : "Minor omission"
                        ))
                        
                        if isImportantPhoneme(targetPhoneme) {
                            scoreCount += 1
                            currentWordPhonemeCount += 1
                        }
                    }
                    
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .insert:
                for _ in opcode.actualRange {
                    let actualItem = filteredPhonemes[gopIndex]
                    alignedScores.append(AlignedPhoneme(
                        type: .insert,
                        target: nil,
                        actual: actualItem.topPrediction.phoneme,
                        score: actualItem.score,
                        note: "Extra sound"
                    ))
                    currentWordInsertionCount += 1
                    gopIndex += 1
                }
            }
        }
        
        let finalTotalScore = scoreCount > 0 ? totalScore / Double(scoreCount) : 0.0
        
        let groupedAlignedPhonemes = splitAlignedPhonemesByWord(alignedPhonemes: alignedScores, guide: idealPhonemes)
        
        let wordScoreResults: [WordScore] = zip(targetWords, zip(wordScores, groupedAlignedPhonemes)).map { word, data in
            WordScore(word: word, score: data.0, alignedPhonemes: data.1)
        }
        
        return PronunciationEvalResult(
            totalScore: finalTotalScore,
            wordScores: wordScoreResults
        )
    }
    
    private func printAlignmentDetails(result: PronunciationEvalResult) {
        print("")
        print("📋 ALIGNED PHONEMES BY WORD:")
        print("───────────────────────────────────────────────────────────────")
        
        for wordScore in result.wordScores {
            let scoreEmoji = wordScore.score >= 0.8 ? "✅" : (wordScore.score >= 0.5 ? "⚠️" : "❌")
            let modeTag = shouldUseStrictScoring(for: wordScore.word) ? " [STRICT]" : " [LENIENT]"
            print("\(scoreEmoji) \"\(wordScore.word)\"\(modeTag) - Score: \(String(format: "%.2f", wordScore.score))")
            
            for aligned in wordScore.alignedPhonemes {
                let typeStr: String
                switch aligned.type {
                case .match: typeStr = "✓"
                case .replace: typeStr = "✗"
                case .delete: typeStr = "−"
                case .insert: typeStr = "+"
                }
                
                let target = aligned.target ?? "∅"
                let actual = aligned.actual ?? "∅"
                let note = aligned.note.map { " (\($0))" } ?? ""
                
                print("     \(typeStr) target: \(target) | actual: \(actual) | score: \(String(format: "%.2f", aligned.score))\(note)")
            }
        }
        
        print("───────────────────────────────────────────────────────────────")
        print("📊 TOTAL SCORE: \(String(format: "%.2f", result.totalScore))")
        print("═══════════════════════════════════════════════════════════════")
        print("")
    }
    
    private func splitAlignedPhonemesByWord(alignedPhonemes: [AlignedPhoneme], guide: [[String]]) -> [[AlignedPhoneme]] {
        var result: [[AlignedPhoneme]] = []
        var alignedIndex = 0
        
        for targetWord in guide {
            let expectedTargetCount = targetWord.count
            var currentWordChunk: [AlignedPhoneme] = []
            var consumedTargetCount = 0
            
            while alignedIndex < alignedPhonemes.count && consumedTargetCount < expectedTargetCount {
                let current = alignedPhonemes[alignedIndex]
                currentWordChunk.append(current)
                alignedIndex += 1
                if current.type != .insert {
                    consumedTargetCount += 1
                }
            }
            
            while alignedIndex < alignedPhonemes.count {
                if alignedPhonemes[alignedIndex].type == .insert {
                    currentWordChunk.append(alignedPhonemes[alignedIndex])
                    alignedIndex += 1
                } else {
                    break
                }
            }
            
            if !currentWordChunk.isEmpty {
                result.append(currentWordChunk)
            }
        }
        
        if alignedIndex < alignedPhonemes.count {
            if result.isEmpty {
                result.append(Array(alignedPhonemes[alignedIndex...]))
            } else {
                var lastChunk = result.removeLast()
                lastChunk.append(contentsOf: alignedPhonemes[alignedIndex...])
                result.append(lastChunk)
            }
        }
        
        return result
    }
}

// MARK: - Levenshtein

enum EditType { case equal, replace, delete, insert }

struct EditOperation {
    let type: EditType
    let targetRange: Range<Int>
    let actualRange: Range<Int>
}

func levenshteinOpcodes(from source: [String], to target: [String], similarityChecker: (String, String) -> Bool) -> [EditOperation] {
    let m = source.count
    let n = target.count
    
    if m == 0 && n == 0 { return [] }
    if m == 0 { return [EditOperation(type: .insert, targetRange: 0..<0, actualRange: 0..<n)] }
    if n == 0 { return [EditOperation(type: .delete, targetRange: 0..<m, actualRange: 0..<0)] }
    
    let insertCost = 2
    let deleteCost = 3
    
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    
    for i in 0...m { dp[i][0] = i * deleteCost }
    for j in 0...n { dp[0][j] = j * insertCost }
    
    for i in 1...m {
        for j in 1...n {
            let s = source[i-1]
            let t = target[j-1]
            
            if s == t {
                dp[i][j] = dp[i-1][j-1]
            } else {
                let isSimilar = similarityChecker(s, t)
                let replaceCost = isSimilar ? 1 : 4
                
                dp[i][j] = min(
                    dp[i-1][j] + deleteCost,
                    dp[i][j-1] + insertCost,
                    dp[i-1][j-1] + replaceCost
                )
            }
        }
    }
    
    var operations: [EditOperation] = []
    var i = m
    var j = n
    
    while i > 0 || j > 0 {
        let currentVal = dp[i][j]
        
        if i > 0 && j > 0 {
            let s = source[i-1]
            let t = target[j-1]
            let isExact = s == t
            let isSimilar = similarityChecker(s, t)
            let cost = isExact ? 0 : (isSimilar ? 1 : 4)
            
            if currentVal == dp[i-1][j-1] + cost {
                let type: EditType = isExact ? .equal : .replace
                operations.insert(EditOperation(type: type, targetRange: (i-1)..<i, actualRange: (j-1)..<j), at: 0)
                i -= 1
                j -= 1
                continue
            }
        }
        
        if i > 0 && currentVal == dp[i-1][j] + deleteCost {
            operations.insert(EditOperation(type: .delete, targetRange: (i-1)..<i, actualRange: j..<j), at: 0)
            i -= 1
            continue
        }
        
        if j > 0 && currentVal == dp[i][j-1] + insertCost {
            operations.insert(EditOperation(type: .insert, targetRange: i..<i, actualRange: (j-1)..<j), at: 0)
            j -= 1
            continue
        }
        
        break
    }
    
    return mergeConsecutiveOperations(operations)
}

func mergeConsecutiveOperations(_ operations: [EditOperation]) -> [EditOperation] {
    guard !operations.isEmpty else { return [] }
    var merged: [EditOperation] = []
    var current = operations[0]
    
    for i in 1..<operations.count {
        let next = operations[i]
        if current.type == next.type &&
            current.targetRange.upperBound == next.targetRange.lowerBound &&
            current.actualRange.upperBound == next.actualRange.lowerBound {
            current = EditOperation(
                type: current.type,
                targetRange: current.targetRange.lowerBound..<next.targetRange.upperBound,
                actualRange: current.actualRange.lowerBound..<next.actualRange.upperBound
            )
        } else {
            merged.append(current)
            current = next
        }
    }
    merged.append(current)
    return merged
}
