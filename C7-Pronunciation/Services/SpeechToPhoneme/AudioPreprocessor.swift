//
//  AudioPreprocessor.swift (FIXED - Smart Chunking)
//  Only processes chunks with actual speech content
//

import AVFoundation
import Accelerate

enum AudioError: Error {
    case fileNotFound
    case loadFailed
    case invalidFormat
    case resamplingFailed
    case silentAudio
    case tooShort
}

struct AudioPreprocessor {
    static let targetSampleRate: Double = 16000
    static let chunkDuration: Double = 5.0 // seconds
    static let chunkSize: Int = Int(targetSampleRate * chunkDuration) // 80,000 samples
    
    // Energy threshold for valid chunks
    static let minChunkEnergy: Float = 0.01
    
    /// Load and preprocess audio file
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
        
        // Check signal energy BEFORE normalization
        let signalEnergy = calculateRMS(monoSamples)
        print("  Signal RMS energy: \(signalEnergy)")
        
        // REMOVED: Don't throw error for quiet audio, just warn
        if signalEnergy < 0.001 {
            print("  ⚠️ WARNING: Audio is very quiet!")
        }
        
        // Normalize to [-1, 1]
        normalize(&monoSamples)
        
        let maxAfterNorm = monoSamples.map { abs($0) }.max() ?? 0
        print("  Normalized: max amplitude = \(maxAfterNorm)")
        
        return monoSamples
    }
    
    /// Calculate RMS (Root Mean Square) energy of signal
    private static func calculateRMS(_ samples: [Float]) -> Float {
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
    
    /// Normalize samples to [-1, 1] range
    private static func normalize(_ samples: inout [Float]) {
        var maxVal: Float = 0
        vDSP_maxmgv(samples, 1, &maxVal, vDSP_Length(samples.count))
        
        if maxVal > 0 {
            var divisor = maxVal
            vDSP_vsdiv(samples, 1, &divisor, &samples, 1, vDSP_Length(samples.count))
        }
    }
    
    /// Split audio into 5-second chunks - IMPROVED VERSION
    /// Only creates chunks with actual speech content
    static func splitIntoChunks(
        samples: [Float],
        overlapSeconds: Double = 0.5
    ) -> [[Float]] {
        print("\n📊 Smart Chunking Analysis:")
        print("  Total samples: \(samples.count)")
        print("  Duration: \(Double(samples.count) / targetSampleRate)s")
        
        // If audio is <= 5 seconds, return as single chunk (padded)
        if samples.count <= chunkSize {
            print("  ✓ Audio fits in single chunk")
            var chunk = samples
            if chunk.count < chunkSize {
                let paddingNeeded = chunkSize - chunk.count
                print("  Padding with \(paddingNeeded) zeros")
                chunk.append(contentsOf: [Float](repeating: 0, count: paddingNeeded))
            }
            
            let energy = calculateRMS(chunk)
            print("  Chunk energy: \(energy)")
            
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
            var chunk = Array(samples[startIndex..<endIndex])
            
            // Calculate energy BEFORE padding
            let chunkEnergy = calculateRMS(chunk)
            let actualDuration = Double(chunk.count) / targetSampleRate
            
            print("\n  Chunk \(chunks.count + 1):")
            print("    Start: \(startIndex), End: \(endIndex)")
            print("    Duration: \(String(format: "%.2f", actualDuration))s")
            print("    Energy: \(chunkEnergy)")
            
            // Only pad if this is the last chunk AND it has enough content
            if chunk.count < chunkSize {
                let percentFilled = Double(chunk.count) / Double(chunkSize) * 100
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
                
                let paddingNeeded = chunkSize - chunk.count
                print("    Padding with \(paddingNeeded) zeros")
                chunk.append(contentsOf: [Float](repeating: 0, count: paddingNeeded))
            }
            
            // Verify final chunk has reasonable energy
            let finalEnergy = calculateRMS(chunk)
            print("    Final energy: \(finalEnergy)")
            
            if finalEnergy >= minChunkEnergy {
                chunks.append(chunk)
                print("    ✓ Chunk added")
            } else {
                print("    ⚠️ SKIPPING: Final energy too low")
                break
            }
            
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
