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
    func decodeChunks(_ logitsArray: [[[Float]]]) -> String {
        let decodedChunks = logitsArray.map { decode(logits: $0) }
        
        // Join chunks with space separator
        // Note: This is a simple concatenation. For better results,
        // you might want to implement overlap handling or beam search.
//        print(decodedChunks) = ["ɡ ə d iː v n ɪ ŋ ɛ v ɹ i w ʌ n"]
        return decodedChunks
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
