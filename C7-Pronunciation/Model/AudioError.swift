//
//  AudioError.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 19/11/25.
//

import Foundation


enum AudioError: LocalizedError {
    case noRecordingAvailable
    case phonemeRecognitionNotReady
    case managerDeallocated
    case modelNotLoaded
    case decoderNotInitialized
    case audioLoadFailed
    case invalidOutput
    case fileNotFound
    case loadFailed
    case invalidFormat
    case resamplingFailed
    case silentAudio
    case tooShort
    
    var errorDescription: String? {
        switch self {
        case .noRecordingAvailable:
            return "No recording available"
        case .phonemeRecognitionNotReady:
            return "Phoneme recognition not initialized"
        case .managerDeallocated:
            return "Audio manager was deallocated"
        case .modelNotLoaded:
            return "Model not loaded"
        case .decoderNotInitialized:
            return "Decoder not initialized"
        case .audioLoadFailed:
            return "Failed to load audio file"
        case .invalidOutput:
            return "Invalid model output"
        case .fileNotFound:
            return "File not found"
        case .loadFailed:
            return "Failed to load processor"
        case .invalidFormat:
            return "Audio is in an invalid format"
        case .resamplingFailed:
            return "Failed resampling audio"
        case .silentAudio:
            return "Audio is completely silent (likely corrupted)"
        case .tooShort:
            return "Audio file is too short"
        }
    }
}
