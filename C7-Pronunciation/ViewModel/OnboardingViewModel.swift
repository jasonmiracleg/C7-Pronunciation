//
//  OnboardingViewModel.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 14/11/25.
//

import Foundation
import SwiftUI
import Combine

class OnboardingViewModel: ObservableObject {
    
    @Published var pages: [OnboardingPage] = []
    @Published var currentPageIndex: Int = 0
    
    var onOnboardingFinished: (() -> Void)?
    
    var isLastPage: Bool {
        currentPageIndex == pages.count - 1
    }
    
    init(onOnboardingFinished: (() -> Void)? = nil) {
        self.onOnboardingFinished = onOnboardingFinished
        loadPages()
    }
    
    /// Populates the `pages` array with the content from your design.
    func loadPages() {
        pages = [
            OnboardingPage(
                imageName: "speaker.wave.2.fill",
                title: "Speak Confidently at Workplace",
                description: "Master your English pronunciation for your career, anytime and anywhere."
            ),
            OnboardingPage(
                imageName: "flame.fill", // Placeholder image
                title: "Master Key Workplace Phrases",
                description: "Practice common professional phrases with Flashcards. Listen, record, and get instant, word-level feedback."
            ),
            OnboardingPage(
                imageName: "lightbulb.fill", // Placeholder image
                title: "Practice Freely in the Sandbox",
                description: "Have something on your mind? Type any text you want in the Sandbox, from a new idea to a daily thought and check your pronunciation instantly."
            )
        ]
    }
    
    /// Advances to the next page or finishes onboarding if on the last page.
    func goToNextPage() {
        if currentPageIndex < pages.count - 1 {
            currentPageIndex += 1
        } else {
            finishOnboarding()
        }
    }
    
    /// Triggers the completion handler to dismiss onboarding.
    func finishOnboarding() {
        onOnboardingFinished?()
    }
}
