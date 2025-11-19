//
//  C7_PronunciationApp.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 13/11/25.
//

import SwiftUI
import SwiftData

@main
struct C7_PronunciationApp: App {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    init() {
        // Warm up the model in background during app launch. COMMENT OUT TO IMPROVE LOAD SPEED IF NOT USING IT YEAH !
        Task.detached(priority: .background) {
            AudioManager.shared.warmUp()
        }
    }
    
    var body: some Scene {
        WindowGroup {
//            DataBankTestView()
//            PronunciationTestView()
            if hasCompletedOnboarding {
                HomeScreenView()
            } else {
                OnboardingView {
                    self.hasCompletedOnboarding = true
                }
            }
        }
        .modelContainer(DataBankManager.shared.modelContainer)
    }
}
