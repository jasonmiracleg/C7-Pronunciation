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
    @StateObject private var viewModel = FlashcardViewModel()
    @State private var currentIndex = 0
    @State private var phrases: [Phrase] = []
    @State private var isLoadingPhrases = true
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if isLoadingPhrases {
                ProgressView("Loading phrases...")
            } else if phrases.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "text.badge.xmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No phrases available")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Button("Dismiss") {
                        dismiss()
                    }
                }
            } else {
                VStack(spacing: 20) {
                    // MARK: - Header
                    headerView
                    
                    // MARK: - Instructions
                    Text("Let's practice your pronunciation by reading the sentences on the cards below.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // MARK: - Card Carousel
                    TabView(selection: $currentIndex) {
                        ForEach(Array(phrases.enumerated()), id: \.offset) { index, phrase in
                            FlashcardView(
                                viewModel: viewModel,
                                onPlayAudio: { speak(text: phrase.text) }
                            )
                            .tag(index)
                            .padding(.horizontal, 20)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 400)
                    .onChange(of: currentIndex) { oldValue, newValue in
                        // Update the target sentence when swiping to a new card
                        if newValue < phrases.count {
                            viewModel.updateTargetSentence(phrases[newValue].text)
                        }
                    }
                    
                    // MARK: - Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<phrases.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // MARK: - Microphone Button
                    recordingButton
                        .padding(.bottom, 40)
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
    
    // MARK: - Data Loading
    
    private func loadPhrases() {
        Task { @MainActor in
            isLoadingPhrases = true
            
            // Fetch random phrases from different categories
            // You can customize this to fetch from specific categories or use different logic
            let randomPicks = DataBankManager.shared.getRandomPhrasePicks()
            
            // Combine phrases from different categories (or choose one category)
            var allPhrases: [Phrase] = []
            allPhrases.append(contentsOf: randomPicks.formal)
            allPhrases.append(contentsOf: randomPicks.informal)
            
            // Only add user-added phrases if they exist
            if !randomPicks.userAdded.isEmpty {
                allPhrases.append(contentsOf: randomPicks.userAdded)
            }
            
            // Shuffle for variety
            phrases = allPhrases.shuffled()
            
            // Set the first phrase as the target
            if let firstPhrase = phrases.first {
                viewModel.updateTargetSentence(firstPhrase.text)
            }
            
            isLoadingPhrases = false
            
            print("✅ Loaded \(phrases.count) phrases for practice")
        }
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
        FlashcardPageView()
    }
}
