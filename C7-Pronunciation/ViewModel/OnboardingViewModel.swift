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
    
    func loadPages() {
        pages = [
            OnboardingPage(
                imageName: "Onboarding(1)",
                title: "A Personal Speaking Tutor at Your Fingertips",
                description: "Master your speaking skills with focused practice; anytime, anywhere."
            ),
            OnboardingPage(
                imageName: "Onboarding(2)",
                title: "Your First Step to Mastery",
                description: """
                Learn to say the key phrases for your career. Our intelligent system caters your exercises to focus on exactly what you need.
                """
            ),
            OnboardingPage(
                imageName: "Onboarding(3)",
                title: "Practice What You Want, How You Want",
                description: "Need to prepare for something? Add your own practice script, and save your signature phrases!"
            )
        ]
    }
    
    /// Advances to the next page or finishes onboarding if on the last page.
    func goToPreviousPage() {
        if currentPageIndex != 0 {
            currentPageIndex -= 1
        }
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
