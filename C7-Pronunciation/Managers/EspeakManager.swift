//
//  EspeakManager.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//

import Foundation
import libespeak_ng

// Global C-function callback required by eSpeak
// It forwards events to our Swift Singleton
private func phonemeCallback(samples: UnsafeMutablePointer<Int16>?, num_samples: Int32, events: UnsafeMutablePointer<espeak_EVENT>?) -> Int32 {
    var evt = events
    while let e = evt?.pointee, e.type != espeakEVENT_LIST_TERMINATED {
        
        if e.type == espeakEVENT_PHONEME {
            let phoneme = withUnsafeBytes(of: e.id.string) { rawPtr in
                String(cString: rawPtr.bindMemory(to: CChar.self).baseAddress!)
            }
            // Accumulate the phoneme character
            EspeakManager.shared.accumulate(phoneme: phoneme)
        }
        
        if e.type == espeakEVENT_WORD {
            // We've hit the end of a word. Add a space.
            EspeakManager.shared.accumulate(phoneme: " ")
        }
        
        evt = evt?.advanced(by: 1)
    }
    return 0
}

public class EspeakManager {
    // Singleton Access
    public static let shared = EspeakManager()
    
    // Internal storage for the current synthesis session
    private var currentPhonemes: [String] = []
    private let queue = DispatchQueue(label: "espeak.manager.queue")

    private init() {
        setup()
    }
    
    // MARK: - Public API

    /// Returns an array of phoneme strings (e.g. ["h", "əl", "ˈəʊ"])
    public func getPhonemes(for text: String) -> [String] {
        queue.sync { currentPhonemes.removeAll() }

        // espeakCHARS_UTF8 = 1 (ensure text is treated as UTF8)
        let textLen = text.utf8.count
        espeak_ng_Synthesize(text, textLen, 0, POS_CHARACTER, 0, 1, nil, nil)
        espeak_ng_Synchronize()

        return queue.sync { return currentPhonemes }
    }

    /// Returns a single string of phonemes separated by spaces (e.g. "həlˈəʊ wˈɜːld")
    public func getPhonemesAsString(for text: String) -> String {
        return getPhonemes(for: text).joined(separator: " ")
    }

    // MARK: - Internal Helper
    fileprivate func accumulate(phoneme: String) {
        queue.async {
            self.currentPhonemes.append(phoneme)
        }
    }

    // MARK: - Setup Logic
    private func setup() {
        // 1. Locate source data in the App Bundle
        guard let bundleDataURL = Bundle.main.url(forResource: "espeak-ng-data", withExtension: nil) else {
            print("EspeakManager Error: 'espeak-ng-data' folder not found in Bundle.")
            return
        }
        
        // 2. Define destination in Documents (Required for write access)
        let fileManager = FileManager.default
        let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destDataURL = docDir.appendingPathComponent("espeak-ng-data")
        
        // 3. Copy if needed
        if !fileManager.fileExists(atPath: destDataURL.path) {
            do {
                try fileManager.copyItem(at: bundleDataURL, to: destDataURL)
            } catch {
                print("EspeakManager Error: Failed to copy data. \(error)")
                return
            }
        }
        
        // 4. Initialize Library
        // Point to the parent directory of 'espeak-ng-data'
        espeak_ng_InitializePath(docDir.path)
        espeak_ng_Initialize(nil)
        
        // 5. Set Synchronous Mode
        espeak_ng_InitializePath(docDir.path)
        espeak_ng_Initialize(nil)
        espeak_ng_InitializeOutput(ENOUTPUT_MODE_SYNCHRONOUS, 0, nil)
        
        // 6. Configuration
        espeak_ng_SetVoiceByName("en")
        
        // Enable Phoneme Events with IPA output
        // 1 = Enable Events
        // 2 = espeakPHONEMES_IPA (Output IPA Unicode chars)
        espeak_ng_SetPhonemeEvents(1, 2)
        
        // Register Callback
        espeak_SetSynthCallback(phonemeCallback)
        
        print("EspeakManager: Initialized successfully with IPA output.")
    }
}
