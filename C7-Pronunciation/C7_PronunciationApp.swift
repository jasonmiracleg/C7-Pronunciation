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
    
    @State private var showDebug = false

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
                    
                    // God Mode DEBUGGG
//                    if hasCompletedOnboarding {
//                        VStack {
//                            HStack {
//                                Spacer()
//                                Button(action: {
//                                    showDebug = true
//                                }) {
//                                    Text("🧠")
//                                        .font(.largeTitle)
//                                        .padding()
//                                        .background(Color.black.opacity(0.2))
//                                        .clipShape(Circle())
//                                }
//                                .padding(.top, 50)
//                                .padding(.trailing, 20)
//                            }
//                            Spacer()
//                        }
//                        .zIndex(2) 
//                    }
                }
                
                if !isModelLoaded {
                    SplashScreenView()
                        .zIndex(1)
                        .transition(.opacity.animation(.easeOut(duration: 1.0)))
                }
            }
            .modelContainer(DataBankManager.shared.modelContainer)
            .sheet(isPresented: $showDebug) {
                DebugPhonemeView()
                    .environmentObject(user)
            }
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
