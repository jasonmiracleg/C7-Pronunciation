//
//  FlashcardPageView.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 17/11/25.
//

import AVFoundation
import SwiftUI

struct FlashcardPageView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var user: User
    @StateObject private var viewModel = FlashcardViewModel()
    @State private var phrase: Phrase?
    @State private var isLoadingPhrases = true
    @State private var isEvaluated = false
    @State private var selectedWord: WordScore? = nil

    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoadingPhrases {
                    ProgressView("Loading phrases...")
                }
                else {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        // MARK: - Instructions
                        Text("Let's practice your pronunciation by reading the sentences on the cards below.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 16)
                        
                        // MARK: - Card Display
                        if let currentPhrase = phrase {
                            FlashcardView(
                                viewModel: viewModel,
                                onPlayAudio: { speak(text: currentPhrase.text) },
                                onTapWord: { word in
                                    selectedWord = word
                                }
                            )
                            .padding(.horizontal, 24)
                            .frame(height: 400)
                        }
                        
                        Spacer()
                        
                        // MARK: - Buttons (Microphone / Next / Retry)
                        buttonStack
                            .padding(.bottom, 40)
                    }
                    .onChange(of: viewModel.isEvaluated) { _, newValue in
                        if newValue == true {
                            isEvaluated = true
                        }
                    }
                }

                
                // MARK: - Error Overlay
                if let error = viewModel.errorMessage {
                    VStack {
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding(.top, 50)
                    .transition(.move(edge: .top))
                    .zIndex(1)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            viewModel.errorMessage = nil
                        }
                    }
                }
            }
            .navigationTitle("Flash Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                loadPhrases()
            }
            .sheet(item: $selectedWord) { word in
                CorrectPronunciationSheetView(wordScore: word) 
                    .presentationDetents([.fraction(0.25)])
            }
        }
    }
    
    // MARK: - Subviews
    
    var headerView: some View {
        HStack {
            Spacer()
            Text("Flash Cards")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
            }
        }
    }
    
    var buttonStack: some View {
        ZStack {
            // 1. Main Action Button
            if isEvaluated {
                retryButton
                    .transition(.opacity)
            } else {
                recordingButton
                    .transition(.opacity)
            }
            
            // 2. Next Button
            if isEvaluated {
                nextButton
                    .offset(x: 90)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 100)
    }


    // MARK: - Data Loading

    private func loadPhrases() {
        Task { @MainActor in
            isLoadingPhrases = true
            isEvaluated = false
            
            
            if user.phraseQueue.isEmpty {
                user.addPhrasesToQueue(basedOn: .mixed)
            }
            
            if !user.phraseQueue.isEmpty {
                phrase = user.nextCard()
                
                // Set the target for the ViewModel
                if let currentPhrase = phrase {
                    viewModel.updateTargetSentence(currentPhrase.text)
                }
            } else {
                phrase = nil
            }

            isLoadingPhrases = false
            
            print("✅ Loaded phrase for practice")
        }
    }

    private func loadNextPhrase() {
        // A. Capture the scores from the current attempt
        let currentPhonemes = viewModel.getCurrentPhonemes()
        
        // B. Update the User profile
        user.updateScores(with: currentPhonemes)
        
        print("💾 Saved scores for \(currentPhonemes.count) phonemes")

        // C. Reset UI state
        isEvaluated = false
        
        // D. Load the next phrase
        loadPhrases()
    }

    private func resetCard() {
        guard let currentPhrase = phrase else { return }
        
        // 1. Reset UI state
        isEvaluated = false
        
        // 2. Tell the ViewModel to reset its scores/state
        viewModel.updateTargetSentence(currentPhrase.text)
    }
    
    var recordingButton: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
                    .frame(width: 120, height: 120)
            } else {
                VStack {
                    Button(action: {
                        viewModel.toggleRecording()
                    }) {
                        Image(systemName: viewModel.isRecording
                              ? "stop.circle.fill"
                              : "microphone.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                    }
                    .glassEffect( .regular.tint(Color.accent))
                }
                .frame(width: 120, height: 120)
            }
        }
    }
    
    var retryButton: some View {
        Button(action: resetCard) {
            
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)

        }
        // Disable interaction if loading
        .glassEffect( .regular.tint(Color.accent))
        .disabled(viewModel.isLoading)
        
        
    }
    
    var nextButton: some View {
        Button(action: loadNextPhrase) {
            Image(systemName: "arrow.forward.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.white)
        }
        .glassEffect( .regular.tint(Color.accent))
        .disabled(viewModel.isLoading)
    }

    // MARK: - Helpers

    func speak(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Create a mutable copy of the text for modification
        var modifiedText = text
        
        // Regular expression to find isolated, single capital letters.
        let pattern = "\\b([A-Z])\\b"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            
            modifiedText = regex.stringByReplacingMatches(
                in: modifiedText,
                options: [],
                range: NSRange(location: 0, length: modifiedText.utf16.count),
                withTemplate: "$1".lowercased()
            )
            
        } catch {
            print("Regex error: \(error)")
            modifiedText = text
        }

        let textToSpeak = modifiedText
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // We use .playAndRecord with .defaultToSpeaker so we don't break the microphone permission/setup
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }

        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
}

// Preview
struct FlashcardPageView_Previews: PreviewProvider {
    static var previews: some View {
    let user = User()
    
    FlashcardPageView()
        .environmentObject(user)
    }
}
