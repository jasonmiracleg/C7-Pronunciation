//
//  EspeakTestView.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//

import SwiftUI

struct EspeakTestView: View {
    @State private var inputText = "Hello World"
    @State private var phonemeString: String = ""
    @State private var phonemeArray: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("eSpeak-NG IPA Converter")
                .font(.headline)
                .padding(.top)
            
            // Input Area
            TextField("Enter text here...", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            // Trigger Button
            Button("Convert to IPA") {
                // 1. Get the clean string representation
                self.phonemeString = EspeakManager.shared.getPhonemesAsString(for: inputText)
                
                // 2. Get the raw array (if you need individual tokens)
                self.phonemeArray = EspeakManager.shared.getPhonemes(for: inputText)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    
                    // Section 1: Clean Sentence Output
                    if !phonemeString.isEmpty {
                        VStack(alignment: .leading) {
                            Text("IPA Sentence:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(phonemeString)
                                .font(.system(.title2, design: .serif))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .textSelection(.enabled) // Allow copying
                        }
                    }
                    
                    // Section 2: Raw Token Debug
                    if !phonemeArray.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Raw Tokens:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(phonemeArray.description)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .onAppear {
            // Optional: Trigger an initial conversion to verify setup works immediately
            self.phonemeString = EspeakManager.shared.getPhonemesAsString(for: inputText)
            self.phonemeArray = EspeakManager.shared.getPhonemes(for: inputText)
        }
    }
}
