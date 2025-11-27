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
    @EnvironmentObject private var viewModel: FlashcardViewModel
    
    @State private var phrase: Phrase?
    @State private var isLoadingPhrases = true
    @State private var selectedWord: WordScore? = nil
    
    @State private var nextButtonScale: CGFloat = 0.0
    @State private var nextButtonOffset: CGFloat = 0.0
    
    // MARK: - View Logic Helpers
    var showWaveform: Bool {
        return viewModel.isRecording || viewModel.isLoading
    }
    
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
                    // Sama layout hierarchy nya kayak custom view (for button / text placement consistency)
                    VStack(spacing: 0) {
                        Spacer().frame(height: 40)  // Slight but consistent padding up top
                        
                        // MARK: - Instructions
                        Text("Start by tapping the record button and speaking the words below out loud.")
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 40)
                            .foregroundStyle(!viewModel.canGenerateNewCards ? .primary : Color(UIColor.systemGroupedBackground))
                        
                        if viewModel.canGenerateNewCards {
                            FlashcardGeneratorView(viewModel: viewModel)
                                .padding(.top, 40)
                                .padding(.horizontal, 24)
                                .frame(height: 400)
                        } else if let currentPhrase = phrase {
                            FlashcardView(
                                viewModel: viewModel,
                                onPlayAudio: { speak(text: currentPhrase.text) },
                                onTapWord: { word in
                                    selectedWord = word
                                }
                            )
                            .padding(.top, 40)
                            .padding(.horizontal, 24)
                            .frame(height: 400)
                        }
                        
                        Spacer()
                        
                        // MARK: - Controls Area
                        controlsArea
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
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
                let customPhrases: [String] = [
                    "Your collective presence genuinely amplifies the atmosphere in this Academy",
                    "The feedback from this conference emphasized what should be improved upon."
                ]
                user.addCustomPhrases(basedOn: customPhrases)
                loadPhrases()
            }
            .onDisappear {
                resetState()
            }
            .sheet(item: $selectedWord) { word in
                CorrectPronunciationSheetView(wordScore: word)
                    .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - Subviews
    var controlsArea: some View {
        VStack {
            if viewModel.canGenerateNewCards {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.15)) {
                        nextButtonScale = 0.0
                        nextButtonOffset = 0.0
                    } completion: {
                        generateNewCards()
                    }
                }) {
                    Image(systemName: "shuffle.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }
                .glassEffect(.regular.tint(Color.accentColor))
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15)) {
                        nextButtonScale = 1.0
                        nextButtonOffset = 90.0
                    }
                }
                .onDisappear {
                    nextButtonScale = 0.0
                    nextButtonOffset = 0.0
                }
            } else if viewModel.isEvaluated {
                ZStack {
                    Button(action: {
                        viewModel.toggleRecording()
                    }) {
                        Image(systemName: (!viewModel.isRecording && !viewModel.isLoading) ? "microphone.circle.fill" : "stop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                    }
                    .glassEffect(viewModel.isLoading ? .regular.tint(Color.secondary) : .regular.tint(Color.accentColor))
                    .disabled(viewModel.isLoading)
                    
                    // 2. Right: Next Button
                    if viewModel.isEvaluated {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                nextButtonScale = 0.0
                                nextButtonOffset = 0.0
                            } completion: {
                                loadNextPhrase()
                            }
                        }) {
                            Image(systemName: "arrow.forward.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                        .glassEffect(.regular.tint(Color.accentColor))
                        .offset(x: nextButtonOffset)
                        .scaleEffect(nextButtonScale)
                        .opacity(nextButtonScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15)) {
                                nextButtonScale = 1.0
                                nextButtonOffset = 90.0
                            }
                        }
                        .onDisappear {
                            nextButtonScale = 0.0
                            nextButtonOffset = 0.0
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                VStack {
                    if showWaveform {
                        WaveformView(levels: viewModel.audioLevels)
                            .padding(.horizontal, 40)
                            .transition(.scale.animation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0)))
                    } else {
                        Color.clear.frame(height: 60)
                    }

                    Button(action: {
                        viewModel.toggleRecording()
                    }) {
                        Image(systemName: (!viewModel.isRecording && !viewModel.isLoading) ? "microphone.circle.fill" : "stop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                    }
                    .glassEffect(viewModel.isLoading ? .regular.tint(Color.secondary) : .regular.tint(Color.accentColor))
                    .disabled(viewModel.isLoading)
                }
            }
            
            

        }
        .padding(.bottom, 40)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isEvaluated)
        .animation(.easeInOut(duration: 0.3), value: showWaveform)
    }
    
    // MARK: - Data Loading
    
    private func loadPhrases() {
        Task {
            isLoadingPhrases = true
            
            if viewModel.firstTimeInstantGenerate {
                user.addPhrasesToQueue(basedOn: .mixed)
                viewModel.firstTimeInstantGenerate = false
            }
            
            if user.phraseQueue.isEmpty {
                viewModel.canGenerateNewCards = true
            } else {
                viewModel.canGenerateNewCards = false
            }
            
            if !user.phraseQueue.isEmpty {
                phrase = user.nextCard()
                print("current phrase: \(phrase?.text)")
                print("canGenerateNewCards: \(viewModel.canGenerateNewCards)")
                viewModel.iterateCardIndex()
                
                // Set the target for the ViewModel
                if let currentPhrase = phrase {
                    viewModel.updateTargetSentence(currentPhrase.text)
                }
            } else {
                phrase = nil
            }
            
            isLoadingPhrases = false
            
        }
    }
    
    private func loadNextPhrase() {
        print("LOADING NEXT PHRASE")
        
        // A. Capture the scores from the current attempt
        let currentPhonemes = viewModel.getCurrentPhonemes()
        
        // B. Update the User profile
        user.updateScores(with: currentPhonemes)
        
        // C. Load the next phrase
        loadPhrases()
    }
    
    private func generateNewCards(){
        if !user.phraseQueue.isEmpty {
            print("PHRASE QUEUE NOT EMPTY")
            viewModel.canGenerateNewCards = false
            loadNextPhrase()
            return
        }
        
        print("ADDING PHRASES")
        user.addPhrasesToQueue(basedOn: .mixed)
        viewModel.generateNewCards()
        loadNextPhrase()
    }
    
    private func resetCard() {
        guard let currentPhrase = phrase else { return }
        viewModel.updateTargetSentence(currentPhrase.text)
    }
    
    private func resetState() {
        user.clearQueue()
        viewModel.currentCardNumber = 0
        viewModel.firstTimeInstantGenerate = true
    }
    
    // MARK: - Audio Helpers
    
    func speak(text: String) {
        // Use the Singleton SpeechSynthesizer
        SpeechSynthesizer.shared.speak(text: text)
    }
}
