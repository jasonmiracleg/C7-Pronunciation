//
//  PronunciationScorer.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 15/11/25.
//


import Foundation

// MARK: - Pronunciation Scorer Singleton

public class PronunciationScorer {
    public static let shared = PronunciationScorer()
    
    private let espeakManager = EspeakManager.shared
    
    private init() { }
    
    // MARK: - Phonetic Similarity Data (Stricter)
//    private let phonemeSimilarityGroups: [Set<String>] = [
//        ["a", "æ", "ɑ", "ɒ"],
//        ["ʌ", "ɐ", "ə"],
//        ["i", "y", "j"],
//        ["ɪ"],
//        ["u", "w"],
//        ["ʊ"],
//        ["e", "ɛ", "3", "eɪ"],
//        ["o", "ɔ", "oʊ", "əʊ"],
//        ["r", "ɹ", "ɾ", "ɝ", "ɚ"],
//        ["l", "ɫ"]
//    ]
    
    // MARK: - Phonetic Similarity Data (Lenient)
    private let phonemeSimilarityGroups: [Set<String>] = [
        ["a", "æ", "ɑ", "ɒ", "ɐ", "ʌ"], // A-like vowels
        ["e", "ɛ", "ɜ", "ə"],           // E-like vowels + Schwa
        ["i", "ɪ", "y", "j"],           // I-like vowels
        ["o", "ɔ"],                     // O-like vowels
        ["u", "ʊ", "w"],                // U-like vowels / glides
        ["r", "ɹ", "ɾ"],                // Rhotics
        ["l", "ɫ"]                      // Laterals
    ]
    
    /// Checks if two phonemes are similar, ignoring diacritics/length markers if needed
    private func checkPhonemeSimilarity(target: String, actual: String) -> Bool {
        // 1. Exact Match (Normalized)
        if target.precomposedStringWithCanonicalMapping == actual.precomposedStringWithCanonicalMapping { return true }
        
        // 2. Group Lookup
        for group in phonemeSimilarityGroups {
            if group.contains(target) && group.contains(actual) {
                return true
            }
        }
        
        // 3. Strip Modifiers (e.g. "oː" -> "o") and check again
        let cleanTarget = target.replacingOccurrences(of: "[ːˌˈ]", with: "", options: .regularExpression)
        let cleanActual = actual.replacingOccurrences(of: "[ːˌˈ]", with: "", options: .regularExpression)
        
        if cleanTarget == cleanActual { return true }
        
        // 4. Check groups with stripped versions
        for group in phonemeSimilarityGroups {
            if group.contains(cleanTarget) && group.contains(cleanActual) {
                return true
            }
        }
        
        return false
    }
    
    /// Aligns and scores phonemes using Levenshtein distance
    func alignAndScore(
        decodedPhonemes: [PhonemePrediction],
        targetSentence: String
    ) -> PronunciationEvalResult {
        // Get ideal phonemes for sentence from espeak
        let idealPhonemes = espeakManager.getPhonemes(for: targetSentence)
        
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
        
        print("🔍 Word Lengths: \(wordLengths)")
        
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
                        
                        // 1. Check Phonetic Similarity
                        if checkPhonemeSimilarity(target: targetPhoneme, actual: actualPhoneme) {
                            // Similar: Use actual score but cap at 0.9 to differentiate from perfect
                            phonemeScoreToAdd = min(actualItem.score, 0.75)
                            
                            alignedScores.append(AlignedPhoneme(
                                type: .match,
                                target: targetPhoneme,
                                actual: actualPhoneme,
                                score: phonemeScoreToAdd,
                                note: "Similar sound (said '\(actualPhoneme)')"
                            ))
                            totalScore += phonemeScoreToAdd
                            
                        } else {
                            // 2. Check Forgiveness (Top 3)
                            var isForgiven = false
                            var forgivenScore: Double = 0.0
                            
                            for topPhoneme in actualItem.top3 {
                                if checkPhonemeSimilarity(target: targetPhoneme, actual: topPhoneme.phoneme) {
                                    isForgiven = true
                                    forgivenScore = topPhoneme.score
                                    break
                                }
                            }
                            
                            if isForgiven {
                                // Strict Forgiveness: Must have at least 40% confidence
                                phonemeScoreToAdd = max(forgivenScore, 0.30)
                                
                                alignedScores.append(AlignedPhoneme(
                                    type: .match,
                                    target: targetPhoneme,
                                    actual: actualPhoneme,
                                    score: phonemeScoreToAdd,
                                    note: "Forgiven mismatch (said '\(actualPhoneme)')"
                                ))
                                totalScore += phonemeScoreToAdd
                            } else {
                                // 3. Wrong
                                alignedScores.append(AlignedPhoneme(
                                    type: .replace,
                                    target: targetPhoneme,
                                    actual: actualPhoneme,
                                    score: 0.0,
                                    note: "Said '\(actualPhoneme)'"
                                ))
                            }
                        }
                        gopIndex += 1
                    } else {
                        // Ran out of actual phonemes (Deletion)
                        alignedScores.append(AlignedPhoneme(
                            type: .delete,
                            target: targetPhoneme,
                            actual: nil,
                            score: 0.0,
                            note: nil
                        ))
                    }
                    
                    scoreCount += 1
                    currentWordScoreTotal += phonemeScoreToAdd
                    currentWordPhonemeCount += 1
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
                    currentWordScoreTotal += 0.0
                    currentWordPhonemeCount += 1
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
    // Replace cost is dynamic: 1 if similar, 4 if different.
    // High diff cost (4) ensures we prefer Insert(1)+Delete(2)=3 over a bad replacement.
    
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    
    for i in 0...m { dp[i][0] = i * deleteCost }
    for j in 0...n { dp[0][j] = j * insertCost }
    
    for i in 1...m {
        for j in 1...n {
            let s = source[i-1]
            let t = target[j-1]
            
            if s == t {
                dp[i][j] = dp[i-1][j-1] // Cost 0
            } else {
                let isSimilar = similarityChecker(s, t)
                let replaceCost = isSimilar ? 1 : 4
                
                dp[i][j] = min(
                    dp[i-1][j] + deleteCost,      // Delete
                    dp[i][j-1] + insertCost,      // Insert
                    dp[i-1][j-1] + replaceCost    // Replace
                )
            }
        }
    }
    
    // BACKTRACKING (Modified for sequential preference)
    var operations: [EditOperation] = []
    var i = m
    var j = n
    
    while i > 0 || j > 0 {
        // Determine costs again to see which path is valid
        let currentVal = dp[i][j]
        
        // CHECK 1: Insert (Prioritize skipping extra actual sounds)
        // We check this BEFORE Match to handle "Repeated Sound" ties.
        // If Actual has "L L" and Target has "L", checking Insert first
        // ensures we consume the second "L" as an insert, matching the first "L".
        if j > 0 && currentVal == dp[i][j-1] + insertCost {
            operations.insert(EditOperation(type: .insert, targetRange: i..<i, actualRange: (j-1)..<j), at: 0)
            j -= 1
            continue
        }
        
        // CHECK 2: Delete (Prioritize skipping missed target sounds)
        if i > 0 && currentVal == dp[i-1][j] + deleteCost {
            operations.insert(EditOperation(type: .delete, targetRange: (i-1)..<i, actualRange: j..<j), at: 0)
            i -= 1
            continue
        }
        
        // CHECK 3: Match / Replace
        // Only take this path if Ins/Del were not optimal or not chosen.
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
        
        // Fallback (should rarely happen given logic)
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
