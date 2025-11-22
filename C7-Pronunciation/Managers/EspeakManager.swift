//
//  EspeakManager.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//  Improved version with context-aware phoneme generation and dual-dialect support
//  FIXED: Simplified to 2 dialects (en, en-us), minimal context corrections
//

import Foundation
import libespeak_ng

// MARK: - Phoneme Data Structures

/// Represents a phoneme with its position in the original text
private struct PhonemeWithPosition {
    let phoneme: String
    let textPosition: Int
}

/// Represents phonemes for a single word
public struct WordPhonemes {
    public let word: String
    public let phonemes: [String]
    public let startPosition: Int
    public let endPosition: Int
}

// MARK: - Global Callback

// Global C-function callback required by eSpeak
// It forwards events to our Swift Singleton
private func phonemeCallback(samples: UnsafeMutablePointer<Int16>?, num_samples: Int32, events: UnsafeMutablePointer<espeak_EVENT>?) -> Int32 {
    var evt = events
    while let e = evt?.pointee, e.type != espeakEVENT_LIST_TERMINATED {
        
        if e.type == espeakEVENT_PHONEME {
            let phoneme = withUnsafeBytes(of: e.id.string) { rawPtr in
                String(cString: rawPtr.bindMemory(to: CChar.self).baseAddress!)
            }
            // Accumulate the phoneme character with its text position
            EspeakManager.shared.accumulate(phoneme: phoneme, textPosition: Int(e.text_position))
        } else if e.type == espeakEVENT_WORD {
            // Track word boundaries
            EspeakManager.shared.markWordBoundary(textPosition: Int(e.text_position), length: Int(e.length))
        }
        
        evt = evt?.advanced(by: 1)
    }
    return 0
}

// MARK: - Main Manager Class

public class EspeakManager {
    // Singleton Access
    public static let shared = EspeakManager()
    
    // Internal storage for the current synthesis session
    private var currentPhonemes: [PhonemeWithPosition] = []
    private var wordBoundaries: [(position: Int, length: Int)] = []
    
    /// Loaded vocabulary for filtering phonemes.
    private var validPhonemes: Set<String> = []
    
    /// Track the currently active dialect to avoid redundant switches
    private var currentDialect: Dialect? = nil
    
    /// Available dialect voices (simplified to 2)
    public enum Dialect: String, CaseIterable {
        case us = "en-us"
        case generic = "en"
        
        var voiceName: String {
            return self.rawValue
        }
        
        /// Display name for UI/logging
        var displayName: String {
            switch self {
            case .us: return "American English"
            case .generic: return "Generic English"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Initializes the eSpeak-NG engine.
    /// This constructor is private to enforce the singleton pattern.
    private init() {
        // 1. Find the 'espeak-ng-data' directory in our App's bundle
        guard let bundlePath = Bundle.main.resourcePath else {
            fatalError("EspeakManager: Failed to find app bundle path.")
        }
        
        // 2. Find the Documents directory (where we can write)
        guard FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first != nil else {
            fatalError("EspeakManager: Failed to find documents directory.")
        }
        
        // 3. Set the path for espeak-ng data
        let dataPath = bundlePath
        
        // 4. Initialize Library
        espeak_ng_InitializePath(dataPath)
        let status = espeak_ng_Initialize(nil)
        if status != ENS_OK {
            fatalError("EspeakManager: Failed to initialize eSpeak-NG. Status: \(status)")
        }
        
        // 5. Set Synchronous Mode (Retrieval Mode)
        espeak_ng_InitializeOutput(ENOUTPUT_MODE_SYNCHRONOUS, 0, nil)
        
        // 6. Configuration - start with generic English
        let voiceResult = espeak_ng_SetVoiceByName("en")
        if voiceResult == ENS_OK {
            currentDialect = .generic
        } else {
            print("EspeakManager: WARNING - Failed to set initial voice 'en'")
        }
        
        // Set pitch range to 0 to get a more monotonic (robotic) voice
        espeak_ng_SetParameter(espeakRANGE, 0, 0)
        
        // Enable Phoneme Events with IPA output
        // 1 = Enable Events
        // 2 = espeakPHONEMES_IPA (Output IPA Unicode chars)
        espeak_ng_SetPhonemeEvents(1, 2)
        
        // Set punctuation handling
        espeak_ng_SetParameter(espeakPUNCTUATION, Int32(espeakPUNCT_NONE.rawValue), 0)
        
        // Register our global C function as the callback
        espeak_SetSynthCallback(phonemeCallback)
        
        // Load vocabulary for filtering (optional)
        loadVocabulary()
        
        // Print available voices for debugging
        printAvailableVoices()
        
        print("EspeakManager: Initialized successfully with IPA output and dual-dialect support.")
    }
    
    /// Debug helper to print available voices
    private func printAvailableVoices() {
        print("EspeakManager: Checking available English voices...")
        
        // Test each dialect
        for dialect in Dialect.allCases {
            let result = espeak_ng_SetVoiceByName(dialect.voiceName)
            let status = result == ENS_OK ? "✓ Available" : "✗ NOT Available"
            print("   [\(dialect.rawValue)]: \(status)")
        }
        
        // Reset to generic
        espeak_ng_SetVoiceByName("en")
        currentDialect = .generic
    }
    
    // MARK: - Backward Compatible API (OLD SIGNATURE)
    
    /// **BACKWARD COMPATIBLE** - Original method signature that returns [[String]]
    /// This maintains compatibility with existing code that expects the old return type.
    /// Always returns generic English phonemes for consistency with old behavior.
    ///
    /// - Parameter text: The text to convert to phonemes
    /// - Returns: Array of phoneme arrays, one per word (e.g., [["h", "ə"], ["l", "oʊ"]])
    public func getPhonemes(for text: String) -> [[String]] {
        let wordPhonemes = getPhonemesDetailed(for: text, dialect: .generic)
        return wordPhonemes.map { $0.phonemes }
    }
    
    // MARK: - New Enhanced API
    
    /// Returns a single string of phonemes separated by spaces (e.g. "h ə l oʊ w ɜː l d")
    public func getPhonemesAsString(for text: String, dialect: Dialect = .generic) -> String {
        let phonemesByWord = getPhonemesDetailed(for: text, dialect: dialect)
        return phonemesByWord.map { $0.phonemes.joined() }.joined(separator: " ")
    }
    
    /// Generates phonemes for all supported dialects and returns a dictionary
    /// **Used internally by PronunciationScorer for multi-dialect support**
    internal func getPhonemesForAllDialects(for text: String) -> [Dialect: [[String]]] {
        var result: [Dialect: [[String]]] = [:]
        
        for dialect in Dialect.allCases {
            let wordPhonemes = getPhonemesDetailed(for: text, dialect: dialect)
            result[dialect] = wordPhonemes.map { $0.phonemes }
            
            // Debug: print what we got for each dialect
            let flatPhonemes = wordPhonemes.flatMap { $0.phonemes }
            print("EspeakManager: [\(dialect.rawValue)] synthesized: \(flatPhonemes.joined(separator: " "))")
        }
        
        return result
    }
    
    /// Generates context-aware phonemes for a given line of text with detailed word information.
    /// This method synthesizes the ENTIRE phrase to maintain context, then splits by word.
    ///
    /// - Parameters:
    ///   - text: The text to convert to phonemes
    ///   - dialect: The English dialect to use (defaults to generic English)
    /// - Returns: Array of WordPhonemes with detailed position information
    public func getPhonemesDetailed(for text: String, dialect: Dialect = .generic) -> [WordPhonemes] {
        // 1. Set the voice for the desired dialect (with verification)
        let dialectSet = setDialect(dialect)
        if !dialectSet {
            print("EspeakManager: WARNING - Could not set dialect \(dialect.rawValue), using fallback")
        }
        
        // 2. Clean the text but preserve structure
        let cleanedText = cleanText(text)
        
        // 3. Extract words from the original text
        let words = extractWords(from: cleanedText)
        
        // 4. Synthesize EACH WORD separately (original reliable approach)
        var result: [WordPhonemes] = []
        
        for word in words {
            let phonemes = synthesizeWord(word.word)
            
            result.append(WordPhonemes(
                word: word.word,
                phonemes: phonemes,
                startPosition: word.position,
                endPosition: word.position + word.word.count
            ))
        }
        
        // 5. Apply MINIMAL context-aware corrections
        // IMPORTANT: Only correct articles, NOT content words!
        // Let eSpeak's output stand for most words to preserve dialect differences
        result = applyMinimalContextCorrections(to: result)
        
        return result
    }
    
    /// Synthesizes a single word and returns its phonemes
    private func synthesizeWord(_ word: String) -> [String] {
        // Clear previous state
        clear()
        
        // Synthesize the word
        word.withCString { cText in
            espeak_ng_Synthesize(cText, strlen(cText) + 1, 0, POS_CHARACTER, 0, UInt32(espeakCHARS_UTF8), nil, nil)
        }
        
        // Force eSpeak to process all remaining buffered events
        espeak_ng_Synchronize()
        
        // Return the phonemes collected
        return currentPhonemes.map { $0.phoneme }
    }
    
    /// Applies MINIMAL context-aware corrections to phonemes
    ///
    /// PHILOSOPHY: Only correct words where the citation (dictionary) form would sound
    /// WRONG or FOREIGN in connected speech - not just "careful" or "emphatic".
    ///
    /// CRITERIA FOR CORRECTION:
    /// 1. The citation form would sound unnatural/foreign in connected speech
    /// 2. Native speakers virtually never use the citation form in normal speech
    /// 3. Using the citation form changes perceived meaning (implies unintended emphasis)
    ///
    /// ARTICLES ONLY meet this criteria:
    /// - "a" /eɪ/ → /ə/: Saying "I am /eɪ/ boy" sounds like spelling the letter
    /// - "an" /æn/ → /ən/: Similar to "a"
    /// - "the" /ðiː/ → /ðə/: Using /ðiː/ before consonants implies contrast
    ///
    /// EVERYTHING ELSE is left alone because both forms are acceptable:
    /// - "for" /fɔːr/ vs /fər/: Both fine; full form = careful speech, not wrong
    /// - "to" /tuː/ vs /tə/: Both acceptable
    /// - "of" /ʌv/ vs /əv/: Both acceptable
    /// - "and" /ænd/ vs /ənd/: Both common
    /// - "can", "you", "are", etc.: All have acceptable full forms
    ///
    /// The PronunciationScorer's similarity checking handles these variants.
    private func applyMinimalContextCorrections(to wordPhonemes: [WordPhonemes]) -> [WordPhonemes] {
        var result = wordPhonemes
        
        for (index, wordPhoneme) in wordPhonemes.enumerated() {
            let word = wordPhoneme.word.lowercased()
            let isNotFirstWord = index > 0
            let isNotLastWord = index < wordPhonemes.count - 1
            let isInContext = isNotFirstWord || isNotLastWord
            
            // Get next word if available (for "the" rule)
            let nextWord = isNotLastWord ? wordPhonemes[index + 1].word.lowercased() : ""
            
            var correctedPhonemes: [String]? = nil
            
            switch word {
                
            // ═══════════════════════════════════════════════════════════════
            // ARTICLE "a"
            // Citation: /eɪ/ (like the letter name)
            // Connected: /ə/ (schwa)
            //
            // WHY CORRECT: Saying "I want /eɪ/ cookie" sounds like you're
            // spelling out the letter or making a contrast ("I want A cookie,
            // not THE cookie"). Native speakers essentially never use /eɪ/
            // in normal connected speech.
            // ═══════════════════════════════════════════════════════════════
            case "a":
                if isInContext {
                    correctedPhonemes = ["ə"]
                }
                
            // ═══════════════════════════════════════════════════════════════
            // ARTICLE "an"
            // Citation: /æn/
            // Connected: /ən/
            //
            // WHY CORRECT: Same as "a" - the full vowel sounds emphatic/foreign
            // in connected speech. "I want /æn/ apple" implies contrast.
            // ═══════════════════════════════════════════════════════════════
            case "an":
                if isInContext {
                    correctedPhonemes = ["ə", "n"]
                }
                
            // ═══════════════════════════════════════════════════════════════
            // ARTICLE "the" - DO NOT CORRECT
            //
            // Both /ðiː/ and /ðə/ are acceptable in natural speech:
            // - "the /ðə/ book" ✓
            // - "the /ðiː/ book" ✓ (slightly emphatic but not wrong)
            // - "the /ðiː/ apple" ✓ (before vowels)
            // - "the /ðə/ apple" ✓ (casual, also fine)
            //
            // Unlike "a/an", using either form doesn't sound foreign or wrong.
            // Native speakers mix these freely. Let eSpeak's output stand and
            // the scorer will accept both via wordSpecificVariants.
            // ═══════════════════════════════════════════════════════════════
            // case "the": -- REMOVED, both forms acceptable
                
            // ═══════════════════════════════════════════════════════════════
            // EVERYTHING ELSE: NO CORRECTION
            // ═══════════════════════════════════════════════════════════════
            default:
                break
            }
            
            // Only update if we have a correction
            if let phonemes = correctedPhonemes {
                result[index] = WordPhonemes(
                    word: wordPhoneme.word,
                    phonemes: phonemes,
                    startPosition: wordPhoneme.startPosition,
                    endPosition: wordPhoneme.endPosition
                )
            }
        }
        
        return result
    }
    
    // MARK: - Private Helpers
    
    /// Sets the eSpeak voice to the specified dialect
    /// Returns success/failure and only changes if different from current
    @discardableResult
    private func setDialect(_ dialect: Dialect) -> Bool {
        // Skip if already set to this dialect
        if currentDialect == dialect {
            return true
        }
        
        let result = espeak_ng_SetVoiceByName(dialect.voiceName)
        
        if result == ENS_OK {
            currentDialect = dialect
            return true
        } else {
            print("EspeakManager: ERROR - Failed to set voice '\(dialect.voiceName)', error code: \(result)")
            
            // Fallback to generic if US fails
            if dialect == .us {
                print("EspeakManager: Trying fallback to generic 'en'...")
                let fallbackResult = espeak_ng_SetVoiceByName("en")
                if fallbackResult == ENS_OK {
                    currentDialect = .generic
                    print("EspeakManager: Fallback to 'en' succeeded")
                }
            }
            
            return false
        }
    }
    
    /// Cleans text while preserving word structure
    private func cleanText(_ text: String) -> String {
        // Define punctuation to remove, but KEEP apostrophes and hyphens
        // Hyphens are important for compound words like "in-person"
        let punctuationToStrip = CharacterSet.punctuationCharacters
            .subtracting(CharacterSet(charactersIn: "'-"))
        
        // Remove extra punctuation but keep spacing
        var cleaned = ""
        for char in text.lowercased() {
            if char.unicodeScalars.allSatisfy({ punctuationToStrip.contains($0) }) {
                // Skip punctuation (except apostrophes and hyphens)
                continue
            }
            cleaned.append(char)
        }
        
        return cleaned
    }
    
    /// Extracts words and their positions from text
    private func extractWords(from text: String) -> [(word: String, position: Int)] {
        var words: [(String, Int)] = []
        var currentWord = ""
        var wordStart = 0
        
        for (index, char) in text.enumerated() {
            if char.isWhitespace {
                if !currentWord.isEmpty {
                    words.append((currentWord, wordStart))
                    currentWord = ""
                }
            } else {
                if currentWord.isEmpty {
                    wordStart = index
                }
                currentWord.append(char)
            }
        }
        
        // Add the last word
        if !currentWord.isEmpty {
            words.append((currentWord, wordStart))
        }
        
        return words
    }
    
    // MARK: - Internal Callback Handlers
    
    /// (Called by C callback) Appends a phoneme to the internal list with its position
    internal func accumulate(phoneme: String, textPosition: Int) {
        // 1. Filter out known separators
        if phoneme.isEmpty || phoneme == " " || phoneme == "_" {
            return
        }
        
        // 2. Clean stress markers and eSpeak-specific annotations
        var cleanedPhoneme = phoneme
            .replacingOccurrences(of: "ˈ", with: "")  // Primary stress
            .replacingOccurrences(of: "ˌ", with: "")  // Secondary stress
        
        // 3. Remove eSpeak-specific annotation characters
        // H = aspiration marker (attached to phonemes like ɔːɹH)
        // ʰ = aspiration superscript
        // ʲ = palatalization
        // ⁿ = nasal release
        // ˡ = lateral release
        // These are phonetic details we don't need for pronunciation scoring
        let espeakAnnotations: [String] = ["H", "ʰ", "ʲ", "ⁿ", "ˡ", "ʷ", "ˠ", "ˤ", "̚"]
        for annotation in espeakAnnotations {
            cleanedPhoneme = cleanedPhoneme.replacingOccurrences(of: annotation, with: "")
        }
        
        // 4. Filter out corrupted/invalid Unicode characters
        cleanedPhoneme = String(cleanedPhoneme.unicodeScalars.filter { scalar in
            // Filter out replacement characters and control characters
            return scalar.value != 0xFFFD && // Replacement character �
                   scalar.value != 0x0000 && // Null
                   scalar.value >= 0x0020    // Filter control chars
        })
        
        // 5. If the string was only a marker or is now empty, skip it
        if cleanedPhoneme.isEmpty {
            return
        }
        
        // 6. Append the cleaned phoneme with its position
        currentPhonemes.append(PhonemeWithPosition(
            phoneme: cleanedPhoneme,
            textPosition: textPosition
        ))
    }
    
    /// (Called by C callback) Marks a word boundary
    internal func markWordBoundary(textPosition: Int, length: Int) {
        wordBoundaries.append((position: textPosition, length: length))
    }
    
    /// Resets the internal state for a new synthesis task
    private func clear() {
        currentPhonemes = []
        wordBoundaries = []
    }
    
    /// Loads and decodes the vocab.json file
    private func loadVocabulary() {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "json") else {
            print("EspeakManager: WARNING - vocab.json not found. Phoneme filtering will be disabled.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let vocab = try JSONDecoder().decode(Vocabulary.self, from: data)
            
            let specialTokens = Set([
                vocab.specialTokens.pad,
                vocab.specialTokens.unk,
                vocab.specialTokens.bos,
                vocab.specialTokens.eos
            ])
            
            self.validPhonemes = Set(vocab.tokenToId.keys.filter { !specialTokens.contains($0) })
            
            print("EspeakManager: Successfully loaded \(self.validPhonemes.count) valid phonemes.")
        } catch {
            print("EspeakManager: ERROR - Failed to load vocab.json: \(error)")
        }
    }
}

// MARK: - Vocabulary Model

private struct Vocabulary: Decodable {
    let vocabSize: Int
    let tokenToId: [String: Int]
    let specialTokens: SpecialTokens
    
    enum CodingKeys: String, CodingKey {
        case vocabSize = "vocab_size"
        case tokenToId = "token_to_id"
        case specialTokens = "special_tokens"
    }
}

private struct SpecialTokens: Decodable {
    let pad: String
    let unk: String
    let bos: String
    let eos: String
}
