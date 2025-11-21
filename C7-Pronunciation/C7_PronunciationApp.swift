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
    @StateObject private var user = User()
    @State private var isModelLoaded = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isModelLoaded {
//                    DataBankTestView()
                    Group {
                        if hasCompletedOnboarding {
                            HomeScreenView()
                                .environmentObject(user)
                        } else {
                            OnboardingView {
                                self.hasCompletedOnboarding = true
                            }
                        }
                    }
                    .transition(.opacity.animation(.easeIn(duration: 1.0)))
                }
                
                if !isModelLoaded {
                    SplashScreenView()
                        .zIndex(1)
                        .transition(.opacity.animation(.easeOut(duration: 1.0)))
                }
            }
            .modelContainer(DataBankManager.shared.modelContainer)
            .task {
                await AudioManager.shared.preloadModel()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                withAnimation {
                    isModelLoaded = true
                }
            }
        }
    }
}
