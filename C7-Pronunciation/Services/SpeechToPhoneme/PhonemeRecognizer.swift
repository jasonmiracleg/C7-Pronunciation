//
//  PhonemeRecognizer.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//

import Foundation
import CoreML

class PhonemeRecognizer {
    
    // MARK: - Properties
    
    private let model: MLModel
    private let vocabulary: PhonemeVocabulary
    private let decoder: CTCDecoder
    
    // Model configuration
    private let inputName = "input_values"
    private let chunkSize = 80000 // 5 seconds at 16kHz
    
    // MARK: - Initialization
    
    init?() {
        // Load CoreML model
        guard let modelURL = Bundle.main.url(
            forResource: "Wav2Vec2_Phoneme",
            withExtension: "mlmodelc"
        ) ?? Bundle.main.url(
            forResource: "Wav2Vec2_Phoneme",
            withExtension: "mlpackage"
        ) else {
            print("Failed to find model in bundle")
            return nil
        }
        
        let config = MLModelConfiguration()
        config.computeUnits = .all // Use CPU, GPU, and Neural Engine
        
        guard let loadedModel = try? MLModel(contentsOf: modelURL, configuration: config) else {
            print("Failed to load CoreML model")
            return nil
        }
        
        self.model = loadedModel
        
        // Load vocabulary
        guard let vocab = PhonemeVocabulary(jsonFilename: "vocab") else {
            print("Failed to load vocabulary")
            return nil
        }
        
        self.vocabulary = vocab
        self.decoder = CTCDecoder(vocabulary: vocab)
        
        print("PhonemeRecognizer initialized successfully")
    }
    
    // MARK: - Public Methods
    
    /// Recognize phonemes from audio file
    /// - Parameter audioURL: URL to audio file
    /// - Returns: Phoneme string
    func recognize(audioURL: URL) throws -> String {
        // Load and preprocess audio
        let samples = try AudioPreprocessor.loadAudio(from: audioURL)
        
        print("Audio loaded: \(samples.count) samples (\(Double(samples.count)/16000.0)s)")
        
        // Split into chunks
        let chunks = AudioPreprocessor.splitIntoChunks(samples: samples)
        
        print("Split into \(chunks.count) chunks")
        
        // Process each chunk
        var allLogits: [[[Float]]] = []
        
        for (index, chunk) in chunks.enumerated() {
            print("Processing chunk \(index + 1)/\(chunks.count)...")
            
            let logits = try processChunk(chunk)
            allLogits.append(logits)
        }
        
        // Decode all chunks
        let phonemes = decoder.decodeChunks(allLogits)
        
        return phonemes
    }
    
    /// Recognize phonemes from audio samples (for streaming)
    /// - Parameter samples: Audio samples (any length, will be chunked automatically)
    /// - Returns: Phoneme string
    func recognize(samples: [Float]) throws -> String {
        print("Processing \(samples.count) samples (\(Double(samples.count)/16000.0)s)")
        
        // Split into chunks
        let chunks = AudioPreprocessor.splitIntoChunks(samples: samples)
        
        print("Split into \(chunks.count) chunks")
        
        // Process each chunk
        var allLogits: [[[Float]]] = []
        
        for (index, chunk) in chunks.enumerated() {
            print("Processing chunk \(index + 1)/\(chunks.count)...")
            
            let logits = try processChunk(chunk)
            allLogits.append(logits)
        }
        
        // Decode all chunks
        let phonemes = decoder.decodeChunks(allLogits)
        
        return phonemes
    }
    
    // MARK: - Private Methods
    
    /// Process a single 5-second audio chunk
    private func processChunk(_ chunk: [Float]) throws -> [[Float]] {
        // Add these debug prints
        let chunkMax = chunk.map { abs($0) }.max() ?? 0
        print("🔍 Chunk max amplitude: \(chunkMax)")
        
        if chunkMax < 0.001 {
            print("⚠️ SILENT CHUNK DETECTED - Will produce gibberish!")
        }
        
        // Create MLMultiArray input
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: chunkSize)], dataType: .float32)
        
        // Copy samples to MLMultiArray
        for i in 0..<chunk.count {
            inputArray[i] = NSNumber(value: chunk[i])
        }
        
        // Create input feature provider
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            inputName: MLFeatureValue(multiArray: inputArray)
        ])
        
        // Run inference
        let output = try model.prediction(from: inputFeatures)
        
        // Get output logits
        guard let outputFeature = output.featureValue(for: "var_1659") ?? output.featureValue(for: "logits"),
              let outputArray = outputFeature.multiArrayValue else {
            throw NSError(domain: "PhonemeRecognizer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to get model output"
            ])
        }
        
        // Convert MLMultiArray to [[Float]]
        let logits = convertToLogits(outputArray)
        
        return logits
    }
    
    /// Convert MLMultiArray to 2D array [timeSteps, vocabSize]
    private func convertToLogits(_ mlArray: MLMultiArray) -> [[Float]] {
        let shape = mlArray.shape.map { $0.intValue }
        
        // Expected shape: [1, timeSteps, vocabSize] or [timeSteps, vocabSize]
        let batchSize: Int
        let timeSteps: Int
        let vocabSize: Int
        
        if shape.count == 3 {
            batchSize = shape[0]
            timeSteps = shape[1]
            vocabSize = shape[2]
        } else if shape.count == 2 {
            batchSize = 1
            timeSteps = shape[0]
            vocabSize = shape[1]
        } else {
            print("Unexpected output shape: \(shape)")
            return []
        }
        
        var logits = [[Float]](
            repeating: [Float](repeating: 0, count: vocabSize),
            count: timeSteps
        )
        
        // CRITICAL: Use MLMultiArray subscripting to respect memory layout
        // Don't use raw pointer arithmetic - it assumes wrong strides!
        for t in 0..<timeSteps {
            for v in 0..<vocabSize {
                let indices: [NSNumber]
                if shape.count == 3 {
                    indices = [0, NSNumber(value: t), NSNumber(value: v)]
                } else {
                    indices = [NSNumber(value: t), NSNumber(value: v)]
                }
                
                logits[t][v] = mlArray[indices].floatValue
            }
        }
        
        return logits
    }
}
