//
//  PronunciationScorer.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//  Improved version with dual-dialect support, compound phoneme handling, and robust alignment
//

import Foundation

// MARK: - Pronunciation Scorer Singleton

public class PronunciationScorer {
    public static let shared = PronunciationScorer()
    
    private let espeakManager = EspeakManager.shared
    
    /// Toggle to enable/disable phoneme similarity groups
    /// When disabled, only exact matches and dialect equivalents are accepted
    public var usePhonemeSimilarityGroups: Bool = false
    
    private init() { }
    
    // MARK: - Phonetic Similarity Data
    
    /// Dialect-specific phoneme mappings for cross-dialect acceptance
    /// These handle US vs Generic English differences
    private let dialectPhonemeEquivalents: [String: Set<String>] = [
        // R-colored vowels (US) vs non-rhotic (Generic)
        "ɝ": ["ɜː", "ɜ", "ɜːɹ"],
        "ɚ": ["ə", "əɹ", "ɜː", "ɜ"],   // ɚ is r-colored schwa, equivalent to ɜː in some contexts
        "ɑr": ["ɑː"],
        "ɑːɹ": ["ɑː", "ɑ"],
        "ɔːɹ": ["ɔː", "ɔ", "oː"],      // "for", "or", "more"
        "ɛɹ": ["ɛə", "eə", "ɛ"],        // "air", "care"
        "ɪɹ": ["ɪə", "iə", "ɪ"],        // "ear", "near"
        "ʊɹ": ["ʊə", "uə", "ʊ"],        // "tour", "sure"
        
        // NURSE vowel - ɜː (UK) vs ɝ/ɚ (US)
        // "prefer", "person", "bird", "nurse"
        "ɜː": ["ɝ", "ɚ", "ɜ"],
        "ɜ": ["ɜː", "ɝ", "ɚ"],
        
        // LOT-CLOTH vowel (US /ɑ/ vs Generic /ɒ/)
        "ɑ": ["ɒ", "ɔ"],
        "ɒ": ["ɑ", "ɔ"],
        
        // TRAP vowel - /æ/ (US/UK) vs /a/ (generic/other notations)
        "æ": ["a"],
        "a": ["æ"],
        
        // KIT vowel variations
        // ᵻ (barred i) is used in some transcriptions as a reduced /ɪ/
        "ɪ": ["i", "ɪ̈", "ᵻ"],
        "ᵻ": ["ɪ", "ə", "i"],           // Barred i - often a reduced vowel
        
        // GOAT diphthong variations
        "oʊ": ["əʊ", "o", "oː"],
        "əʊ": ["oʊ", "o", "oː"],
        
        // T-flapping (US /ɾ/ vs /t/)
        "ɾ": ["t", "d"],
        "t": ["ɾ"],
        
        // Dark L variations
        "l": ["ɫ", "ɫ̩"],
        "ɫ": ["l"],
        
        // STRUT vowel variations
        "ʌ": ["ɐ", "ə"],
        "ɐ": ["ʌ", "ə"],
        
        // Rhotic vs non-rhotic 'r'
        "ɹ": ["r", "ɾ"],
        "r": ["ɹ", "ɾ"],
        
        // Short i variations
        "iː": ["ɪ", "i"],
        
        // FOOT vowel
        "ʊ": ["u", "ɷ"],
    ]
    
    /// Word-specific acceptable phoneme variants
    ///
    /// PHILOSOPHY: Vowel reduction to schwa is ONLY acceptable in specific
    /// short function words, NOT globally. This prevents false negatives
    /// on content words like "food", "moon", "can't" where the full vowel
    /// is required.
    ///
    /// Structure: [word: [target_phoneme: Set<acceptable_variants>]]
    ///
    /// Criteria for inclusion:
    /// 1. Short words (1-2 syllables)
    /// 2. Function words (articles, prepositions, conjunctions, auxiliaries)
    /// 3. High frequency in connected speech
    /// 4. Reduction is well-documented in phonetics
    private let wordSpecificVariants: [String: [String: Set<String>]] = [
        // ═══════════════════════════════════════════════════════════════
        // ARTICLES
        // ═══════════════════════════════════════════════════════════════
        // "the" - both /ðiː/ and /ðə/ are acceptable in any context
        // Native speakers mix these freely regardless of following sound
        "the": [
            "iː": ["ə", "ɪ", "i"],      // /ðiː/ target, /ðə/ actual = OK
            "i": ["ə", "ɪ"],            // /ði/ target, /ðə/ actual = OK
            "ə": ["iː", "ɪ", "i"],      // /ðə/ target, /ðiː/ actual = OK
        ],
        
        // ═══════════════════════════════════════════════════════════════
        // PREPOSITIONS
        // ═══════════════════════════════════════════════════════════════
        "to": ["uː": ["ə", "ʊ"], "u": ["ə", "ʊ"]],           // /tuː/ → /tə/
        "for": ["ɔː": ["ə", "ɔ"], "ɔːɹ": ["ə", "ɚ", "ər"]],  // /fɔːr/ → /fər/
        "of": ["ʌ": ["ə"], "ɒ": ["ə"]],                       // /ʌv/ → /əv/
        "from": ["ʌ": ["ə"], "ɒ": ["ə"]],                     // /frʌm/ → /frəm/
        "at": ["æ": ["ə"]],                                    // /æt/ → /ət/
        "as": ["æ": ["ə"]],                                    // /æz/ → /əz/
        
        // ═══════════════════════════════════════════════════════════════
        // CONJUNCTIONS
        // ═══════════════════════════════════════════════════════════════
        "and": ["æ": ["ə", "ɛ"]],                              // /ænd/ → /ənd/, /ən/
        "but": ["ʌ": ["ə"]],                                   // /bʌt/ → /bət/
        "or": ["ɔː": ["ə"], "ɔːɹ": ["ə", "ɚ"]],               // /ɔːr/ → /ər/
        "than": ["æ": ["ə"]],                                  // /ðæn/ → /ðən/
        "that": ["æ": ["ə"]],                                  // /ðæt/ → /ðət/ (conjunction)
        
        // ═══════════════════════════════════════════════════════════════
        // AUXILIARIES / MODALS
        // ═══════════════════════════════════════════════════════════════
        "can": ["æ": ["ə"]],                                   // /kæn/ → /kən/
        "have": ["æ": ["ə"]],                                  // /hæv/ → /həv/
        "has": ["æ": ["ə"]],                                   // /hæz/ → /həz/
        "had": ["æ": ["ə"]],                                   // /hæd/ → /həd/
        "was": ["ɒ": ["ə"], "ʌ": ["ə"]],                       // /wɒz/ → /wəz/
        "were": ["ɜː": ["ə"], "ɝ": ["ə"]],                     // /wɜːr/ → /wər/
        "are": ["ɑː": ["ə"], "ɑːɹ": ["ə", "ɚ"]],              // /ɑːr/ → /ər/
        "do": ["uː": ["ə", "ʊ"], "u": ["ə"]],                  // /duː/ → /də/
        "does": ["ʌ": ["ə"]],                                  // /dʌz/ → /dəz/
        "would": ["ʊ": ["ə"]],                                 // /wʊd/ → /wəd/
        "could": ["ʊ": ["ə"]],                                 // /kʊd/ → /kəd/
        "should": ["ʊ": ["ə"]],                                // /ʃʊd/ → /ʃəd/
        "will": ["ɪ": ["ə"]],                                  // /wɪl/ → /wəl/
        "shall": ["æ": ["ə"]],                                 // /ʃæl/ → /ʃəl/
        "must": ["ʌ": ["ə"]],                                  // /mʌst/ → /məst/
        
        // ═══════════════════════════════════════════════════════════════
        // PRONOUNS
        // ═══════════════════════════════════════════════════════════════
        "you": ["uː": ["ə", "ʊ"], "u": ["ə"]],                 // /juː/ → /jə/
        "your": ["ɔː": ["ə"], "ɔːɹ": ["ə", "ɚ"]],             // /jɔːr/ → /jər/
        "he": ["iː": ["ɪ", "i"]],                              // /hiː/ → /hi/, /ɪ/
        "she": ["iː": ["ɪ", "i"]],                             // /ʃiː/ → /ʃi/
        "we": ["iː": ["ɪ", "i"]],                              // /wiː/ → /wi/
        "me": ["iː": ["ɪ", "i"]],                              // /miː/ → /mi/
        "her": ["ɜː": ["ə"], "ɝ": ["ə", "ɚ"]],                // /hɜːr/ → /hər/, /ər/
        "him": ["ɪ": ["ə"]],                                   // /hɪm/ → /ɪm/, /əm/
        "his": ["ɪ": ["ə"]],                                   // /hɪz/ → /ɪz/
        "them": ["ɛ": ["ə"]],                                  // /ðɛm/ → /ðəm/
        "us": ["ʌ": ["ə"]],                                    // /ʌs/ → /əs/
        "our": ["aʊ": ["ɑː", "ɑ"], "ɑː": ["ə"]],              // /aʊər/ → /ɑːr/, /ər/
        
        // ═══════════════════════════════════════════════════════════════
        // OTHER COMMON FUNCTION WORDS
        // ═══════════════════════════════════════════════════════════════
        "be": ["iː": ["ɪ", "i"]],                              // /biː/ → /bi/
        "been": ["iː": ["ɪ"]],                                 // /biːn/ → /bɪn/
        "just": ["ʌ": ["ə"]],                                  // /dʒʌst/ → /dʒəst/
        "some": ["ʌ": ["ə"]],                                  // /sʌm/ → /səm/
        "there": ["ɛ": ["ə"], "ɛə": ["ə"]],                   // /ðɛər/ → /ðər/
    ]
    
    /// Voicing pairs - consonants that differ ONLY in voicing
    /// These are ALWAYS considered similar for alignment purposes
    private let voicingPairs: [Set<String>] = [
        // Fricatives
        ["z", "s"],
        ["v", "f"],
        ["ð", "θ"],
        ["ʒ", "ʃ"],
        
        // Stops
        ["b", "p"],
        ["d", "t"],
        ["g", "k"],
        ["ɡ", "k"],
        
        // Affricates
        ["dʒ", "tʃ"],
    ]
    
    /// Compound phoneme equivalences
    /// Maps compound/ligature phonemes to their component equivalents
    private let compoundPhonemeEquivalents: [String: Set<String>] = [
        // R-colored vowels can match vowel + r
        "ɔːɹ": ["ɔː", "ɔːr", "ɔr", "oːɹ", "oːr"],
        "ɑːɹ": ["ɑː", "ɑːr", "ɑr", "aːɹ", "aːr"],
        "ɛɹ": ["ɛr", "ɛə", "eɹ", "er"],
        "ɪɹ": ["ɪr", "ɪə", "iɹ", "ir"],
        "ʊɹ": ["ʊr", "ʊə", "uɹ", "ur"],
        "ɚ": ["əɹ", "ər"],
        "ɝ": ["ɜːɹ", "ɜːr", "ɜɹ"],
        
        // Affricates
        "tʃ": ["t͡ʃ"],
        "dʒ": ["d͡ʒ"],
    ]
    
    /// Core phonetic similarity groups - strict grouping
    private let phonemeSimilarityGroups: [Set<String>] = [
        // Keep only very similar vowels together
        ["a", "æ"],
        ["ɑ", "ɒ"],
        
        // Schwa variants
        ["ə", "ɐ", "ᵻ"],
        
        // I-like vowels
        ["i", "iː"],
        ["ɪ"],
        
        // U-like vowels
        ["u", "uː"],
        ["ʊ"],
        
        // E-like vowels
        ["e", "ɛ"],
        ["ɜ", "ɜː"],
        
        // O-like vowels
        ["o", "oː"],
        ["ɔ", "ɔː"],
        
        // Rhotics
        ["r", "ɹ", "ɾ"],
        
        // Laterals
        ["l", "ɫ"],
    ]
    
    /// Checks if two phonemes form a voicing pair (differ only in voicing)
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
    
    /// Strips length markers and stress markers from a phoneme
    private func stripModifiers(_ phoneme: String) -> String {
        return phoneme.replacingOccurrences(of: "[ːˌˈʲ]", with: "", options: .regularExpression)
    }
    
    /// Checks if a phoneme variant is acceptable for a specific word
    /// This handles function word reductions (e.g., "to" /tuː/ → /tə/)
    private func isWordSpecificVariant(word: String, target: String, actual: String) -> Bool {
        let wordLower = word.lowercased()
        
        guard let wordVariants = wordSpecificVariants[wordLower] else {
            return false
        }
        
        // Check direct match
        if let acceptableVariants = wordVariants[target], acceptableVariants.contains(actual) {
            return true
        }
        
        // Check with stripped modifiers
        let cleanTarget = stripModifiers(target)
        let cleanActual = stripModifiers(actual)
        
        if let acceptableVariants = wordVariants[cleanTarget], acceptableVariants.contains(cleanActual) {
            return true
        }
        
        return false
    }
    
    /// Checks if two phonemes are similar, considering dialect variations and compounds
    /// This is the GLOBAL check - does not consider word context
    private func checkPhonemeSimilarity(target: String, actual: String) -> Bool {
        return checkPhonemeSimilarityWithContext(target: target, actual: actual, word: nil)
    }
    
    /// Checks if two phonemes are similar, with optional word context for function word reductions
    private func checkPhonemeSimilarityWithContext(target: String, actual: String, word: String?) -> Bool {
        let normalizedTarget = target.precomposedStringWithCanonicalMapping
        let normalizedActual = actual.precomposedStringWithCanonicalMapping
        
        // 1. Exact Match
        if normalizedTarget == normalizedActual {
            return true
        }
        
        // 2. Check voicing pairs (always enabled)
        if areVoicingPair(phoneme1: target, phoneme2: actual) {
            return true
        }
        
        // 3. Check word-specific variants (function word reductions)
        if let word = word, isWordSpecificVariant(word: word, target: target, actual: actual) {
            return true
        }
        
        // 4. Check compound phoneme equivalents
        if let equivalents = compoundPhonemeEquivalents[target], equivalents.contains(actual) {
            return true
        }
        if let equivalents = compoundPhonemeEquivalents[actual], equivalents.contains(target) {
            return true
        }
        
        // 5. Check dialect equivalents
        if let equivalents = dialectPhonemeEquivalents[target], equivalents.contains(actual) {
            return true
        }
        if let equivalents = dialectPhonemeEquivalents[actual], equivalents.contains(target) {
            return true
        }
        
        // 6. Strip modifiers and check again
        let cleanTarget = stripModifiers(target)
        let cleanActual = stripModifiers(actual)
        
        if cleanTarget == cleanActual { return true }
        
        // 7. Check dialect equivalents with stripped versions
        if let equivalents = dialectPhonemeEquivalents[cleanTarget], equivalents.contains(cleanActual) {
            return true
        }
        if let equivalents = dialectPhonemeEquivalents[cleanActual], equivalents.contains(cleanTarget) {
            return true
        }
        
        // 8. Check compound equivalents with stripped versions
        if let equivalents = compoundPhonemeEquivalents[cleanTarget], equivalents.contains(cleanActual) {
            return true
        }
        if let equivalents = compoundPhonemeEquivalents[cleanActual], equivalents.contains(cleanTarget) {
            return true
        }
        
        // 9. Only check similarity groups if enabled
        if usePhonemeSimilarityGroups {
            for group in phonemeSimilarityGroups {
                if group.contains(target) && group.contains(actual) {
                    return true
                }
                if group.contains(cleanTarget) && group.contains(cleanActual) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Scoring Methods
    
    /// Default scoring method - uses multi-dialect support by default for best accuracy.
    func alignAndScore(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String
    ) -> PronunciationEvalResult {
        return alignAndScoreMultiDialect(
            decodedPhonemes: decodedPhonemes,
            targetSentence: targetSentence
        )
    }
    
    /// Multi-dialect scoring - tries both dialects and returns best match.
    private func alignAndScoreMultiDialect(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String
    ) -> PronunciationEvalResult {
        
        // Get phonemes for all dialects
        let allDialectPhonemes = espeakManager.getPhonemesForAllDialects(for: targetSentence)
        
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
        
        // Try generic English first (primary)
        if let genericPhonemes = allDialectPhonemes[.generic] {
            let genericResult = scoreAgainstDialect(
                decodedPhonemes: decodedPhonemes,
                targetSentence: targetSentence,
                idealPhonemes: genericPhonemes,
                dialect: .generic
            )
            
            // If generic scores well (>0.75), use it
            if genericResult.totalScore > 0.75 {
                print("✅ Using Generic English: Score = \(String(format: "%.2f", genericResult.totalScore))")
                printAlignmentDetails(result: genericResult)
                return genericResult
            }
            
            // Otherwise, try all dialects and pick best
            var bestResult = genericResult
            var bestScore = genericResult.totalScore
            var bestDialect = EspeakManager.Dialect.generic
            
            print("📊 DIALECT SCORES:")
            print("   [en]: \(String(format: "%.2f", genericResult.totalScore))")
            
            for (dialect, dialectPhonemes) in allDialectPhonemes where dialect != .generic {
                let result = scoreAgainstDialect(
                    decodedPhonemes: decodedPhonemes,
                    targetSentence: targetSentence,
                    idealPhonemes: dialectPhonemes,
                    dialect: dialect
                )
                
                print("   [\(dialect.rawValue)]: \(String(format: "%.2f", result.totalScore))")
                
                if result.totalScore > bestScore {
                    bestScore = result.totalScore
                    bestResult = result
                    bestDialect = dialect
                }
            }
            
            print("")
            print("🏆 BEST DIALECT: \(bestDialect.rawValue) with score \(String(format: "%.2f", bestScore))")
            printAlignmentDetails(result: bestResult)
            
            return bestResult
        }
        
        // Fallback if generic not available
        var bestResult: PronunciationEvalResult?
        var bestScore: Double = -1.0
        
        for (dialect, dialectPhonemes) in allDialectPhonemes {
            let result = scoreAgainstDialect(
                decodedPhonemes: decodedPhonemes,
                targetSentence: targetSentence,
                idealPhonemes: dialectPhonemes,
                dialect: dialect
            )
            
            if result.totalScore > bestScore {
                bestScore = result.totalScore
                bestResult = result
            }
        }
        
        if let result = bestResult {
            printAlignmentDetails(result: result)
        }
        
        return bestResult ?? PronunciationEvalResult(totalScore: 0, wordScores: [])
    }
    
    /// Prints detailed alignment information for debugging
    private func printAlignmentDetails(result: PronunciationEvalResult) {
        print("")
        print("📋 ALIGNED PHONEMES BY WORD:")
        print("───────────────────────────────────────────────────────────────")
        
        for wordScore in result.wordScores {
            let scoreEmoji = wordScore.score >= 0.8 ? "✅" : (wordScore.score >= 0.5 ? "⚠️" : "❌")
            print("\(scoreEmoji) \"\(wordScore.word)\" - Score: \(String(format: "%.2f", wordScore.score))")
            
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
    
    /// Score against a specific dialect's phonemes
    private func scoreAgainstDialect(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String,
        idealPhonemes: [[String]],
        dialect: EspeakManager.Dialect
    ) -> PronunciationEvalResult {
        
        // Split the sentence into individual target words
        // IMPORTANT: Must match EspeakManager's word parsing (split on whitespace only)
        // Swift's .byWords treats hyphens as separators, causing misalignment
        let targetWords = extractWordsMatchingEspeak(from: targetSentence)
        
        // Debug: verify word count matches phoneme groups
        if targetWords.count != idealPhonemes.count {
            print("⚠️ WARNING: Word count mismatch!")
            print("   targetWords (\(targetWords.count)): \(targetWords)")
            print("   idealPhonemes groups (\(idealPhonemes.count)): \(idealPhonemes.map { $0.joined(separator: "") })")
        }
        
        // Flatten and Normalize inputs
        let targetPhonemesFlat = idealPhonemes.flatMap { $0 }.map { $0.precomposedStringWithCanonicalMapping }
        let actualPhonemes = decodedPhonemes.map { $0.topPrediction.phoneme.precomposedStringWithCanonicalMapping }
        
        // Get Weighted Levenshtein edit operations
        let opcodes = levenshteinOpcodes(
            from: targetPhonemesFlat,
            to: actualPhonemes,
            similarityChecker: checkPhonemeSimilarity
        )
        
        var alignedScores: [AlignedPhoneme] = []
        var totalScore: Double = 0
        var scoreCount: Int = 0
        var gopIndex: Int = 0
        
        // Word-level scoring variables
        var wordScores: [Double] = []
        var currentWordScoreTotal: Double = 0
        var currentWordPhonemeCount: Int = 0
        var targetPhonemeIndex: Int = 0
        
        let wordLengths = idealPhonemes.map { $0.count }
        guard !wordLengths.isEmpty else {
            return PronunciationEvalResult(totalScore: 0, wordScores: [])
        }
        
        var currentWordBoundary = wordLengths[0]
        var currentWordIndex = 0
        
        /// Returns the current word being processed
        func getCurrentWord() -> String {
            guard currentWordIndex < targetWords.count else { return "" }
            return targetWords[currentWordIndex]
        }
        
        func checkWordBoundary() {
            if targetPhonemeIndex == currentWordBoundary {
                let avgScore = currentWordPhonemeCount > 0
                ? currentWordScoreTotal / Double(currentWordPhonemeCount)
                : 0.0
                wordScores.append(avgScore)
                
                currentWordScoreTotal = 0
                currentWordPhonemeCount = 0
                currentWordIndex += 1
                
                if currentWordIndex < wordLengths.count {
                    currentWordBoundary += wordLengths[currentWordIndex]
                }
            }
        }
        
        for opcode in opcodes {
            switch opcode.type {
            case .equal:
                // Perfect match
                for i in opcode.targetRange {
                    let targetPhoneme = targetPhonemesFlat[i]
                    let actualItem = decodedPhonemes[gopIndex]
                    
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
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .replace:
                // Mismatch - check if it's acceptable variant
                for i in opcode.targetRange {
                    let targetPhoneme = targetPhonemesFlat[i]
                    var phonemeScoreToAdd: Double = 0.0
                    let currentWord = getCurrentWord()
                    
                    if gopIndex < decodedPhonemes.count {
                        let actualItem = decodedPhonemes[gopIndex]
                        let actualPhoneme = actualItem.topPrediction.phoneme
                        
                        // Check if phonemes are similar/acceptable variants
                        // Use word-aware checking for function word reductions
                        if checkPhonemeSimilarityWithContext(target: targetPhoneme, actual: actualPhoneme, word: currentWord) {
                            // Check variant type for scoring
                            let isVoicingVariant = areVoicingPair(phoneme1: targetPhoneme, phoneme2: actualPhoneme)
                            let isCompoundMatch = isCompoundPhonemeMatch(target: targetPhoneme, actual: actualPhoneme)
                            let isFunctionWordReduction = isWordSpecificVariant(word: currentWord, target: targetPhoneme, actual: actualPhoneme)
                            
                            // Determine credit and note based on variant type
                            let maxCredit: Double
                            let note: String
                            
                            if isCompoundMatch {
                                maxCredit = 0.90
                                note = "Compound/dialect variant"
                            } else if isFunctionWordReduction {
                                maxCredit = 0.85
                                note = "Function word reduction"
                            } else if isVoicingVariant {
                                maxCredit = 0.85
                                note = "Voicing variant"
                            } else {
                                maxCredit = 0.70
                                note = "Similar variant"
                            }
                            
                            phonemeScoreToAdd = min(actualItem.score, maxCredit)
                            
                            alignedScores.append(AlignedPhoneme(
                                type: .match,
                                target: targetPhoneme,
                                actual: actualPhoneme,
                                score: phonemeScoreToAdd,
                                note: note
                            ))
                            totalScore += phonemeScoreToAdd
                            
                        } else {
                            // Real mispronunciation
                            phonemeScoreToAdd = 0.0
                            
                            alignedScores.append(AlignedPhoneme(
                                type: .replace,
                                target: targetPhoneme,
                                actual: actualPhoneme,
                                score: 0.0,
                                note: "Mispronounced (said '\(actualPhoneme)')"
                            ))
                        }
                        
                        scoreCount += 1
                        gopIndex += 1
                        currentWordScoreTotal += phonemeScoreToAdd
                        currentWordPhonemeCount += 1
                        
                    } else {
                        // Ran out of actual phonemes
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
                // Missing phoneme
                for i in opcode.targetRange {
                    let targetPhoneme = targetPhonemesFlat[i]
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
                    
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .insert:
                // Extra phoneme - don't penalize
                for _ in opcode.actualRange {
                    let actualItem = decodedPhonemes[gopIndex]
                    alignedScores.append(AlignedPhoneme(
                        type: .insert,
                        target: nil,
                        actual: actualItem.topPrediction.phoneme,
                        score: actualItem.score,
                        note: "Extra sound (ignored)"
                    ))
                    gopIndex += 1
                }
            }
        }
        
        let finalTotalScore = scoreCount > 0 ? totalScore / Double(scoreCount) : 0.0
        
        // Split with Greedy logic
        let groupedAlignedPhonemes = splitAlignedPhonemesByWord(alignedPhonemes: alignedScores, guide: idealPhonemes)
        
        let wordScoreResults: [WordScore] = zip(targetWords, zip(wordScores, groupedAlignedPhonemes)).map { word, data in
            WordScore(word: word, score: data.0, alignedPhonemes: data.1)
        }
        
        return PronunciationEvalResult(
            totalScore: finalTotalScore,
            wordScores: wordScoreResults
        )
    }
    
    // MARK: - Helper functions
    
    /// Checks if two phonemes match via compound phoneme equivalence
    private func isCompoundPhonemeMatch(target: String, actual: String) -> Bool {
        if let equivalents = compoundPhonemeEquivalents[target], equivalents.contains(actual) {
            return true
        }
        if let equivalents = compoundPhonemeEquivalents[actual], equivalents.contains(target) {
            return true
        }
        
        // Also check stripped versions
        let cleanTarget = stripModifiers(target)
        let cleanActual = stripModifiers(actual)
        
        if let equivalents = compoundPhonemeEquivalents[cleanTarget], equivalents.contains(cleanActual) {
            return true
        }
        if let equivalents = compoundPhonemeEquivalents[cleanActual], equivalents.contains(cleanTarget) {
            return true
        }
        
        return false
    }
    
    /// Determines if a phoneme is "important" for pronunciation scoring
    private func isImportantPhoneme(_ phoneme: String) -> Bool {
        let unimportantPhonemes: Set<String> = [
            "ə",    // Schwa
            "ɚ",    // R-colored schwa
            "ᵻ",    // Barred i
            "ɪ",    // Can be reduced
            "ʔ",    // Glottal stop
        ]
        
        if unimportantPhonemes.contains(phoneme) {
            return false
        }
        
        return true
    }
    
    /// Extracts words from text using the same logic as EspeakManager
    /// This ensures word boundaries match between target words and ideal phoneme groups
    ///
    /// Key difference from Swift's .byWords:
    /// - This splits on WHITESPACE ONLY
    /// - Swift's .byWords treats hyphens, punctuation as word boundaries
    /// - "in-person" → this: ["in-person"], .byWords: ["in", "person"]
    private func extractWordsMatchingEspeak(from text: String) -> [String] {
        // First, clean punctuation the same way EspeakManager does
        let punctuationToStrip = CharacterSet.punctuationCharacters
            .subtracting(CharacterSet(charactersIn: "'-"))  // Keep apostrophes and hyphens
        
        var cleaned = ""
        for char in text {
            if char.unicodeScalars.allSatisfy({ punctuationToStrip.contains($0) }) {
                continue
            }
            cleaned.append(char)
        }
        
        // Split on whitespace only
        var words: [String] = []
        var currentWord = ""
        
        for char in cleaned {
            if char.isWhitespace {
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = ""
                }
            } else {
                currentWord.append(char)
            }
        }
        
        if !currentWord.isEmpty {
            words.append(currentWord)
        }
        
        return words
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

// MARK: - Robust Levenshtein

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
    
    // Costs tuned so similar_replace is always preferred over delete + insert
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
    
    // Backtracking - prefer replace over insert/delete
    var operations: [EditOperation] = []
    var i = m
    var j = n
    
    while i > 0 || j > 0 {
        let currentVal = dp[i][j]
        
        // Check match/replace FIRST
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
        
        // Delete
        if i > 0 && currentVal == dp[i-1][j] + deleteCost {
            operations.insert(EditOperation(type: .delete, targetRange: (i-1)..<i, actualRange: j..<j), at: 0)
            i -= 1
            continue
        }
        
        // Insert
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
