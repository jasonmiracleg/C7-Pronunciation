//
//  PhonemeRecognitionManager.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//

import Foundation
import CoreML
import AVFoundation

// MARK: - Errors

enum RecognitionError: LocalizedError {
    case notInitialized
    case modelNotLoaded
    case decoderNotInitialized
    case audioLoadFailed
    case invalidOutput
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Manager not initialized. Call initialize() first."
        case .modelNotLoaded:
            return "Model not loaded"
        case .decoderNotInitialized:
            return "Decoder not initialized"
        case .audioLoadFailed:
            return "Failed to load audio file"
        case .invalidOutput:
            return "Invalid model output"
        }
    }
}


// Single entry point for communicating with the Wav2Vec2 Model
class Wav2Vec2ModelManager {
    static let shared = Wav2Vec2ModelManager()
    
    // MARK: - Properties
    
    private var model: MLModel?
    private var vocabulary: PhonemeVocabulary?
    private var decoder: CTCDecoder?
    
    private let modelName = "Wav2Vec2_Phoneme"
    private let vocabFilename = "vocab"
    private let chunkSize = 80000 // 5 seconds at 16kHz
    
    private(set) var isInitialized = false
    
    // MARK: - Initialization
    
    private init() { }
    
    /// Initialize the manager (call this on app startup)
    /// - Returns: Success status
    @discardableResult
    func initialize() -> Bool {
        guard !isInitialized else {
            return true
        }
        
        do {
            // Load vocabulary from vocab.json file
            guard let vocab = PhonemeVocabulary(jsonFilename: vocabFilename) else {
                print("✗ Failed to load vocabulary from \(vocabFilename).json")
                return false
            }
            self.vocabulary = vocab
            
            // Initialize decoder
            self.decoder = CTCDecoder(vocabulary: vocab)
            
            // Load CoreML model
            guard let modelURL = Bundle.main.url(
                forResource: modelName,
                withExtension: "mlmodelc"
            ) ?? Bundle.main.url(
                forResource: modelName,
                withExtension: "mlpackage"
            ) else {
                return false
            }
            
            let config = MLModelConfiguration()
            config.computeUnits = .all // All = Model uses CPU, GPU, and Neural Engine
            
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
            
            isInitialized = true
            
            return true
            
        } catch {
            print("\n✗ Initialization failed: \(error)")
            return false
        }
    }
    
    // MARK: - Public API
    
    /// Recognize phonemes from an audio file
    /// - Parameter url: URL to audio file
    /// - Returns: Recognized phonemes as a string
    /// - Throws: Recognition errors
    func recognizePhonemes(from url: URL) throws -> String {
        guard isInitialized else {
            throw RecognitionError.notInitialized
        }
        
        // Load and preprocess audio
        let samples = try loadAndPreprocessAudio(from: url)
        
        // Split into chunks
        let chunks = splitIntoChunks(samples: samples)
        
        // Process each chunk
        var allLogits: [[[Float]]] = []
        
        for (_, chunk) in chunks.enumerated() {
            let logits = try processChunk(chunk)
            allLogits.append(logits)
        }
        
        // Decode
        guard let decoder = decoder else {
            throw RecognitionError.decoderNotInitialized
        }
        
        let phonemes = decoder.decodeChunks(allLogits)
        
        return phonemes
    }
    
    /// Recognize phonemes from raw audio samples
    /// - Parameter samples: Audio samples (16kHz, mono, normalized to [-1, 1])
    /// - Returns: Recognized phonemes as a string
    /// - Throws: Recognition errors
    func recognizePhonemes(from samples: [Float]) throws -> String {
        guard isInitialized else {
            throw RecognitionError.notInitialized
        }
        
        // Split into chunks
        let chunks = splitIntoChunks(samples: samples)
        
        // Process each chunk
        var allLogits: [[[Float]]] = []
        
        for (_, chunk) in chunks.enumerated() {
            let logits = try processChunk(chunk)
            allLogits.append(logits)
        }
        
        // Decode
        guard let decoder = decoder else {
            throw RecognitionError.decoderNotInitialized
        }
        
        let phonemes = decoder.decodeChunks(allLogits)
        
        return phonemes
    }
    
    /// Get vocabulary size
    var vocabularySize: Int {
        return vocabulary?.vocabSize ?? 0
    }
    
    /// Get model information
    var modelInfo: String {
        guard isInitialized else {
            return "Not initialized"
        }
        return """
        Model: \(modelName)
        Vocabulary: \(vocabularySize) tokens
        Chunk size: \(chunkSize) samples (5 seconds)
        Status: Ready
        """
    }
    
    // MARK: - Private Methods
    
    private func loadAndPreprocessAudio(from url: URL) throws -> [Float] {
        // Load audio file
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw RecognitionError.audioLoadFailed
        }
        
        try audioFile.read(into: buffer)
        
        // Convert to mono
        var samples = convertToMono(buffer: buffer)
        
        // Resample to 16kHz if needed
        if format.sampleRate != 16000 {
            samples = try resample(samples: samples, fromRate: format.sampleRate, toRate: 16000)
        }
        
        // Normalize
        normalize(&samples)
        
        return samples
    }
    
    private func convertToMono(buffer: AVAudioPCMBuffer) -> [Float] {
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        
        guard let channelData = buffer.floatChannelData else {
            return []
        }
        
        var monoSamples = [Float](repeating: 0, count: frameCount)
        
        if channelCount == 1 {
            for i in 0..<frameCount {
                monoSamples[i] = channelData[0][i]
            }
        } else {
            for i in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][i]
                }
                monoSamples[i] = sum / Float(channelCount)
            }
        }
        
        return monoSamples
    }
    
    private func resample(samples: [Float], fromRate: Double, toRate: Double) throws -> [Float] {
        let ratio = toRate / fromRate
        let outputLength = Int(Double(samples.count) * ratio)
        var outputSamples = [Float](repeating: 0, count: outputLength)
        
        for i in 0..<outputLength {
            let srcIndex = Double(i) / ratio
            let srcIndexInt = Int(srcIndex)
            let fraction = Float(srcIndex - Double(srcIndexInt))
            
            if srcIndexInt < samples.count - 1 {
                let sample1 = samples[srcIndexInt]
                let sample2 = samples[srcIndexInt + 1]
                outputSamples[i] = sample1 + (sample2 - sample1) * fraction
            } else if srcIndexInt < samples.count {
                outputSamples[i] = samples[srcIndexInt]
            }
        }
        
        return outputSamples
    }
    
    private func normalize(_ samples: inout [Float]) {
        guard let maxVal = samples.map({ abs($0) }).max(), maxVal > 0 else {
            return
        }
        
        for i in 0..<samples.count {
            samples[i] = samples[i] / maxVal
        }
    }
    
    private func splitIntoChunks(samples: [Float]) -> [[Float]] {
        // If fits in one chunk, return it
        if samples.count <= chunkSize {
            var chunk = samples
            if chunk.count < chunkSize {
                chunk.append(contentsOf: [Float](repeating: 0, count: chunkSize - chunk.count))
            }
            return [chunk]
        }
        
        // Split into overlapping chunks
        let overlap = 8000 // 0.5 seconds
        let stride = chunkSize - overlap
        
        var chunks: [[Float]] = []
        var startIndex = 0
        
        while startIndex < samples.count {
            let endIndex = min(startIndex + chunkSize, samples.count)
            var chunk = Array(samples[startIndex..<endIndex])
            
            // Skip if mostly padding (blank tokens)
            if chunk.count < chunkSize / 2 {
                break
            }
            
            // Pad if needed
            if chunk.count < chunkSize {
                chunk.append(contentsOf: [Float](repeating: 0, count: chunkSize - chunk.count))
            }
            
            chunks.append(chunk)
            
            if endIndex >= samples.count {
                break
            }
            
            startIndex += stride
        }
        
        return chunks
    }
    
    private func processChunk(_ chunk: [Float]) throws -> [[Float]] {
        guard let model = model else {
            throw RecognitionError.modelNotLoaded
        }
        
        // Create MLMultiArray
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: chunkSize)], dataType: .float32)
        
        for i in 0..<chunk.count {
            inputArray[i] = NSNumber(value: chunk[i])
        }
        
        // Create input
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_values": MLFeatureValue(multiArray: inputArray)
        ])
        
        // Run inference
        let output = try model.prediction(from: inputFeatures)
        
        // Get output
        guard let outputFeature = output.featureValue(for: "var_1659") ?? output.featureValue(for: "logits"),
              let outputArray = outputFeature.multiArrayValue else {
            throw RecognitionError.invalidOutput
        }
        
        // Convert to logits
        let logits = convertToLogits(outputArray)
        
        return logits
    }
    
    private func convertToLogits(_ mlArray: MLMultiArray) -> [[Float]] {
        let shape = mlArray.shape.map { $0.intValue }
        
        let timeSteps: Int
        let vocabSize: Int
        
        if shape.count == 3 {
            timeSteps = shape[1]
            vocabSize = shape[2]
        } else if shape.count == 2 {
            timeSteps = shape[0]
            vocabSize = shape[1]
        } else {
            return []
        }
        
        var logits = [[Float]](
            repeating: [Float](repeating: 0, count: vocabSize),
            count: timeSteps
        )
        
        // Use MLMultiArray subscripting to respect memory layout
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

