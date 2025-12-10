//
//  AudioPreprocessor.swift (FIXED - Correct Normalization)
//  Zero-mean unit-variance normalization for wav2vec2 compatibility
//

import AVFoundation
import Accelerate


struct AudioPreprocessor {
    static let targetSampleRate: Double = 16000
    static let chunkDuration: Double = 5.0 // seconds
    static let chunkSize: Int = Int(targetSampleRate * chunkDuration) // 80,000 samples
    
    // Energy threshold for valid chunks
    static let minChunkEnergy: Float = 0.01
    
    // Epsilon for numerical stability (matches HuggingFace)
    private static let epsilon: Float = 1e-5
    
    /// Load and preprocess audio file
    /// Returns raw samples - normalization happens per-chunk in splitIntoChunks
    static func loadAudio(from url: URL) throws -> [Float] {
        print("Loading audio from: \(url.lastPathComponent)")
        
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        
        print("  Format: \(format.sampleRate)Hz, \(format.channelCount) channel(s)")
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw AudioError.loadFailed
        }
        
        try audioFile.read(into: buffer)
        
        var monoSamples = convertToMono(buffer: buffer)
        
        print("  Loaded \(monoSamples.count) samples (\(Double(monoSamples.count)/format.sampleRate)s)")
        
        if monoSamples.count < 1600 {
            throw AudioError.tooShort
        }
        
        // Resample to 16kHz if needed
        if format.sampleRate != targetSampleRate {
            print("  Resampling from \(format.sampleRate)Hz to \(targetSampleRate)Hz...")
            monoSamples = try resample(
                samples: monoSamples,
                fromRate: format.sampleRate,
                toRate: targetSampleRate
            )
        }
        
        // Check signal energy
        let signalEnergy = calculateRMS(monoSamples)
        print("  Signal RMS energy: \(signalEnergy)")
        
        if signalEnergy < 0.001 {
            print("  ⚠️ WARNING: Audio is very quiet!")
        }
        
        // DO NOT normalize here - normalization happens per-chunk in splitIntoChunks
        // This ensures each chunk is independently normalized before padding
        
        return monoSamples
    }
    
    /// Calculate RMS (Root Mean Square) energy of signal
    static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        vDSP_svesq(samples, 1, &sum, vDSP_Length(samples.count))
        return sqrt(sum / Float(samples.count))
    }
    
    /// Convert stereo/multi-channel to mono
    private static func convertToMono(buffer: AVAudioPCMBuffer) -> [Float] {
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
    
    /// Resample audio to target sample rate
    private static func resample(
        samples: [Float],
        fromRate: Double,
        toRate: Double
    ) throws -> [Float] {
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
    
    // MARK: - Zero-Mean Unit-Variance Normalization (CRITICAL FIX)
    
    /// Normalize samples using zero-mean unit-variance normalization
    /// This matches HuggingFace Wav2Vec2FeatureExtractor and is REQUIRED for wav2vec2-lv60 models
    /// Formula: (x - mean) / sqrt(variance + epsilon)
    static func normalize(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }
        
        // Calculate mean using Accelerate
        var mean: Float = 0
        vDSP_meanv(samples, 1, &mean, vDSP_Length(samples.count))
        
        // Calculate variance: E[X^2] - E[X]^2
        var sumOfSquares: Float = 0
        vDSP_svesq(samples, 1, &sumOfSquares, vDSP_Length(samples.count))
        let meanOfSquares = sumOfSquares / Float(samples.count)
        let variance = meanOfSquares - (mean * mean)
        
        // Standard deviation with epsilon for numerical stability
        let std = sqrt(variance + epsilon)
        
        // Normalize: (x - mean) / std
        var result = [Float](repeating: 0, count: samples.count)
        var negativeMean = -mean
        
        // Subtract mean
        vDSP_vsadd(samples, 1, &negativeMean, &result, 1, vDSP_Length(samples.count))
        
        // Divide by std
        var stdReciprocal = 1.0 / std
        vDSP_vsmul(result, 1, &stdReciprocal, &result, 1, vDSP_Length(result.count))
        
        return result
    }
    
    /// Split audio into 5-second chunks with proper normalization
    /// Each chunk is normalized BEFORE padding to match HuggingFace behavior
    static func splitIntoChunks(
        samples: [Float],
        overlapSeconds: Double = 0.5
    ) -> [[Float]] {
        print("\n📊 Smart Chunking Analysis:")
        print("  Total samples: \(samples.count)")
        print("  Duration: \(Double(samples.count) / targetSampleRate)s")
        
        // If audio is <= 5 seconds, return as single chunk (normalized then padded)
        if samples.count <= chunkSize {
            print("  ✓ Audio fits in single chunk")
            
            // Calculate energy BEFORE normalization
            let energy = calculateRMS(samples)
            print("  Chunk energy (pre-norm): \(energy)")
            
            // NORMALIZE the actual audio content FIRST
            var chunk = normalize(samples)
            
            // THEN pad with zeros (zeros stay as zeros, which is correct)
            if chunk.count < chunkSize {
                let paddingNeeded = chunkSize - chunk.count
                print("  Padding with \(paddingNeeded) zeros (after normalization)")
                chunk.append(contentsOf: [Float](repeating: 0, count: paddingNeeded))
            }
            
            return [chunk]
        }
        
        // For longer audio, use smarter chunking
        print("  Audio requires multiple chunks")
        
        let overlapSamples = Int(targetSampleRate * overlapSeconds)
        let stride = chunkSize - overlapSamples
        
        var chunks: [[Float]] = []
        var startIndex = 0
        
        while startIndex < samples.count {
            let endIndex = min(startIndex + chunkSize, samples.count)
            let rawChunk = Array(samples[startIndex..<endIndex])
            
            // Calculate energy BEFORE normalization
            let chunkEnergy = calculateRMS(rawChunk)
            let actualDuration = Double(rawChunk.count) / targetSampleRate
            
            print("\n  Chunk \(chunks.count + 1):")
            print("    Start: \(startIndex), End: \(endIndex)")
            print("    Duration: \(String(format: "%.2f", actualDuration))s")
            print("    Energy (pre-norm): \(chunkEnergy)")
            
            // Only pad if this is the last chunk AND it has enough content
            if rawChunk.count < chunkSize {
                let percentFilled = Double(rawChunk.count) / Double(chunkSize) * 100
                print("    Content: \(String(format: "%.1f", percentFilled))% filled")
                
                // Skip if mostly padding (less than 50% real audio)
                if percentFilled < 50 {
                    print("    ⚠️ SKIPPING: Chunk would be >50% padding")
                    break
                }
                
                // Skip if energy is too low (likely silence/noise)
                if chunkEnergy < minChunkEnergy {
                    print("    ⚠️ SKIPPING: Energy too low (\(chunkEnergy) < \(minChunkEnergy))")
                    break
                }
            }
            
            // NORMALIZE the raw audio content FIRST (before padding)
            var chunk = normalize(rawChunk)
            
            // THEN pad if needed (padding stays as zeros)
            if chunk.count < chunkSize {
                let paddingNeeded = chunkSize - chunk.count
                print("    Padding with \(paddingNeeded) zeros (after normalization)")
                chunk.append(contentsOf: [Float](repeating: 0, count: paddingNeeded))
            }
            
            chunks.append(chunk)
            print("    ✓ Chunk added (normalized)")
            
            // Break if we've processed the entire audio
            if endIndex >= samples.count {
                break
            }
            
            startIndex += stride
        }
        
        print("\n  ✓ Created \(chunks.count) valid chunk(s)")
        return chunks
    }
}
