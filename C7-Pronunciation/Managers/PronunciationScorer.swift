//
//  PronunciationScorer.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//  Improved version with multi-dialect support
//

import Foundation

// MARK: - Pronunciation Scorer Singleton

public class PronunciationScorer {
    public static let shared = PronunciationScorer()
    
    private let espeakManager = EspeakManager.shared
    
    private init() { }
    
    // MARK: - Phonetic Similarity Data
    
    /// Dialect-specific phoneme mappings for cross-dialect acceptance
    private let dialectPhonemeEquivalents: [String: Set<String>] = [
        // R-colored vowels (US) vs non-rhotic (UK)
        "ɝ": ["ɜː", "ɜ"],      // US "bird" /bɝd/ vs UK "bird" /bɜːd/
        "ɚ": ["ə"],            // US "better" /ˈbɛɾɚ/ vs UK /ˈbɛtə/
        "ɑr": ["ɑː"],          // US "car" vs UK "car"
        
        // LOT-CLOTH vowel (US /ɑ/ vs UK /ɒ/)
        "ɑ": ["ɒ", "ɔ"],
        "ɒ": ["ɑ", "ɔ"],
        
        // GOAT diphthong (US /oʊ/ vs UK /əʊ/)
        "oʊ": ["əʊ", "o"],
        "əʊ": ["oʊ", "o"],
        
        // T-flapping (US /ɾ/ vs UK /t/)
        "ɾ": ["t", "d"],
        "t": ["ɾ"],
        
        // Dark L variations
        "l": ["ɫ"],
        "ɫ": ["l"],
        
        // STRUT vowel variations
        "ʌ": ["ɐ", "ə"],
        "ɐ": ["ʌ", "ə"],
    ]
    
    /// Core phonetic similarity groups - strict grouping
    private let phonemeSimilarityGroups: [Set<String>] = [
        // Keep only very similar vowels together
        ["a", "æ"],
        ["ɑ", "ɒ"],
        
        // Schwa variants
        ["ə", "ɐ"],
        
        // I-like vowels - separate short/long
        ["i", "iː"],
        ["ɪ"],
        
        // U-like vowels - separate short/long
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
    
    /// Checks if two phonemes are similar, considering dialect variations
    private func checkPhonemeSimilarity(target: String, actual: String) -> Bool {
        // 1. Exact Match (Normalized)
        if target.precomposedStringWithCanonicalMapping == actual.precomposedStringWithCanonicalMapping {
            return true
        }
        
        // 2. Check dialect equivalents (NEW!)
        if let equivalents = dialectPhonemeEquivalents[target], equivalents.contains(actual) {
            return true
        }
        if let equivalents = dialectPhonemeEquivalents[actual], equivalents.contains(target) {
            return true
        }
        
        // 3. Group Lookup
        for group in phonemeSimilarityGroups {
            if group.contains(target) && group.contains(actual) {
                return true
            }
        }
        
        // 4. Strip Modifiers (e.g. "oː" -> "o") and check again
        let cleanTarget = target.replacingOccurrences(of: "[ːˌˈ]", with: "", options: .regularExpression)
        let cleanActual = actual.replacingOccurrences(of: "[ːˌˈ]", with: "", options: .regularExpression)
        
        if cleanTarget == cleanActual { return true }
        
        // 5. Check groups with stripped versions
        for group in phonemeSimilarityGroups {
            if group.contains(cleanTarget) && group.contains(cleanActual) {
                return true
            }
        }
        
        // 6. Check dialect equivalents with stripped versions
        if let equivalents = dialectPhonemeEquivalents[cleanTarget], equivalents.contains(cleanActual) {
            return true
        }
        if let equivalents = dialectPhonemeEquivalents[cleanActual], equivalents.contains(cleanTarget) {
            return true
        }
        
        return false
    }
    
    // MARK: - Scoring Methods
    
    /// Default scoring method - uses multi-dialect support by default for best accuracy.
    /// Accepts US, UK, and generic English pronunciations.
    func alignAndScore(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String
    ) -> PronunciationEvalResult {
        // Use multi-dialect scoring by default
        return alignAndScoreMultiDialect(
            decodedPhonemes: decodedPhonemes,
            targetSentence: targetSentence
        )
    }
    
    /// Multi-dialect scoring - tries all three English dialects and returns best match.
    /// This is now called by default from alignAndScore().
    private func alignAndScoreMultiDialect(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String
    ) -> PronunciationEvalResult {
        
        // Get phonemes for all three dialects
        let allDialectPhonemes = espeakManager.getPhonemesForAllDialects(for: targetSentence)
        
        // Debug: Print input phonemes (what user said)
        print("═══════════════════════════════════════════════════════════════")
        print("🎤 TARGET SENTENCE: \"\(targetSentence)\"")
        print("═══════════════════════════════════════════════════════════════")
        print("")
        print("📥 USER INPUT (Decoded Phonemes - Unaligned):")
        let userPhonemes = decodedPhonemes.map { $0.topPrediction.phoneme }
        print("   \(userPhonemes.joined(separator: " "))")
        print("")
        
        // Debug: Print ideal phonemes for each dialect
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
            
            print("📊 Dialect \(dialect.rawValue): Score = \(String(format: "%.2f", result.totalScore))")
            
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
        var targetWords: [String] = []
        targetSentence.enumerateSubstrings(in: targetSentence.startIndex..., options: .byWords) { (substring, _, _, _) in
            if let word = substring {
                targetWords.append(word)
            }
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
                // Mismatch (could be similar or wrong)
                for i in opcode.targetRange {
                    let targetPhoneme = targetPhonemesFlat[i]
                    var phonemeScoreToAdd: Double = 0.0
                    
                    if gopIndex < decodedPhonemes.count {
                        let actualItem = decodedPhonemes[gopIndex]
                        let actualPhoneme = actualItem.topPrediction.phoneme
                        
                        // 1. Check Phonetic Similarity (now includes dialect variations!)
                        if checkPhonemeSimilarity(target: targetPhoneme, actual: actualPhoneme) {
                            // Similar: Use actual score but cap lower to be stricter
                            phonemeScoreToAdd = min(actualItem.score, 0.70)
                            
                            alignedScores.append(AlignedPhoneme(
                                type: .match,
                                target: targetPhoneme,
                                actual: actualPhoneme,
                                score: phonemeScoreToAdd,
                                note: "Similar/dialect variant"
                            ))
                            totalScore += phonemeScoreToAdd
                            
                        } else {
                            // 2. Wrong phoneme - no forgiveness
                            phonemeScoreToAdd = 0.0
                            
                            alignedScores.append(AlignedPhoneme(
                                type: .replace,
                                target: targetPhoneme,
                                actual: actualPhoneme,
                                score: 0.0,
                                note: "Wrong (said '\(actualPhoneme)')"
                            ))
                        }
                        
                        scoreCount += 1
                        gopIndex += 1
                        currentWordScoreTotal += phonemeScoreToAdd
                        currentWordPhonemeCount += 1
                        
                    } else {
                        // Missing phoneme
                        alignedScores.append(AlignedPhoneme(
                            type: .delete,
                            target: targetPhoneme,
                            actual: nil,
                            score: 0.0,
                            note: nil
                        ))
                        scoreCount += 1
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
                        note: nil
                    ))
                    scoreCount += 1
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .insert:
                // Extra phoneme
                for _ in opcode.actualRange {
                    let actualItem = decodedPhonemes[gopIndex]
                    alignedScores.append(AlignedPhoneme(
                        type: .insert,
                        target: nil,
                        actual: actualItem.topPrediction.phoneme,
                        score: actualItem.score,
                        note: nil
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
    
    private func splitAlignedPhonemesByWord(alignedPhonemes: [AlignedPhoneme], guide: [[String]]) -> [[AlignedPhoneme]] {
        var result: [[AlignedPhoneme]] = []
        var alignedIndex = 0
        
        for targetWord in guide {
            let expectedTargetCount = targetWord.count
            var currentWordChunk: [AlignedPhoneme] = []
            var consumedTargetCount = 0
            
            // 1. Consume Targets
            while alignedIndex < alignedPhonemes.count && consumedTargetCount < expectedTargetCount {
                let current = alignedPhonemes[alignedIndex]
                currentWordChunk.append(current)
                alignedIndex += 1
                if current.type != .insert {
                    consumedTargetCount += 1
                }
            }
            
            // 2. Consume Trailing Inserts (Attach to CURRENT word, not next)
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
        
        // Attach any remaining tail to the last word
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
    
    // Safety for empty inputs
    if m == 0 && n == 0 { return [] }
    if m == 0 { return [EditOperation(type: .insert, targetRange: 0..<0, actualRange: 0..<n)] }
    if n == 0 { return [EditOperation(type: .delete, targetRange: 0..<m, actualRange: 0..<0)] }
    
    let insertCost = 1
    let deleteCost = 2
    
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
    
    // BACKTRACKING
    var operations: [EditOperation] = []
    var i = m
    var j = n
    
    while i > 0 || j > 0 {
        let currentVal = dp[i][j]
        
        // CHECK 1: Insert
        if j > 0 && currentVal == dp[i][j-1] + insertCost {
            operations.insert(EditOperation(type: .insert, targetRange: i..<i, actualRange: (j-1)..<j), at: 0)
            j -= 1
            continue
        }
        
        // CHECK 2: Delete
        if i > 0 && currentVal == dp[i-1][j] + deleteCost {
            operations.insert(EditOperation(type: .delete, targetRange: (i-1)..<i, actualRange: j..<j), at: 0)
            i -= 1
            continue
        }
        
        // CHECK 3: Match / Replace
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
