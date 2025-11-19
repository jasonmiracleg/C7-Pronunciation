//
//  Wav2VecManager.swift
//  PronunciationScorer
//
//  Created by Savio Enoson on 19/11/25.
//

import Foundation
import CoreML

/// Responsible strictly for ML Model interaction and decoding logic.
public class Wav2VecManager {
    
    private var model: MLModel?
    private var vocabulary: PhonemeVocabulary?
    private var decoder: CTCDecoder?
    
    private let modelName = "Wav2Vec2_Phoneme"
    private let vocabFilename = "vocab"
    private let chunkSize = 80000 // 5 seconds at 16kHz
    
    init() {
        // Changed: Wrap initialization in a detached Task so it doesn't block the thread
        Task.detached(priority: .userInitiated) {
            await self.initialize()
        }
    }
    
    private func initialize() {
        do {
                    // 1. Load Vocabulary
                    guard let vocab = PhonemeVocabulary(jsonFilename: vocabFilename) else {
                        print("✗ Failed to load vocabulary")
                        return
                    }
                    self.vocabulary = vocab
                    
                    // 2. Init Decoder
                    self.decoder = CTCDecoder(vocabulary: vocab)
                    
                    // 3. Load CoreML Model
                    guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")
                            ?? Bundle.main.url(forResource: modelName, withExtension: "mlpackage") else {
                        print("✗ Model not found: \(modelName)")
                        return
                    }
                    
                    let config = MLModelConfiguration()
                    config.computeUnits = .all
                    
                    self.model = try MLModel(contentsOf: modelURL, configuration: config)
                    print("✓ Wav2VecManager initialized (Background)")
                    
                } catch {
                    print("✗ Wav2VecManager init failed: \(error)")
                }
    }
    
    /// Main entry point: Takes raw float samples and returns phoneme predictions
    func process(samples: [Float]) throws -> [[PhonemePrediction]] {
        guard let decoder = decoder, model != nil else {
            // Reusing your existing error enum if available, or generic error
            throw AudioError.modelNotLoaded
        }

        // 1. Split large audio into chunks the model can handle
        let chunks = splitIntoChunks(samples: samples)
        var allLogits: [[[Float]]] = []
        
        // 2. Run inference on each chunk
        for (_, chunk) in chunks.enumerated() {
            let logits = try runInference(on: chunk)
            allLogits.append(logits)
        }
        
        // 3. Decode logits into Phonemes
        return decoder.decodeChunks(allLogits)
    }
    
    // MARK: - Internal CoreML Logic
    
    private func runInference(on chunk: [Float]) throws -> [[Float]] {
        guard let model = model else { throw AudioError.modelNotLoaded }
        
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: chunkSize)], dataType: .float32)
        for i in 0..<chunk.count {
            inputArray[i] = NSNumber(value: chunk[i])
        }
        
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_values": MLFeatureValue(multiArray: inputArray)
        ])
        
        let output = try model.prediction(from: inputFeatures)
        
        guard let outputFeature = output.featureValue(for: "var_1659") ?? output.featureValue(for: "logits"),
              let outputArray = outputFeature.multiArrayValue else {
            throw AudioError.invalidOutput
        }
        
        return convertToLogits(outputArray)
    }
    
    private func splitIntoChunks(samples: [Float]) -> [[Float]] {
        if samples.count < chunkSize {
            var chunk = samples
            chunk.append(contentsOf: [Float](repeating: 0, count: chunkSize - chunk.count))
            return [chunk]
        }
        
        if samples.count == chunkSize { return [samples] }
        
        let overlap = 8000
        let stride = chunkSize - overlap
        var chunks: [[Float]] = []
        var startIndex = 0
        
        while startIndex < samples.count {
            let endIndex = min(startIndex + chunkSize, samples.count)
            var chunk = Array(samples[startIndex..<endIndex])
            if chunk.count < chunkSize {
                chunk.append(contentsOf: [Float](repeating: 0, count: chunkSize - chunk.count))
            }
            chunks.append(chunk)
            if endIndex >= samples.count { break }
            startIndex += stride
        }
        return chunks
    }
    
    private func convertToLogits(_ mlArray: MLMultiArray) -> [[Float]] {
        let shape = mlArray.shape.map { $0.intValue }
        let timeSteps = (shape.count == 3) ? shape[1] : shape[0]
        let vocabSize = (shape.count == 3) ? shape[2] : shape[1]
        
        var logits = [[Float]](repeating: [Float](repeating: 0, count: vocabSize), count: timeSteps)
        
        for t in 0..<timeSteps {
            for v in 0..<vocabSize {
                let indices: [NSNumber] = (shape.count == 3)
                    ? [0, NSNumber(value: t), NSNumber(value: v)]
                    : [NSNumber(value: t), NSNumber(value: v)]
                logits[t][v] = mlArray[indices].floatValue
            }
        }
        return logits
    }
}
