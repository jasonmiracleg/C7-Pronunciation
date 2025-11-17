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
    
    private init() { }
    
    /// Aligns and scores phonemes using Levenshtein distance
    /// - Parameters:
    ///   - decodedPhonemes: Array of detected phonemes from the model (as PhonemePrediction objects)
    ///   - idealPhonemes: Array of arrays representing target phonemes grouped by word
    ///   - words: Array of target words (optional, for word-level scoring)
    /// - Returns: PronunciationResult containing aligned scores, total score, and word scores
    func alignAndScore(
        decodedPhonemes: [PhonemePrediction],
        idealPhonemes: [[String]],
        targetSentence: String,
        words: [String]? = nil
    ) -> PronunciationEvalResult {
        // Split the sentence into individual target words
        var targetWords: [String] = []
        targetSentence.enumerateSubstrings(in: targetSentence.startIndex..., options: .byWords) { (substring, _, _, _) in
            if let word = substring {
                targetWords.append(word)
            }
        }
        
        // Flatten the ideal phonemes for alignment
        let targetPhonemesFlat = idealPhonemes.flatMap { $0 }
        let actualPhonemes = decodedPhonemes.map { $0.topPrediction.phoneme }
        
        // Get Levenshtein edit operations
        let opcodes = levenshteinOpcodes(from: targetPhonemesFlat, to: actualPhonemes)
        
        var alignedScores: [AlignedPhoneme] = []
        var totalScore: Double = 0
        var scoreCount: Int = 0
        var gopIndex: Int = 0
        
        // Word-level scoring variables
        var wordScores: [Double] = []
        var currentWordScoreTotal: Double = 0
        var currentWordPhonemeCount: Int = 0
        var targetPhonemeIndex: Int = 0
        
        // Get word lengths (phoneme count per word)
        let wordLengths = idealPhonemes.map { $0.count }
        guard !wordLengths.isEmpty else {
            return PronunciationEvalResult(totalScore: 0, wordScores: [])
        }
        
        var currentWordBoundary = wordLengths[0]
        var currentWordIndex = 0
        
        // Helper function to check word boundaries
        func checkWordBoundary() {
            if targetPhonemeIndex == currentWordBoundary {
                let avgScore = currentWordPhonemeCount > 0
                ? currentWordScoreTotal / Double(currentWordPhonemeCount)
                : 0.0
                wordScores.append(avgScore)
                
                // Reset for next word
                currentWordScoreTotal = 0
                currentWordPhonemeCount = 0
                currentWordIndex += 1
                
                // Set new boundary if there are more words
                if currentWordIndex < wordLengths.count {
                    currentWordBoundary += wordLengths[currentWordIndex]
                }
            }
        }
        
        // Process each edit operation
        for opcode in opcodes {
            switch opcode.type {
            case .equal:
                // Perfect match - phonemes are the same
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
                    
                    // Word score tracking
                    currentWordScoreTotal += actualItem.score
                    currentWordPhonemeCount += 1
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .replace:
                // Phoneme mismatch - check if it's in top-3 (forgiveness)
                for i in opcode.targetRange {
                    let targetPhoneme = targetPhonemesFlat[i]
                    var phonemeScoreToAdd: Double = 0.0
                    
                    if gopIndex < decodedPhonemes.count {
                        let actualItem = decodedPhonemes[gopIndex]
                        
                        var isForgiven = false
                        var forgivenScore: Double = 0.0
                        
                        // Check if target phoneme is in top-3 predictions
                        for topPhoneme in actualItem.top3 {
                            if topPhoneme.phoneme == targetPhoneme {
                                isForgiven = true
                                forgivenScore = topPhoneme.score
                                break
                            }
                        }
                        
                        if isForgiven {
                            phonemeScoreToAdd = forgivenScore
                            alignedScores.append(AlignedPhoneme(
                                type: .match,
                                target: targetPhoneme,
                                actual: actualItem.topPrediction.phoneme,
                                score: forgivenScore,
                                note: "Forgiven mismatch (said '\(actualItem.topPrediction.phoneme)')"
                            ))
                            totalScore += forgivenScore
                        } else {
                            alignedScores.append(AlignedPhoneme(
                                type: .replace,
                                target: targetPhoneme,
                                actual: actualItem.topPrediction.phoneme,
                                score: 0.0,
                                note: "Said '\(actualItem.topPrediction.phoneme)'"
                            ))
                        }
                        
                        gopIndex += 1
                    } else {
                        // No more actual phonemes - it's a deletion
                        alignedScores.append(AlignedPhoneme(
                            type: .delete,
                            target: targetPhoneme,
                            actual: nil,
                            score: 0.0,
                            note: nil
                        ))
                    }
                    
                    scoreCount += 1
                    
                    // Word score tracking
                    currentWordScoreTotal += phonemeScoreToAdd
                    currentWordPhonemeCount += 1
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .delete:
                // Missing phoneme - user didn't say it
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
                    
                    // Word score tracking
                    currentWordScoreTotal += 0.0
                    currentWordPhonemeCount += 1
                    targetPhonemeIndex += 1
                    checkWordBoundary()
                }
                
            case .insert:
                // Extra phoneme - user added something
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
                    // Note: Insertions do NOT affect word score or target index
                }
            }
        }
        
        let finalTotalScore = scoreCount > 0 ? totalScore / Double(scoreCount) : 0.0
        
        // Split aligned phonemes by word
        let groupedAlignedPhonemes = splitAlignedPhonemesByWord(alignedPhonemes: alignedScores, guide: idealPhonemes)
        
        print("Unalligned Phonemes:")
        print(alignedScores.compactMap(\.actual).joined(separator: ", "))
        print("Guide:")
        print(idealPhonemes)
        print("Alignment results:")
        for group in groupedAlignedPhonemes {
            print(group.compactMap(\.actual).joined(separator: " "))
        }
        
        // Create word-level scores with word names
        let wordScoreResults: [WordScore]
        wordScoreResults = wordScores.enumerated().map { WordScore(word: targetWords[$0.offset], alignedPhonemes: groupedAlignedPhonemes[$0.offset]) }
        
        return PronunciationEvalResult(
            totalScore: finalTotalScore,
            wordScores: wordScoreResults,
        )
    }
}

// MARK: - Levenshtein Distance Implementation

/// Represents an edit operation type
enum EditType {
    case equal
    case replace
    case delete
    case insert
}

/// Represents an edit operation with ranges
struct EditOperation {
    let type: EditType
    let targetRange: Range<Int>
    let actualRange: Range<Int>
}

/// Computes Levenshtein edit operations (opcodes) between two sequences
/// - Parameters:
///   - source: The source sequence (target phonemes)
///   - target: The target sequence (actual phonemes)
/// - Returns: Array of EditOperation representing the alignment
func levenshteinOpcodes(from source: [String], to target: [String]) -> [EditOperation] {
    let m = source.count
    let n = target.count
    
    // Create the distance matrix
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    
    // Initialize first row and column
    for i in 0...m {
        dp[i][0] = i
    }
    for j in 0...n {
        dp[0][j] = j
    }
    
    // Fill the matrix
    for i in 1...m {
        for j in 1...n {
            if source[i - 1] == target[j - 1] {
                dp[i][j] = dp[i - 1][j - 1]
            } else {
                dp[i][j] = min(
                    dp[i - 1][j] + 1,      // deletion
                    dp[i][j - 1] + 1,      // insertion
                    dp[i - 1][j - 1] + 1   // substitution
                )
            }
        }
    }
    
    // Backtrack to get operations
    var operations: [EditOperation] = []
    var i = m
    var j = n
    
    while i > 0 || j > 0 {
        if i > 0 && j > 0 && source[i - 1] == target[j - 1] {
            // Equal - find the start of the equal sequence
            var equalStart = (i - 1, j - 1)
            while equalStart.0 > 0 && equalStart.1 > 0 &&
                    source[equalStart.0 - 1] == target[equalStart.1 - 1] {
                equalStart = (equalStart.0 - 1, equalStart.1 - 1)
            }
            operations.insert(EditOperation(
                type: .equal,
                targetRange: equalStart.0..<i,
                actualRange: equalStart.1..<j
            ), at: 0)
            i = equalStart.0
            j = equalStart.1
        } else if i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + 1 {
            // Replace
            operations.insert(EditOperation(
                type: .replace,
                targetRange: (i - 1)..<i,
                actualRange: (j - 1)..<j
            ), at: 0)
            i -= 1
            j -= 1
        } else if i > 0 && dp[i][j] == dp[i - 1][j] + 1 {
            // Delete
            operations.insert(EditOperation(
                type: .delete,
                targetRange: (i - 1)..<i,
                actualRange: j..<j
            ), at: 0)
            i -= 1
        } else if j > 0 && dp[i][j] == dp[i][j - 1] + 1 {
            // Insert
            operations.insert(EditOperation(
                type: .insert,
                targetRange: i..<i,
                actualRange: (j - 1)..<j
            ), at: 0)
            j -= 1
        }
    }
    
    // Merge consecutive operations of the same type
    return mergeConsecutiveOperations(operations)
}

/// Merges consecutive operations of the same type for cleaner output
func mergeConsecutiveOperations(_ operations: [EditOperation]) -> [EditOperation] {
    guard !operations.isEmpty else { return [] }
    
    var merged: [EditOperation] = []
    var current = operations[0]
    
    for i in 1..<operations.count {
        let next = operations[i]
        
        if current.type == next.type &&
            current.targetRange.upperBound == next.targetRange.lowerBound &&
            current.actualRange.upperBound == next.actualRange.lowerBound {
            // Merge
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

// MARK: -- Helper functions
/// Splits aligned phonemes per word based on the known ideal phonemes list
private func splitAlignedPhonemesByWord(alignedPhonemes: [AlignedPhoneme], guide: [[String]]) -> [[AlignedPhoneme]] {
    
    var result: [[AlignedPhoneme]] = []
    // This is our cursor for the flat alignedPhonemes list
    var alignedIndex = 0
    
    // Loop through each target word in the guide (e.g., ["ɡ", "ʊ", "d"])
    for targetWord in guide {
        
        // This is the number of *target* phonemes we expect for this word.
        let expectedTargetCount = targetWord.count
        
        // This will store all aligned phonemes for the current word
        var currentWordChunk: [AlignedPhoneme] = []
        
        // This counts how many of the word's target phonemes we've seen
        var consumedTargetCount = 0
        
        // Keep consuming from alignedPhonemes as long as...
        // 1. We haven't run out of aligned phonemes
        // 2. We haven't found all the target phonemes for this word yet
        while alignedIndex < alignedPhonemes.count && consumedTargetCount < expectedTargetCount {
            
            // Get the next aligned phoneme
            let currentAlignedPhoneme = alignedPhonemes[alignedIndex]
            currentWordChunk.append(currentAlignedPhoneme)
            alignedIndex += 1 // Always advance the main cursor

            // If the phoneme was a .match, .replace, or .delete,
            // it corresponds to one of the target phonemes.
            // If it was an .insert, it's an *extra* sound and
            // doesn't count against the target total.
            //
            if currentAlignedPhoneme.type != .insert {
                consumedTargetCount += 1
            }
        }
        
        // Add the completed chunk for this word to the result
        if !currentWordChunk.isEmpty {
            result.append(currentWordChunk)
        }
    }
    
    // After looping through the guide, check if there are any
    // leftover phonemes (e.g., extra sounds at the very end).
    if alignedIndex < alignedPhonemes.count {
        result.append(Array(alignedPhonemes[alignedIndex...]))
    }
    
    return result
}
