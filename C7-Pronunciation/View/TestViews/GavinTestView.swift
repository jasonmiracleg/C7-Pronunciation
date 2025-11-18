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
        ScrollView {
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
                
                
                // BUTTON
                Button("Get 3 Random Phonemes") {
                    vm.getRandomPhonemes()
                }
                .buttonStyle(.borderedProminent)

                LazyHStack{
                    Button("Least Attempted") {
                        vm.getLeastAttemptedPhonemes()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Most Urgent") {
                        vm.getMostUrgentPhonemes()
                    }
                    .buttonStyle(.borderedProminent)
                }
                LazyHStack {
                    Button("Search/ Generate") {
                        vm.performPhonemeSearch()
                        vm.user.addPhrasesToQueue()

                    }
                    .buttonStyle(.borderedProminent)
                    Button("Next Card") {
                        vm.progressQueue()
                    }
                    
                    .buttonStyle(.borderedProminent)
                }

                
                // RESULT TEXT
                if let last = vm.lastUpdateText {
                    Text(last)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // LIST OF SCORES
                Text("Phonemes")
                // replace List with lazy stack
                LazyVStack {
                    ForEach(vm.user.getRawMostAttemptedPhonemes(), id: \.id) { item in
                        HStack {
                            Text(item.phoneme)
                            Spacer()
                            Text("A: \(item.attempts)")
                            Text("S: \(String(format: "%.3f", item.score))")
                        }
                        .padding(.vertical, 4)
                    }
                }

                Text("Search Terms")
                LazyVStack {
                    ForEach(vm.phonemeSearchTerms, id: \.self) { phoneme in
                        HStack {
                            Text(phoneme)
                                .font(.system(size: 16, design: .monospaced))
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Phrase Queue")
                        Spacer()
                        Text("\(vm.user.phraseQueue.count) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    if vm.grabbedPhrase != nil {
                        Text("Current card: \(vm.grabbedPhrase?.text)")
                    }

                    if vm.user.phraseQueue.isEmpty {
                        Text("Empty Queue.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(vm.user.phraseQueue.prefix(3).enumerated()), id: \.element.id) { index, phrase in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("#\(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                PhraseRow(phrase: phrase)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Results")
                        Spacer()
                        Text("\(vm.phonemeSearchResults.count) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    if vm.phonemeSearchResults.isEmpty {
                        Text("No results. Add phonemes and tap Search.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(vm.phonemeSearchResults.prefix(3).enumerated()), id: \.element.id) { index, phrase in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("#\(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                PhraseRow(phrase: phrase)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.vertical, 8)

                
            }
            .padding()
        }
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
    @Published var phonemeSearchTerms: [String] = []
    @Published var phonemeSearchResults: [Phrase] = []
    
    @Published var phonemeQueue: [Phrase] = []
    @Published var grabbedPhrase: Phrase? = nil

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
    
    func getRandomPhonemes() {
        let a = Int.random(in: 0..<user.phonemeScores.count)
        let b = Int.random(in: 0..<user.phonemeScores.count)
        let c = Int.random(in: 0..<user.phonemeScores.count)
        
        let phoneme1 = user.phonemeScores[a].phoneme
        let phoneme2 = user.phonemeScores[b].phoneme
        let phoneme3 = user.phonemeScores[c].phoneme
        
        phonemeSearchTerms = [phoneme1, phoneme2, phoneme3]
    }
    
    func getLeastAttemptedPhonemes() {
        phonemeSearchTerms = user.getLeastAttemptedPhonemes()
    }
    
    func getMostUrgentPhonemes() {
        phonemeSearchTerms = user.getMostUrgentPhonemes()
    }
    
    func performPhonemeSearch() {
        guard !phonemeSearchTerms.isEmpty else { return }
        
        phonemeSearchResults = DataBankManager.shared.getPhrasesContainingPhoneme(
            phonemeSearchTerms
        )
    }
    
    func progressQueue() {
        grabbedPhrase = user.nextCard()
    }
}



