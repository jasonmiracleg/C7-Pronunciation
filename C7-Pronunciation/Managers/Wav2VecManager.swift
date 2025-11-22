//
//  Wav2VecManager.swift
//  PronunciationScorer
//
//  Created by Savio Enoson on 19/11/25.
//  FIXED: Overlap handling to prevent duplicate phonemes at chunk boundaries
//

import Foundation
import CoreML

/// Responsible strictly for ML Model interaction and decoding logic.
class Wav2VecManager {
    
    private var model: MLModel?
    private var vocabulary: PhonemeVocabulary?
    private var decoder: CTCDecoder?
    
    private let modelName = "Wav2Vec2_Phoneme"
    private let vocabFilename = "vocab"
    private let chunkSize = 80000
    
    // Overlap configuration
    // 8000 samples = 0.5 seconds at 16kHz
    // This creates ~25 logit frames of overlap (8000 / 320 ≈ 25)
    private let overlapSamples = 8000
    private let samplesPerFrame = 320  // Wav2Vec2 downsampling factor (typically 320 for base model)
    
    // Track if we are already loaded so we don't reload
    private var isLoaded = false
    
    init() { }
    
    /// Call this to force the model to load. Returns when finished.
    func load() {
        if isLoaded { return }
        initialize()
        isLoaded = true
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
            print("✓ Wav2VecManager Model Loaded Successfully")
            
        } catch {
            print("✗ Wav2VecManager init failed: \(error)")
        }
    }
    
    /// Main entry point: Takes raw float samples and returns phoneme predictions
    func process(samples: [Float]) throws -> [[PhonemePrediction]] {
        guard let decoder = decoder, model != nil else {
            throw AudioError.modelNotLoaded
        }

        // 1. Split large audio into chunks the model can handle
        let chunks = splitIntoChunks(samples: samples)
        
        // If only one chunk, no overlap handling needed
        if chunks.count == 1 {
            let logits = try runInference(on: chunks[0])
            return decoder.decodeChunks([logits])
        }
        
        // 2. Run inference on each chunk and merge logits with overlap handling
        let mergedLogits = try processChunksWithOverlapHandling(chunks: chunks)
        
        // 3. Decode merged logits into Phonemes (as single continuous sequence)
        return decoder.decodeChunks([mergedLogits])
    }
    
    // MARK: - Overlap Handling (NEW)
    
    /// Process multiple chunks and merge their logits, handling overlap regions
    /// This prevents duplicate phonemes at chunk boundaries
    private func processChunksWithOverlapHandling(chunks: [[Float]]) throws -> [[Float]] {
        guard !chunks.isEmpty else { return [] }
        
        // Calculate how many logit frames correspond to the overlap
        // Wav2Vec2 downsamples audio by factor of ~320 (depends on model config)
        let overlapFrames = overlapSamples / samplesPerFrame
        
        print("📊 Processing \(chunks.count) chunks with overlap handling")
        print("   Overlap: \(overlapSamples) samples ≈ \(overlapFrames) logit frames")
        
        var mergedLogits: [[Float]] = []
        
        for (index, chunk) in chunks.enumerated() {
            let chunkLogits = try runInference(on: chunk)
            
            if index == 0 {
                // First chunk: use all logits
                mergedLogits = chunkLogits
                print("   Chunk 0: Added all \(chunkLogits.count) frames")
            } else {
                // Subsequent chunks: skip the overlap region at the beginning
                // The overlap region was already captured by the end of the previous chunk
                let framesToSkip = min(overlapFrames, chunkLogits.count)
                
                if framesToSkip < chunkLogits.count {
                    let newFrames = Array(chunkLogits.dropFirst(framesToSkip))
                    mergedLogits.append(contentsOf: newFrames)
                    print("   Chunk \(index): Skipped \(framesToSkip) overlap frames, added \(newFrames.count) new frames")
                } else {
                    print("   Chunk \(index): Skipped entirely (all overlap)")
                }
            }
        }
        
        print("   Total merged frames: \(mergedLogits.count)")
        return mergedLogits
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
        // Short audio: single chunk with padding
        if samples.count < chunkSize {
            var chunk = samples
            chunk.append(contentsOf: [Float](repeating: 0, count: chunkSize - chunk.count))
            return [chunk]
        }
        
        // Exact fit: no chunking needed
        if samples.count == chunkSize { return [samples] }
        
        // Long audio: split with overlap
        let stride = chunkSize - overlapSamples
        var chunks: [[Float]] = []
        var startIndex = 0
        
        while startIndex < samples.count {
            let endIndex = min(startIndex + chunkSize, samples.count)
            var chunk = Array(samples[startIndex..<endIndex])
            
            // Pad last chunk if needed
            if chunk.count < chunkSize {
                chunk.append(contentsOf: [Float](repeating: 0, count: chunkSize - chunk.count))
            }
            
            chunks.append(chunk)
            
            // Stop if we've reached the end
            if endIndex >= samples.count { break }
            
            startIndex += stride
        }
        
        print("📊 Split \(samples.count) samples into \(chunks.count) chunks (stride: \(stride), overlap: \(overlapSamples))")
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
