//
//  DataBankTestView.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 13/11/25.
//


import SwiftUI
import SwiftData

struct DataBankTestView: View {
    @State private var formalPicks: [Phrase] = []
    @State private var informalPicks: [Phrase] = []
    @State private var userAddedPicks: [Phrase] = []
    
    @State private var searchResults: [Phrase] = []
    @State private var didSearch = false

    var body: some View {
        NavigationStack {
            List {
                // formal
                Section(header: Text(PhraseCategory.formal.displayName)) {
                    if formalPicks.isEmpty {
                        Text("No formal phrases found.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(formalPicks, id: \.id) { phrase in
                        PhraseRow(phrase: phrase)
                    }
                }
                
                // informal
                Section(header: Text(PhraseCategory.informal.displayName)) {
                    if informalPicks.isEmpty {
                        Text("No informal phrases found.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(informalPicks, id: \.id) { phrase in
                        PhraseRow(phrase: phrase)
                    }
                }
                
                // user-added (for testing later)
                Section(header: Text(PhraseCategory.userAdded.displayName)) {
                    if userAddedPicks.isEmpty {
                        Text("No user-added phrases yet.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(userAddedPicks, id: \.id) { phrase in
                        PhraseRow(phrase: phrase)
                    }
                }
                
                // Does nothing, will add later
                if didSearch {
                    Section(header: Text("Search Results")) {
                        if searchResults.isEmpty {
                            Text("No matching phrases found.")
                        }
                        ForEach(searchResults) { phrase in
                            PhraseRow(phrase: phrase)
                        }
                    }
                }
            }
            .navigationTitle("Random Phrases")
            .toolbar {
// TODO: Implement search (should take one or morte strings or phonemes, return the list of all matches)
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button(action: testSearch) {
//                        Image(systemName: "magnifyingglass")
//                    }
//                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshPicks) {
                        Image(systemName: "dice")
                    }
                }
            }
            .onAppear(perform: refreshPicks)
        }
    }
    
    // Gets 3 random phrases
    func refreshPicks() {
        let picks = SwiftDataManager.shared.getRandomPhrasePicks()
        
        self.formalPicks = picks.formal
        self.informalPicks = picks.informal
        self.userAddedPicks = picks.userAdded
        
        self.didSearch = false
        self.searchResults = []
    }
    
    // TODO: Implement search.
    func testSearch() {
        let terms = ["you", "assist"]
        self.searchResults = SwiftDataManager.shared.getPhrasesContainingText(
            terms,
            category: .formal
        )
        self.didSearch = true
    }
}

// Test view for phrases
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
        .modelContainer(for: Phrase.self, inMemory: true)
}
