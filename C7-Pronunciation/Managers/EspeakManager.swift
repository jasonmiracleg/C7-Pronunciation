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
        
        evt = evt?.advanced(by: 1)
    }
    return 0
}

public class EspeakManager {
    // Singleton Access
    public static let shared = EspeakManager()
    
    // Internal storage for the current synthesis session
    private var currentPhonemes: [String] = []
    
    /// Loaded vocabulary for filtering phonemes.
    private var validPhonemes: Set<String> = []
    
    // MARK: - Public API
    
    /// Initializes the eSpeak-NG engine.
    /// This constructor is private to enforce the singleton pattern.
    private init() {
        // 1. Find the 'espeak-ng-data' directory in our App's bundle
        guard let bundlePath = Bundle.main.resourcePath else {
            fatalError("EspeakManager: Failed to find app bundle path.")
        }
        
        // 2. Find the Documents directory (where we can write)
        guard FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first != nil else {
            fatalError("EspeakManager: Failed to find documents directory.")
        }
        
        // 3. Set the path for espeak-ng data
        // The espeak_Initialize function needs the *parent* directory of "espeak-ng-data".
        // In this setup, we assume "espeak-ng-data" is at the root of the bundle.
        let dataPath = bundlePath
        
        // 4. Initialize Library
        espeak_ng_InitializePath(dataPath)
        let status = espeak_ng_Initialize(nil)
        if status != ENS_OK {
            fatalError("EspeakManager: Failed to initialize eSpeak-NG. Status: \(status)")
        }
        
        // 5. Set Synchronous Mode (Retrieval Mode)
        // This makes espeak_ng_Synthesize block until all phonemes are generated
        // and all callbacks have returned.
        espeak_ng_InitializeOutput(ENOUTPUT_MODE_SYNCHRONOUS, 0, nil)
        
        // 6. Configuration
        espeak_ng_SetVoiceByName("en-us")
        
        // Set pitch range to 0 to get a more monotonic (robotic) voice, typically is better for phoneme analysis.
        espeak_ng_SetParameter(espeakRANGE, 0, 0)
        
        // Enable Phoneme Events with IPA output
        // 1 = Enable Events
        // 2 = espeakPHONEMES_IPA (Output IPA Unicode chars)
        espeak_ng_SetPhonemeEvents(1, 2)
        
        // Register our global C function as the callback
        espeak_SetSynthCallback(phonemeCallback)
        
        print("EspeakManager: Initialized successfully with IPA output.")
    }
    
    /// Returns a single string of phonemes separated by spaces (e.g. "h ə l oʊ w ɜː l d")
    public func getPhonemesAsString(for text: String) -> String {
        let phonemesByWord = getPhonemes(for: text)
        return phonemesByWord.map { $0.joined() }.joined(separator: " ")
    }
    
    /// Generates phonemes for a given line of text, splitting by word.
    /// Generates phonemes for a given line of text.
        public func getPhonemes(for text: String) -> [[String]] {
            
            // 1. Define punctuation to remove, but KEEP apostrophes
            let punctuationToStrip = CharacterSet.punctuationCharacters
                .subtracting(CharacterSet(charactersIn: "'"))
            
            // 2. Split text into words
            let words = text.lowercased()
                .components(separatedBy: .whitespacesAndNewlines) // Split by space
                .map { $0.trimmingCharacters(in: punctuationToStrip) } // Remove "!" "," "." etc.
                .filter { !$0.isEmpty } // Remove empty strings
            
            var allWordsPhonemes: [[String]] = []
            
            // 3. Synthesize each word individually
            for word in words {
                // Get phonemes for this *individual* word.
                // synthesizePhrase("i'm") will now correctly return ["aɪ", "m"]
                // synthesizePhrase("i") will return ["aɪ"]
                // synthesizePhrase("am") will return ["ɐm"]
                let phonemes = synthesizePhrase(word)
                
                // Add the list if it's not empty
                if !phonemes.isEmpty {
                    allWordsPhonemes.append(phonemes)
                }
            }
            
            return allWordsPhonemes
        }
    
    
    /// Synthesizes a single word/phrase and returns all its phonemes as one list.
    private func synthesizePhrase(_ text: String) -> [String] {
        // 1. Clear previous state
        clear()
        
        // 2. Synthesize the text
        text.withCString { cText in
            espeak_ng_Synthesize(cText, strlen(cText) + 1, 0, POS_CHARACTER, 0, UInt32(espeakCHARS_UTF8), nil, nil)
        }
        
        // 3. Force eSpeak to process all remaining buffered events.
        espeak_ng_Synchronize()
        
        // 4. Return the flat list of phonemes collected by the callback.
        // We are assuming all phonemes belong to the single word we just synthesized.
        return currentPhonemes
    }
    
    // MARK: - Internal Callback Handlers
    
    /// (Called by C callback) Appends a phoneme to the internal list.
    internal func accumulate(phoneme: String) {
        // 1. Filter out known separators (which are sent as their own events)
        if phoneme.isEmpty || phoneme == " " || phoneme == "_" {
            return
        }
        
        // 2. Clean stress markers, which are prefixed to phonemes
        // (e.g., "ˈə" becomes "ə")
        let cleanedPhoneme = phoneme
            .replacingOccurrences(of: "ˈ", with: "")
            .replacingOccurrences(of: "ˌ", with: "")
        
        // 3. If the string was *only* a marker, it's now empty. Don't append.
        if cleanedPhoneme.isEmpty {
            return
        }
        
        // 4. Append the cleaned, valid phoneme
        currentPhonemes.append(cleanedPhoneme)
    }
    
    /// Resets the internal state for a new synthesis task.
    private func clear() {
        currentPhonemes = []
    }
    
    /// Loads and decodes the vocab.json file.
    private func loadVocabulary() {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "json") else {
            print("EspeakManager: WARNING - vocab.json not found. Phoneme filtering will be disabled.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            // Decode the vocabulary file
            let vocab = try JSONDecoder().decode(Vocabulary.self, from: data)
            
            // Build a set of the special tokens from the decoded struct
            let specialTokens = Set([
                vocab.specialTokens.pad,
                vocab.specialTokens.unk,
                vocab.specialTokens.bos,
                vocab.specialTokens.eos
            ])
            
            // Filter the vocab keys to get only valid phonemes (excluding special tokens)
            self.validPhonemes = Set(vocab.tokenToId.keys.filter { !specialTokens.contains($0) })
            
            print("EspeakManager: Successfully loaded \(self.validPhonemes.count) valid phonemes. Filtering enabled.")
        } catch {
            print("EspeakManager: ERROR - Failed to load or decode vocab.json: \(error). Filtering disabled.")
        }
    }
}

// MARK: - Vocabulary Model

// Helper struct to read vocab.json
private struct Vocabulary: Decodable {
    let vocabSize: Int
    let tokenToId: [String: Int]
    let specialTokens: SpecialTokens
    
    enum CodingKeys: String, CodingKey {
        case vocabSize = "vocab_size"
        case tokenToId = "token_to_id"
        case specialTokens = "special_tokens"
    }
}

// Tokens which exist in the IPA alphabet but not in the tokenizer. Must remove to maintain alignment accuracy
private struct SpecialTokens: Decodable {
    let pad: String
    let unk: String
    let bos: String
    let eos: String
}
