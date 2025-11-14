//
//  PronunciationViewModel.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//


import Foundation
import SwiftUI
import Combine

@MainActor
class PronunciationViewModel: ObservableObject {
    
    // Dependencies
    private let audioManager = AudioManager.shared
    private let networkManager = NetworkManager.shared
    
    // State
    @Published var targetText: String = "Good morning. My name is Jason."
    @Published var scoreResponse: ScoreResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRecording = false
    
    init() {
        // Sync Audio Manager state with View Model
        audioManager.$isRecording
            .assign(to: &$isRecording)
    }
    
    func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            // Automatically submit after stopping
            Task {
                await submitRecording()
            }
        } else {
            resetResults()
            audioManager.startRecording()
        }
    }
    
    private func submitRecording() async {
        guard let audioURL = audioManager.audioURL else {
            self.errorMessage = "Recording not found."
            return
        }
        
        self.isLoading = true
        
        do {
            let response = try await networkManager.scorePronunciation(text: targetText, audioURL: audioURL)
            self.scoreResponse = response
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
    
    func resetResults() {
        scoreResponse = nil
        errorMessage = nil
    }
}
