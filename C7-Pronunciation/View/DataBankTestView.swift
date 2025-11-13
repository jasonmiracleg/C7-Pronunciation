//
//  DataBankTestView.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//


import SwiftUI
import SwiftData

struct DataBankTestView: View {
    // State for our random picks
    @State private var formalPicks: [Phrase] = []
    @State private var informalPicks: [Phrase] = []
    @State private var userAddedPicks: [Phrase] = []
    
    // State for the user input
    @State private var userInput: String = ""
    @State private var isGenerating: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // MARK: - Input Section
                VStack(spacing: 12) {
                    TextField("Enter a phrase to convert...", text: $userInput)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .submitLabel(.done)
                        .onSubmit(submitUserPhrase)
                    
                    Button(action: submitUserPhrase) {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Generate & Add")
                                .bold()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
                .padding(.vertical)
                .background(Color(uiColor: .secondarySystemBackground))
                
                // MARK: - Data List
                List {
                    // Section for User Added phrases (Prioritized at top)
                    Section(header: Text(PhraseCategory.userAdded.displayName)) {
                        if userAddedPicks.isEmpty {
                            Text("No user-added phrases yet.")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        ForEach(userAddedPicks, id: \.id) { phrase in
                            PhraseRow(phrase: phrase)
                        }
                    }
                    
                    // Section for Formal phrases
                    Section(header: Text(PhraseCategory.formal.displayName)) {
                        ForEach(formalPicks, id: \.id) { phrase in
                            PhraseRow(phrase: phrase)
                        }
                    }
                    
                    // Section for Informal phrases
                    Section(header: Text(PhraseCategory.informal.displayName)) {
                        ForEach(informalPicks, id: \.id) { phrase in
                            PhraseRow(phrase: phrase)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Phoneme Data Bank")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshPicks) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear(perform: refreshPicks)
        }
    }
    
    // MARK: - Actions
    
    func submitUserPhrase() {
        // Basic validation
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        isGenerating = true
        
        // Perform the add operation (Espeak generation + DB Save)
        // We use DispatchQueue to ensure UI updates flow correctly if Espeak takes a moment
        DispatchQueue.main.async {
            SwiftDataManager.shared.addUserPhrase(trimmedInput)
            
            // Clear input
            userInput = ""
            isGenerating = false
            
            // Refresh the view to show the new item
            refreshPicks()
        }
    }
    
    /// Refreshes the list.
    /// For "User Added", we fetch ALL of them (or the last 10) so you can see your input.
    /// For others, we keep the "random 3" logic.
    func refreshPicks() {
        // 1. Get random picks for default categories
        let picks = SwiftDataManager.shared.getRandomPhrasePicks()
        self.formalPicks = picks.formal
        self.informalPicks = picks.informal
        
        // 2. Get ALL user added phrases (sorted by newest)
        // We manually fetch this so we can see what we just added
        let userCategory = PhraseCategory.userAdded.rawValue
        let descriptor = FetchDescriptor<Phrase>(
            predicate: #Predicate { $0.categoryRawValue == userCategory },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let userPhrases = try SwiftDataManager.shared.modelContainer.mainContext.fetch(descriptor)
            self.userAddedPicks = userPhrases
        } catch {
            print("Failed to fetch user phrases: \(error)")
            self.userAddedPicks = []
        }
    }
}

// Reuse your existing PhraseRow, or ensure it is defined:
struct PhraseRow: View {
    var phrase: Phrase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phrase.text)
                .font(.headline)
            Text(phrase.phonemes)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DataBankTestView()
        .modelContainer(SwiftDataManager.shared.modelContainer)
}
