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
    var body: some Scene {
        WindowGroup {
            DataBankTestView()
        }
        .modelContainer(SwiftDataManager.shared.modelContainer) // Added model context here
    }
}
