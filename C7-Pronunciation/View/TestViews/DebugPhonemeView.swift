//
//  DebugPhonemeView.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 21/11/25.
//


import SwiftUI

struct DebugPhonemeView: View {
    @EnvironmentObject var user: User
    @State private var sortOption = 0 // 0: Score, 1: Attempts, 2: Urgency
    
    var sortedPhonemes: [PhonemeRecommendationScore] {
        switch sortOption {
        case 1: return user.phonemeScores.sorted { $0.attempts > $1.attempts } // Most tried
        case 2: return user.phonemeScores.sorted { $0.lastUpdated > $1.lastUpdated } // Recently updated
        default: return user.phonemeScores.sorted { $0.score < $1.score } // Lowest score (Urgent)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Queue Status") {
                    LabeledContent("Queue Size", value: "\(user.phraseQueue.count)")
                    if let first = user.phraseQueue.first {
                        Text("Next: \(first.text)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Phoneme Data") {
                    ForEach(sortedPhonemes, id: \.id) { item in
                        HStack {
                            Text(item.phoneme)
                                .font(.title2)
                                .bold()
                                .frame(width: 50)
                            
                            VStack(alignment: .leading) {
                                ProgressView(value: item.score)
                                    .tint(getColor(score: item.score))
                                HStack {
                                    Text("Score: \(Int(item.score * 100))%")
                                    Spacer()
                                    Text("Att: \(item.attempts)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("God Mode 🧠")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Sort", selection: $sortOption) {
                        Text("Worst Score").tag(0)
                        Text("Most Attempts").tag(1)
                        Text("Recent").tag(2)
                    }
                }
            }
        }
    }
    
    func getColor(score: Double) -> Color {
        if score < 0.4 { return .red }
        if score < 0.7 { return .orange }
        return .green
    }
}