//
//  EspeakManager.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//  Improved version with context-aware phoneme generation and multi-dialect support
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
    
    /// Available dialect voices
    public enum Dialect: String {
        case us = "en-us"
        case uk = "en-gb"
        case generic = "en"
        
        var voiceName: String {
            switch self {
            case .us: return "en-us"
            case .uk: return "en-gb"
            case .generic: return "en"
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
        
        // 6. Configuration
        espeak_ng_SetVoiceByName("en")
        
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
        
        print("EspeakManager: Initialized successfully with IPA output and multi-dialect support.")
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
        
        for dialect in [Dialect.us, .uk, .generic] {
            let wordPhonemes = getPhonemesDetailed(for: text, dialect: dialect)
            result[dialect] = wordPhonemes.map { $0.phonemes }
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
        // 1. Set the voice for the desired dialect
        setDialect(dialect)
        
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
        
        // 5. Apply context-aware corrections to common function words
        result = applyContextCorrections(to: result)
        
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
    
    /// Applies context-aware corrections to phonemes for common function words
    private func applyContextCorrections(to wordPhonemes: [WordPhonemes]) -> [WordPhonemes] {
        var result = wordPhonemes
        
        for (index, wordPhoneme) in wordPhonemes.enumerated() {
            let word = wordPhoneme.word.lowercased()
            let isNotFirstWord = index > 0
            let isNotLastWord = index < wordPhonemes.count - 1
            
            // Get next word if available
            let nextWord = isNotLastWord ? wordPhonemes[index + 1].word.lowercased() : ""
            let nextWordStartsWithVowel = nextWord.first.map { "aeiou".contains($0) } ?? false
            
            var correctedPhonemes = wordPhoneme.phonemes
            
            // Apply context-based corrections
            switch word {
            // Article "a" - becomes schwa in context
            case "a":
                if isNotFirstWord || isNotLastWord {
                    correctedPhonemes = ["ə"]
                }
                
            // Article "the" - /ðiː/ before vowels, /ðə/ before consonants
            case "the":
                if nextWordStartsWithVowel {
                    correctedPhonemes = ["ð", "iː"]
                } else {
                    correctedPhonemes = ["ð", "ə"]
                }
                
            // Preposition "to" - becomes /tə/ when unstressed
            case "to":
                if isNotFirstWord && isNotLastWord {
                    correctedPhonemes = ["t", "ə"]
                }
                
            // Auxiliary "can" - becomes /kən/ when unstressed
            case "can":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["k", "ə", "n"]
                }
                
            // Modal "will" - becomes /wəl/ when unstressed
            case "will":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["w", "ə", "l"]
                }
                
            // Auxiliary "have" - becomes /həv/ or /əv/ when unstressed
            case "have":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["h", "ə", "v"]
                }
                
            // Auxiliary "has" - becomes /həz/ or /əz/ when unstressed
            case "has":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["h", "ə", "z"]
                }
                
            // Auxiliary "had" - becomes /həd/ or /əd/ when unstressed
            case "had":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["h", "ə", "d"]
                }
                
            // Auxiliary "would" - becomes /wəd/ when unstressed
            case "would":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["w", "ə", "d"]
                }
                
            // Auxiliary "should" - becomes /ʃəd/ when unstressed
            case "should":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ʃ", "ə", "d"]
                }
                
            // Auxiliary "could" - becomes /kəd/ when unstressed
            case "could":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["k", "ə", "d"]
                }
                
            // Preposition "of" - becomes /əv/ when unstressed
            case "of":
                correctedPhonemes = ["ə", "v"]
                
            // Preposition "for" - becomes /fər/ or /fɚ/ when unstressed
            case "for":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["f", "ɚ"]
                }
                
            // Conjunction "and" - becomes /ənd/ or /ən/ when unstressed
            case "and":
                if isNotLastWord {
                    correctedPhonemes = ["ə", "n", "d"]
                }
                
            // Pronoun "you" - becomes /jə/ when unstressed
            case "you":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["j", "ə"]
                }
                
            // Auxiliary "are" - becomes /ɚ/ or /ər/ when unstressed
            case "are":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ɚ"]
                }
                
            // Auxiliary "is" - becomes /z/ or /s/ when contracted
            case "is":
                if isNotFirstWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ɪ", "z"]
                }
                
            // Preposition "at" - becomes /ət/ when unstressed
            case "at":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ə", "t"]
                }
                
            // Preposition "from" - becomes /frəm/ when unstressed
            case "from":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["f", "r", "ə", "m"]
                }
                
            // Pronoun "he" - becomes /i/ when unstressed
            case "he":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["i"]
                }
                
            // Pronoun "she" - becomes /ʃi/ when unstressed
            case "she":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ʃ", "i"]
                }
                
            // Pronoun "we" - becomes /wi/ when unstressed
            case "we":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["w", "i"]
                }
                
            // Auxiliary "do" - becomes /də/ when unstressed
            case "do":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["d", "ə"]
                }
                
            // Auxiliary "does" - becomes /dəz/ when unstressed
            case "does":
                if isNotLastWord && !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["d", "ə", "z"]
                }
                
            // Preposition "than" - becomes /ðən/ when unstressed
            case "than":
                correctedPhonemes = ["ð", "ə", "n"]
                
            // Conjunction "as" - becomes /əz/ when unstressed
            case "as":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ə", "z"]
                }
                
            // Conjunction "but" - becomes /bət/ when unstressed
            case "but":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["b", "ə", "t"]
                }
                
            // Pronoun "them" - becomes /ðəm/ when unstressed
            case "them":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ð", "ə", "m"]
                }
                
            // Pronoun "him" - becomes /ɪm/ when unstressed
            case "him":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ɪ", "m"]
                }
                
            // Pronoun "her" - becomes /ɚ/ or /hɚ/ when unstressed
            case "her":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["h", "ɚ"]
                }
                
            // Existential "there" - becomes /ðɚ/ when unstressed
            case "there":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ð", "ɚ"]
                }
                
            // Possession "his" - becomes /ɪz/ when unstressed
            case "his":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ɪ", "z"]
                }
                
            // Preposition "with" - becomes /wɪð/ or /wɪθ/ (can be /wɪt/ in fast speech)
            case "with":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["w", "ɪ", "ð"]
                }
                
            // Article "an" - becomes /ən/ when unstressed
            case "an":
                if !isEmphatic(word: word, inContext: wordPhonemes, at: index) {
                    correctedPhonemes = ["ə", "n"]
                }
                
            default:
                break
            }
            
            result[index] = WordPhonemes(
                word: wordPhoneme.word,
                phonemes: correctedPhonemes,
                startPosition: wordPhoneme.startPosition,
                endPosition: wordPhoneme.endPosition
            )
        }
        
        return result
    }
    
    /// Determines if a word is emphatic (stressed) in context
    private func isEmphatic(word: String, inContext context: [WordPhonemes], at index: Int) -> Bool {
        // Simple heuristic: if it's the last word or first word, might be emphatic
        // This is a simplified check - real emphasis detection would need prosody analysis
        return index == 0 || index == context.count - 1
    }
    
    // MARK: - Private Helpers
    
    /// Sets the eSpeak voice to the specified dialect
    private func setDialect(_ dialect: Dialect) {
        espeak_ng_SetVoiceByName(dialect.voiceName)
    }
    
    /// Cleans text while preserving word structure
    private func cleanText(_ text: String) -> String {
        // Define punctuation to remove, but KEEP apostrophes
        let punctuationToStrip = CharacterSet.punctuationCharacters
            .subtracting(CharacterSet(charactersIn: "'"))
        
        // Remove extra punctuation but keep spacing
        var cleaned = ""
        for char in text.lowercased() {
            if char.unicodeScalars.allSatisfy({ punctuationToStrip.contains($0) }) {
                // Skip punctuation (except apostrophes)
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
        
        // 2. Clean stress markers only
        let cleanedPhoneme = phoneme
            .replacingOccurrences(of: "ˈ", with: "")
            .replacingOccurrences(of: "ˌ", with: "")
        
        // 3. If the string was only a marker, skip it
        if cleanedPhoneme.isEmpty {
            return
        }
        
        // 4. Append the cleaned phoneme with its position
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
