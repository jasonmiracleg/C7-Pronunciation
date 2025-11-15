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
    init() {
        // Warm up the model in background during app launch. COMMENT OUT TO IMPROVE LOAD SPEED IF NOT USING IT YEAH !
        Task {
            AudioManager.initialize()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            DataBankTestView()
        }
        .modelContainer(DataBankManager.shared.modelContainer)
    }
}
