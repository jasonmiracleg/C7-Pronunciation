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
            // We've hit the end of a word. Add a word boundary marker.
            EspeakManager.shared.markWordBoundary()
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
    private var wordBoundaries: [Int] = []  // Indices where words end
    private let queue = DispatchQueue(label: "espeak.manager.queue")
    
    // Vocabulary filtering
    private var validPhonemes: Set<String> = []
    private var phonemePattern: NSRegularExpression?

    private init() {
        setup()
        loadVocabulary()
    }
    
    // MARK: - Public API

    /// Returns an array of phoneme strings (e.g. ["h", "ə", "l", "oʊ"])
    public func getPhonemes(for text: String) -> [String] {
        queue.sync {
            currentPhonemes.removeAll()
            wordBoundaries.removeAll()
        }

        // espeakCHARS_UTF8 = 1 (ensure text is treated as UTF8)
        let textLen = text.utf8.count
        espeak_ng_Synthesize(text, textLen, 0, POS_CHARACTER, 0, 1, nil, nil)
        espeak_ng_Synchronize()

        let rawPhonemes = queue.sync { return currentPhonemes }
        
        // Join and filter through vocabulary
        let rawString = rawPhonemes.joined(separator: "")
        return filterPhonemes(from: rawString)
    }

    /// Returns a single string of phonemes separated by spaces (e.g. "h ə l oʊ w ɜː l d")
    public func getPhonemesAsString(for text: String) -> String {
        let phonemesByWord = getPhonemesByWord(for: text)
        
        // TODO: Benerin processing yg di atas (ini duct-tape tpi aku mager hehe)
        // Join each arr in a 2D array into a single string (it's now [String]); then join that array as well -> String
        return phonemesByWord.map { $0.joined() }.joined(separator: " ")
    }
    
    /// Returns phonemes grouped by word (e.g. [["h", "ə", "l", "oʊ"], ["w", "ɜː", "l", "d"]])
    /// Each inner array represents the phonemes for one word.
    public func getPhonemesByWord(for text: String) -> [[String]] {
        // Split text into words (same pattern as Python: word characters and apostrophes)
        let pattern = "\\b[\\w']+\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        var allWordsPhonemes: [[String]] = []
        
        for match in matches {
            let word = nsText.substring(with: match.range).lowercased()
            
            if word.isEmpty {
                continue
            }
            
            // Get phonemes for this individual word
            let wordPhonemes = getPhonemes(for: word)
            
            // Add to the main list (only if not empty)
            if !wordPhonemes.isEmpty {
                allWordsPhonemes.append(wordPhonemes)
            }
        }
        
//        print("Phonemes (by word): \(allWordsPhonemes)")
        return allWordsPhonemes
    }

    // MARK: - Internal Helpers
    
    fileprivate func accumulate(phoneme: String) {
        queue.async {
            self.currentPhonemes.append(phoneme)
        }
    }
    
    fileprivate func markWordBoundary() {
        queue.async {
            self.wordBoundaries.append(self.currentPhonemes.count)
        }
    }
    
    // MARK: - Vocabulary Filtering
    
    /// Load the model's vocabulary and build a filtering pattern
    private func loadVocabulary() {
        guard let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "json") else {
            print("EspeakManager Warning: vocab.json not found in Bundle. Phoneme filtering disabled.")
            return
        }
        
        do {
            let data = try Data(contentsOf: vocabURL)
            let vocab = try JSONDecoder().decode(Vocabulary.self, from: data)
            
            // Extract all valid phonemes (excluding special tokens)
            let specialTokens: Set<String> = ["<pad>", "<s>", "</s>", "<unk>"]
            validPhonemes = Set(vocab.tokenToId.keys.filter { !specialTokens.contains($0) })
            
            print(validPhonemes)
            
            // Build regex pattern (sort by length, longest first for greedy matching)
            let sortedPhonemes = validPhonemes.sorted { $0.count > $1.count }
            let pattern = sortedPhonemes.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            
            phonemePattern = try? NSRegularExpression(pattern: pattern, options: [])
            
            print("EspeakManager: Loaded \(validPhonemes.count) valid phonemes from vocabulary")
            
        } catch {
            print("EspeakManager Error: Failed to load vocabulary. \(error)")
        }
    }
    
    /// Filter raw eSpeak output to only include phonemes in the model's vocabulary
    /// This removes stress markers (ˈ, ˌ) and other symbols not in the vocabulary
    private func filterPhonemes(from rawOutput: String) -> [String] {
        guard let pattern = phonemePattern else {
            // Fallback: if no vocab loaded, return raw output split by common delimiters
            print("EspeakManager Warning: No vocabulary loaded, returning unfiltered phonemes")
            return rawOutput.components(separatedBy: CharacterSet.whitespaces)
                .filter { !$0.isEmpty }
        }
        
        let nsString = rawOutput as NSString
        let matches = pattern.matches(in: rawOutput, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var phonemes: [String] = []
        for match in matches {
            let phoneme = nsString.substring(with: match.range)
            phonemes.append(phoneme)
        }
        
        return phonemes
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
