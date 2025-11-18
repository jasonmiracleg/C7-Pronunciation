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
    
    // TTS for the speaker button (Playback)
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
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
                    FlashcardView(
                        viewModel: viewModel,
                        onPlayAudio: { speak(text: viewModel.targetSentence) }
                    )
                    .tag(0)
                    .padding(.horizontal, 20)
                    
                    // Dummy card
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .overlay(Text("Next Sentence...").foregroundColor(.gray))
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 400)
                
                Spacer()
                
                // MARK: - Microphone Button
                recordingButton
                    .padding(.bottom, 40)
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
                    // Auto-dismiss error after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        viewModel.errorMessage = nil
                    }
                }
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
        // Disable interaction while processing inference
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Helpers
    
    func speak(text: String) {
        // Stop any previous speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Slightly slower for practice
        synthesizer.speak(utterance)
    }
}


// Preview
struct FlashcardPageView_Previews: PreviewProvider {
    static var previews: some View {
        FlashcardPageView()
    }
}
