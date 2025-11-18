//
//  GavinTestView.swift
//  C7-Pronunciation
//
//  Created by Gerald Gavin Lienardi on 17/11/25.
//

import Foundation
import SwiftUI
import Combine


struct GavinTestView: View {
    
    @StateObject private var vm = GavinTestViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("Phoneme count: \(vm.user.phonemeScores.count)")
            Text("Loaded: \(vm.user.successfullyLoadedPhonemes)")
                .padding(.bottom, 8)
            
            // NEXT PHONEME
            HStack {
                Text("Next: \(vm.currentPhonemeName)")
                    .font(.headline)
                Spacer()
                Text("Eval: \(vm.randomScore)")
            }

            // BUTTON
            Button("Evaluate Random") {
                vm.evaluateRandom()
            }
            .buttonStyle(.borderedProminent)

            // RESULT TEXT
            if let last = vm.lastUpdateText {
                Text(last)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            // LIST OF SCORES
            List(vm.user.getRawMostAttemptedPhonemes(), id: \.id) { item in
                HStack {
                    Text(item.phoneme)
                    Spacer()
                    Text("A: \(item.attempts.description) S:")
                    Text(String(format: "%.3f", Double(item.score)))
                }
            }
        }
        .padding()
    }
}

#Preview {
    GavinTestView()
}

class GavinTestViewModel: ObservableObject {
    
    @Published var user: User = User()
    
    // state for simulation
    @Published var randomIndex: Int = 0
    @Published var randomScore: Int = 0 // 0–100
    @Published var lastUpdateText: String? = nil

    // easy display
    var currentPhonemeName: String {
        guard user.phonemeScores.indices.contains(randomIndex) else { return "" }
        return user.phonemeScores[randomIndex].phoneme
    }

    func evaluateRandom() {
        guard !user.phonemeScores.isEmpty else { return }

        // pick phoneme
        randomIndex = Int.random(in: 0 ..< user.phonemeScores.count)
        randomScore = Int.random(in: 0 ... 100)

        let phoneme = user.phonemeScores[randomIndex].phoneme
        let oldScore = user.phonemeScores[randomIndex].score
        let eval = Double(randomScore)

        // update through user function
        user.updateScore(for: phoneme, evalScore: eval)

        let newScore = user.phonemeScores[randomIndex].score
        let delta = newScore - oldScore

        lastUpdateText =
            "\(phoneme)  old: \(String(format: "%.3f", oldScore)) → new: \(String(format: "%.3f", newScore))   Δ: \(String(format: "%.3f", delta))"
    }
}



