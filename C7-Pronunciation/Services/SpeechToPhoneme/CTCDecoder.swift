//
//  CTCDecoder.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//


//
//  CTCDecoder.swift
//  CTC (Connectionist Temporal Classification) decoder
//

import Foundation

struct CTCDecoder {
    private let vocabulary: PhonemeVocabulary
    
    init(vocabulary: PhonemeVocabulary) {
        self.vocabulary = vocabulary
    }
    
    /// Decode CTC output using greedy decoding
    /// - Parameter logits: Model output logits [timeSteps, vocabSize]
    /// - Returns: Decoded phoneme string
    func decode(logits: [[Float]]) -> String {
        // Step 1: Get predicted IDs (argmax along vocab dimension)
        let predictedIds = logits.map { timeStep -> Int in
            guard let maxIndex = timeStep.enumerated().max(by: { $0.element < $1.element })?.offset else {
                return PhonemeVocabulary.blankId
            }
            return maxIndex
        }
        
        // Step 2: CTC collapse - remove blanks and consecutive duplicates
        let collapsedIds = collapseRepeats(predictedIds)
        
        // Step 3: Convert IDs to phoneme tokens
        let phonemes = vocabulary.tokens(for: collapsedIds)
        
        // Step 4: Join with spaces
        return phonemes.joined(separator: " ")
    }
    
    /// CTC collapse: remove blank tokens and consecutive duplicates
    private func collapseRepeats(_ ids: [Int]) -> [Int] {
        var result: [Int] = []
        var previousId = PhonemeVocabulary.blankId
        
        for id in ids {
            // Skip blank tokens
            if id == PhonemeVocabulary.blankId {
                previousId = id
                continue
            }
            
            // Skip if same as previous (repeated)
            if id != previousId {
                result.append(id)
            }
            
            previousId = id
        }
        
        return result
    }
    
    /// Decode multiple chunks and concatenate results
    /// - Parameter logitsArray: Array of logits from multiple chunks
    /// - Returns: Concatenated phoneme string
    
    // DEBUG: TEST OUTPUTTING PhonemePrediction Objects. OLD FUNC BELOW:
    // func decodeChunks(_ logitsArray: [[[Float]]]) -> String {
    func decodeChunks(_ logitsArray: [[[Float]]]) -> [[PhonemePrediction]] {
//        let decodedChunks = logitsArray.map { decode(logits: $0) }
        let decodedChunks = logitsArray.map { decodeWithConfidence(logits: $0) }
        
        return decodedChunks
            .filter { !$0.isEmpty }
//            .joined(separator: " ")
    }
    
    func decodeWithConfidence(logits: [[Float]]) -> [PhonemePrediction] {
        var results: [PhonemePrediction] = []
        
        for timeStep in logits {
            // Get top 3 predictions
            let top3 = timeStep.enumerated()
                .sorted { $0.element > $1.element }
                .prefix(4)
            
            let topIndex = top3[0].offset
            let topValue = top3[0].element
            
            // Convert logits to probabilities using softmax
            let maxLogit = timeStep.max() ?? 0
            let expSum = timeStep.reduce(0) { $0 + exp($1 - maxLogit) }
            let topProb = exp(topValue - maxLogit) / expSum
            
            let alternatives = Array(top3.dropFirst()).map { idx, val in
                let prob = exp(val - maxLogit) / expSum
                return PhonemeEvaluationScore(phoneme: vocabulary.token(for: idx) ?? "", score: Double(prob))
            }
            
            if topIndex != 0 { // Skip blank
                let topScore = Double(topProb)
                let result = PhonemePrediction(
                    topPrediction: PhonemeEvaluationScore(phoneme: vocabulary.token(for: topIndex) ?? "", score: topScore),
                    score: topScore,
                    top3: alternatives
                )
                results.append(result)
            }
        }
        
        return results
    }
}
