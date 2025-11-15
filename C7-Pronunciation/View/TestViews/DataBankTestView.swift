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
    
    // MARK: - Search Testing States
    @State private var selectedTab: SearchTab = .randomPicks
    
    // Text search
    @State private var textSearchTerms: [String] = []
    @State private var newTextTerm: String = ""
    @State private var textSearchResults: [Phrase] = []
    @State private var textSearchCategory: PhraseCategory? = nil
    
    // Phoneme search
    @State private var phonemeSearchTerms: [String] = []
    @State private var availablePhonemes: [String] = []
    @State private var phonemeSearchResults: [Phrase] = []
    @State private var phonemeSearchCategory: PhraseCategory? = nil
    
    enum SearchTab: String, CaseIterable {
        case randomPicks = "Random Picks"
        case textSearch = "Text Search"
        case phonemeSearch = "Phoneme Search"
    }
    
    // Common IPA phonemes for testing
    let ipaPhonemes = [
        "p", "b", "t", "d", "k", "ɡ",
        "m", "n", "ŋ",
        "f", "v", "θ", "ð", "s", "z", "ʃ", "ʒ", "h",
        "tʃ", "dʒ",
        "l", "r", "j", "w",
        "i", "ɪ", "e", "ɛ", "æ",
        "ə", "ʌ", "ɑ", "ɔ", "o", "ʊ", "u",
        "aɪ", "aʊ", "eɪ", "oʊ", "ɔɪ"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                switch selectedTab {
                case .randomPicks:
                    randomPicksView
                case .textSearch:
                    textSearchView
                case .phonemeSearch:
                    phonemeSearchView
                }
            }
            .navigationTitle("Phoneme Data Bank")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshPicks) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                refreshPicks()
                setupPhonemeSelection()
            }
        }
    }
    
    // MARK: - Random Picks View
    
    var randomPicksView: some View {
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
    }
    
    // MARK: - Text Search View
    
    var textSearchView: some View {
        VStack(spacing: 0) {
            // Search controls
            VStack(spacing: 16) {
                // Category filter
                Picker("Category Filter", selection: $textSearchCategory) {
                    Text("All Categories").tag(nil as PhraseCategory?)
                    ForEach([PhraseCategory.formal, .informal, .userAdded], id: \.self) { category in
                        Text(category.displayName).tag(category as PhraseCategory?)
                    }
                }
                .pickerStyle(.segmented)
                
                // Add new term
                HStack {
                    TextField("Add search term...", text: $newTextTerm)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(addTextTerm)
                    
                    Button(action: addTextTerm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newTextTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                // Current search terms (ranked by importance)
                if !textSearchTerms.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search Terms (ranked by importance)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(textSearchTerms.enumerated()), id: \.offset) { index, term in
                                    HStack(spacing: 4) {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(term)
                                        Button(action: { removeTextTerm(at: index) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                // Search button
                Button(action: performTextSearch) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search Text (Weighted)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(textSearchTerms.isEmpty)
                
                // Clear button
                if !textSearchTerms.isEmpty {
                    Button(action: clearTextSearch) {
                        Text("Clear All")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            
            // Results
            List {
                Section(header: HStack {
                    Text("Results")
                    Spacer()
                    Text("\(textSearchResults.count) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }) {
                    if textSearchResults.isEmpty {
                        Text("No results. Add search terms and tap Search.")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    ForEach(Array(textSearchResults.enumerated()), id: \.element.id) { index, phrase in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                Spacer()
                            }
                            PhraseRow(phrase: phrase)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    // MARK: - Phoneme Search View
    
    var phonemeSearchView: some View {
        VStack(spacing: 0) {
            // Search controls
            VStack(spacing: 16) {
                // Category filter
                Picker("Category Filter", selection: $phonemeSearchCategory) {
                    Text("All Categories").tag(nil as PhraseCategory?)
                    ForEach([PhraseCategory.formal, .informal, .userAdded], id: \.self) { category in
                        Text(category.displayName).tag(category as PhraseCategory?)
                    }
                }
                .pickerStyle(.segmented)
                
                // Available phonemes to add
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Phonemes (tap to add)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(availablePhonemes, id: \.self) { phoneme in
                                Button(action: { addPhoneme(phoneme) }) {
                                    Text(phoneme)
                                        .font(.system(size: 18, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .disabled(phonemeSearchTerms.contains(phoneme))
                            }
                            
                            Button(action: setupPhonemeSelection) {
                                Image(systemName: "arrow.clockwise")
                                    .padding(8)
                            }
                        }
                    }
                }
                
                // Current search phonemes (ranked by importance)
                if !phonemeSearchTerms.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search Phonemes (ranked by importance)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(phonemeSearchTerms.enumerated()), id: \.offset) { index, phoneme in
                                    HStack(spacing: 4) {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(phoneme)
                                            .font(.system(size: 18, design: .monospaced))
                                        Button(action: { removePhoneme(at: index) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                // Search button
                Button(action: performPhonemeSearch) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search Phonemes (Weighted)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(phonemeSearchTerms.isEmpty)
                
                // Clear button
                if !phonemeSearchTerms.isEmpty {
                    Button(action: clearPhonemeSearch) {
                        Text("Clear All")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            
            // Results
            List {
                Section(header: HStack {
                    Text("Results")
                    Spacer()
                    Text("\(phonemeSearchResults.count) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }) {
                    if phonemeSearchResults.isEmpty {
                        Text("No results. Add phonemes and tap Search.")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    ForEach(Array(phonemeSearchResults.enumerated()), id: \.element.id) { index, phrase in
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
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    // MARK: - Random Picks Actions
    
    func submitUserPhrase() {
        // Basic validation
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        isGenerating = true
        
        // Perform the add operation (Espeak generation + DB Save)
        DispatchQueue.main.async {
            DataBankManager.shared.addUserPhrase(trimmedInput)
            
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
        let picks = DataBankManager.shared.getRandomPhrasePicks()
        self.formalPicks = picks.formal
        self.informalPicks = picks.informal
        
        // 2. Get ALL user added phrases (sorted by newest)
        let userCategory = PhraseCategory.userAdded.rawValue
        let descriptor = FetchDescriptor<Phrase>(
            predicate: #Predicate { $0.categoryRawValue == userCategory },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let userPhrases = try DataBankManager.shared.modelContainer.mainContext.fetch(descriptor)
            self.userAddedPicks = userPhrases
        } catch {
            print("Failed to fetch user phrases: \(error)")
            self.userAddedPicks = []
        }
    }
    
    // MARK: - Text Search Actions
    
    func addTextTerm() {
        let trimmed = newTextTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !textSearchTerms.contains(trimmed) else { return }
        
        textSearchTerms.append(trimmed)
        newTextTerm = ""
    }
    
    func removeTextTerm(at index: Int) {
        textSearchTerms.remove(at: index)
        // Clear results when terms change
        textSearchResults = []
    }
    
    func performTextSearch() {
        guard !textSearchTerms.isEmpty else { return }
        
        textSearchResults = DataBankManager.shared.getPhrasesContainingText(
            textSearchTerms,
            category: textSearchCategory
        )
    }
    
    func clearTextSearch() {
        textSearchTerms = []
        textSearchResults = []
        newTextTerm = ""
    }
    
    // MARK: - Phoneme Search Actions
    
    func setupPhonemeSelection() {
        // Pick 10 random phonemes from the IPA set
        availablePhonemes = Array(ipaPhonemes.shuffled().prefix(10))
    }
    
    func addPhoneme(_ phoneme: String) {
        guard !phonemeSearchTerms.contains(phoneme) else { return }
        phonemeSearchTerms.append(phoneme)
    }
    
    func removePhoneme(at index: Int) {
        phonemeSearchTerms.remove(at: index)
        // Clear results when phonemes change
        phonemeSearchResults = []
    }
    
    func performPhonemeSearch() {
        guard !phonemeSearchTerms.isEmpty else { return }
        
        phonemeSearchResults = DataBankManager.shared.getPhrasesContainingPhoneme(
            phonemeSearchTerms,
            category: phonemeSearchCategory
        )
    }
    
    func clearPhonemeSearch() {
        phonemeSearchTerms = []
        phonemeSearchResults = []
        setupPhonemeSelection()
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
        .modelContainer(DataBankManager.shared.modelContainer)
}
