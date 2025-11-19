//
//  PronunciationView.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//

import Combine
import SwiftUI

struct PronunciationView: View { 
    
    @StateObject private var viewModel = PronunciationViewModel()
    @StateObject private var synthesizer = SpeechSynthesizer() // Keep this helper for playback
    
    // UI State for the detail sheet
    @State private var selectedWord: WordScore?
    @State private var showingWordDetail = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                inputSection
                recordingSection
                resultsSection
            }
            .navigationTitle("Pronunciation AI")
            .sheet(item: $selectedWord) { word in
                WordDetailView(word: word, synthesizer: synthesizer)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var inputSection: some View {
        Section("Target Text") {
            TextEditor(text: $viewModel.targetSentence)
                .frame(height: 80)
                .focused($isInputFocused)
            
            Button("Done") {
                isInputFocused = false
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private var recordingSection: some View {
        Section {
            Button(action: viewModel.toggleRecording) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                    Text(viewModel.isRecording ? "Stop & Analyze" : "Start Recording")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .tint(viewModel.isRecording ? .red : .blue)
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
    }
    
    @ViewBuilder
    private var resultsSection: some View {
        if viewModel.isLoading {
            HStack {
                Spacer()
                ProgressView("Processing Audio...")
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
        
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundColor(.red)
                .font(.caption)
        }
        
        if let response = viewModel.evalResults {
            Section("Results") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Score:")
                        Text("\(response.totalScore*100, specifier: "%.0f")%")
                            .bold()
                            .foregroundColor(scoreColor(response.totalScore))
                    }
                    .font(.title2)
                    
                    Text(response.feedback)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
                
                // Individual word scores
                FlexibleFlowLayout(data: response.wordScores) { word in
                    WordChip(word: word, color: scoreColor(word.score))
                        .onTapGesture {
                            self.selectedWord = word
                        }
                }
            }
        }
    }
}

private func scoreColor(_ score: Double) -> Color {
    switch score*100 {
    case 85...100: return .green
    case 70..<85: return .blue
    case 50..<70: return .orange
    default: return .red
    }
}

// MARK: - Small Components

struct WordChip: View {
    let word: WordScore
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(word.word)
                .fontWeight(.medium)
                .foregroundColor(color)
            Text("\(Int(word.score*100))%")
                .font(.caption2)
                .foregroundColor(color.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct WordDetailView: View {
    let word: WordScore
    let synthesizer: SpeechSynthesizer
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(word.word)
                    .font(.largeTitle)
                    .bold()
                
                VStack {
                    Text("Spoken Phonemes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    buildSpokenPhonemesText()
                        .font(.title2)
                        .frame(maxWidth: .infinity, alignment: .leading) // Keep the layout
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    Text("Ideal Phonemes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(word.allTargets()) // This one remains unchanged
                        .font(.title2)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button {
                    synthesizer.speak(word: word.word)
                } label: {
                    Label("Play Pronunciation", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
//        DEBUG PRINT
//        .task {
//            for alignedPhoneme in word.alignedPhonemes {
//                print("Type: \(alignedPhoneme.type) | Actual: \(alignedPhoneme.actual ?? "?") | Target: \(alignedPhoneme.target) | Score: \(alignedPhoneme.score) | Note: \(alignedPhoneme.note ?? "None")")
//            }
//        }
    }
    
    private func buildSpokenPhonemesText() -> Text {
        var combinedText = Text("")
        
        print("Building spoken card for word: \(self.word.word)")
        print("Spoken phonemes: \(self.word.allActuals())")
        
        for phoneme in word.alignedPhonemes {
            if let actualPhoneme = phoneme.actual {
                print("\(actualPhoneme)")
                
                // Create a text view for this specific phoneme
                var phonemeText = Text(actualPhoneme)
                
                // Check the score. We color it if it's "blue or below" (< 85)
                if phoneme.score * 100 < 85 {
                    phonemeText = phonemeText.foregroundColor(scoreColor(phoneme.score))
                }
                
                // Add this phoneme and a space to the main text
                combinedText = Text("\(combinedText)\(phonemeText) ")            }
        }
        
        return combinedText
    }
}

#Preview{
    PronunciationView()
}
