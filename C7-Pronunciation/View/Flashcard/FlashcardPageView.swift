//
//  FlashcardPageView.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 17/11/25.
//

import SwiftUI
import AVFoundation

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
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if isLoadingPhrases {
                ProgressView("Loading phrases...")
            }
            else {
                VStack(spacing: 20) {
                    // MARK: - Header
                    headerView
                    
                    // MARK: - Instructions
                    Text("Let's practice your pronunciation by reading the sentences on the cards below.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // MARK: - Card Display
                    if let currentPhrase = phrase {
                        FlashcardView(
                            viewModel: viewModel,
                            onPlayAudio: { speak(text: currentPhrase.text) },
                            onTapWord: { word in
                                selectedWord = word
                            }
                        )
                        .padding(.horizontal, 20)
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
        .onAppear {
            loadPhrases()
        }
        .sheet(item: $selectedWord) { word in
            CorrectPronunciationSheetView(wordScore: word) 
                .presentationDetents([.fraction(0.25)])
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
        .padding(.horizontal)
        .padding(.top, 20)
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
        Button(action: {
            viewModel.toggleRecording()
        }) {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.blue)
                    .frame(width: 72, height: 72)
                    .shadow(color: (viewModel.isRecording ? Color.red : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(viewModel.isLoading)
    }
    
    var retryButton: some View {
        Button(action: resetCard) {
            ZStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "arrow.clockwise")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        // Disable interaction if loading
        .disabled(viewModel.isLoading)
    }
    
    var nextButton: some View {
        Button(action: loadNextPhrase) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50) // Smaller size
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "arrow.forward")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Helpers
    
    func speak(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
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
