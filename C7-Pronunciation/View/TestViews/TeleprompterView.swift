import SwiftUI
import Speech
import AVFoundation
import Combine

struct TeleprompterView: View {
    @StateObject private var viewModel = TeleprompterViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Input Section
            if !viewModel.isRecording {
                VStack {
                    Text("Enter Your Script")
                        .font(.headline)
                        .padding(.top)
                    
                    TextEditor(text: $viewModel.scriptText)
                        .frame(height: 150)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Recording Control
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.title)
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isRecording ? Color.red : Color.blue)
                .cornerRadius(15)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .disabled(!viewModel.hasPermission || (viewModel.scriptText.isEmpty && !viewModel.isRecording))
            
            // Permission Status
            if !viewModel.hasPermission {
                Text("Microphone permission required")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom, 5)
            }
            
            // Debug: Show recognized text
            if viewModel.isRecording && !viewModel.recognizedText.isEmpty {
                VStack(spacing: 4) {
                    Text("Recognized (Sentence \(viewModel.currentSentenceIndex + 1)/\(viewModel.sentences.count)):")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(viewModel.recognizedText)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
            }
            
            // Script Display with Highlighting
            if viewModel.isRecording || viewModel.hasRecorded {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(Array(viewModel.sentences.enumerated()), id: \.offset) { index, sentence in
                                SentenceView(
                                    sentence: sentence,
                                    isHighlighted: index == viewModel.currentSentenceIndex,
                                    isPassed: index < viewModel.currentSentenceIndex
                                )
                                .id(index)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.currentSentenceIndex) { newIndex in
                        if viewModel.shouldAutoScroll {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            viewModel.userIsScrolling()
                        }
                    )
                }
                .background(Color.black)
            } else {
                Spacer()
                Text("Enter your script above and press record to begin")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            viewModel.requestPermissions()
        }
    }
}

struct SentenceView: View {
    let sentence: String
    let isHighlighted: Bool
    let isPassed: Bool
    
    var body: some View {
        Text(sentence)
            .font(.system(size: 24, weight: isHighlighted ? .bold : .regular))
            .foregroundColor(textColor)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }
    
    private var textColor: Color {
        if isHighlighted {
            return .white
        } else if isPassed {
            return .gray
        } else {
            return Color.white.opacity(0.6)
        }
    }
    
    private var backgroundColor: Color {
        if isHighlighted {
            return Color.blue.opacity(0.3)
        } else {
            return Color.clear
        }
    }
}

@MainActor
class TeleprompterViewModel: ObservableObject {
    @Published var scriptText: String = ""
    @Published var isRecording: Bool = false
    @Published var hasPermission: Bool = false
    @Published var hasRecorded: Bool = false
    @Published var sentences: [String] = []
    @Published var currentSentenceIndex: Int = 0
    @Published var shouldAutoScroll: Bool = true
    @Published var recognizedText: String = ""
    
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var autoScrollTimer: Timer?
    private var allRecognizedText: String = ""
    private var lastMatchedWordCount: Int = 0
    private var cumulativeWordBuffer: [String] = []
    private var recordingStartTime: Date?
    private let averageWordsPerSecond: Double = 2.5 // Average speaking rate
    
    init() {
        // Use enhanced recognition with on-device processing
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.defaultTaskHint = .dictation
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                self?.hasPermission = authStatus == .authorized
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                if !allowed {
                    self?.hasPermission = false
                }
            }
        }
    }
    
    func startRecording() {
        // Parse sentences from script
        sentences = parseSentences(from: scriptText)
        currentSentenceIndex = 0
        shouldAutoScroll = true
        isRecording = true
        hasRecorded = true
        allRecognizedText = ""
        recognizedText = ""
        lastMatchedWordCount = 0
        cumulativeWordBuffer = []
        recordingStartTime = Date()
        
        print("📝 Starting recording with \(sentences.count) sentences")
        for (i, sentence) in sentences.enumerated() {
            print("  [\(i)]: \(sentence)")
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio session setup failed: \(error)")
            return
        }
        
        // Setup speech recognition
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine,
              let inputNode = audioEngine.inputNode as AVAudioInputNode? else {
            print("❌ Failed to get audio engine or input node")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Failed to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Enable on-device recognition for better performance and privacy
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false // Allow cloud for better accuracy with varied pronunciations
        }
        
        print("✅ Starting recognition task...")
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                print("🎤 Recognized: \(spokenText)")
                
                Task { @MainActor in
                    self.recognizedText = spokenText
                    self.allRecognizedText = spokenText
                    self.matchSpokenTextToSentence(spokenText: spokenText)
                }
            }
            
            if let error = error {
                print("❌ Recognition error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
        
        // Setup audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("✅ Audio engine started successfully")
        } catch {
            print("❌ Audio engine failed to start: \(error)")
        }
    }
    
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
    }
    
    private func parseSentences(from text: String) -> [String] {
        // Split by sentence boundaries
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var sentences: [String] = []
        
        // Use regex to split by sentence boundaries (., !, ?, or newlines)
        let pattern = "[.!?\\n]+"
        let components = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        
        for component in components {
            let cleaned = component.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty {
                sentences.append(cleaned)
            }
        }
        
        return sentences.isEmpty ? [text] : sentences
    }
    
    private func matchSpokenTextToSentence(spokenText: String) {
        let normalizedSpoken = normalizeText(spokenText)
        let currentWords = normalizedSpoken.components(separatedBy: " ").filter { !$0.isEmpty }
        
        // Update cumulative buffer only with new words
        if currentWords.count > cumulativeWordBuffer.count {
            cumulativeWordBuffer = currentWords
        }
        
        // Calculate time-based unlocking: which sentences should be "unlocked" for jumping
        let elapsedTime = Date().timeIntervalSince(recordingStartTime ?? Date())
        let wordsSpokenByTime = elapsedTime * averageWordsPerSecond
        
        print("🔍 Words: \(currentWords.count) | Time: \(String(format: "%.1f", elapsedTime))s | Current: [\(currentSentenceIndex)]")
        print("   Spoken: \(normalizedSpoken)")
        
        // CRITICAL: Never go backwards
        let minAllowedIndex = currentSentenceIndex
        
        // Get current sentence info
        let currentSentence = sentences[currentSentenceIndex]
        let currentSentenceWords = normalizeText(currentSentence).components(separatedBy: " ").filter { !$0.isEmpty }
        
        print("   📖 Current sentence [\(currentSentenceIndex)]: \(currentSentence)")
        print("   📖 Words in sentence: \(currentSentenceWords.count)")
        
        // STRATEGY 1: Check if we've COMPLETED the current sentence
        // Look at the end of what we've spoken and see if it matches the end of current sentence
        // Use adaptive thresholds based on sentence length
        let isShortSentence = currentSentenceWords.count <= 5
        let isMediumSentence = currentSentenceWords.count > 5 && currentSentenceWords.count <= 12
        let isLongSentence = currentSentenceWords.count > 12
        
        // For short sentences, check more words; for long sentences, fewer is fine
        let sentenceEndCheckLength = isShortSentence ? min(currentSentenceWords.count, 3) :
                                     isMediumSentence ? min(currentSentenceWords.count, 4) :
                                     min(currentSentenceWords.count, 5)
        
        if sentenceEndCheckLength >= 2 && currentWords.count >= sentenceEndCheckLength {
            let currentSentenceEnd = Array(currentSentenceWords.suffix(sentenceEndCheckLength))
            let spokenEnd = Array(currentWords.suffix(sentenceEndCheckLength))
            
            var endMatches = 0
            for i in 0..<sentenceEndCheckLength {
                if currentSentenceEnd[i] == spokenEnd[i] || fuzzyMatch(currentSentenceEnd[i], spokenEnd[i]) {
                    endMatches += 1
                }
            }
            
            let endMatchRatio = Double(endMatches) / Double(sentenceEndCheckLength)
            print("   🏁 End match: \(endMatches)/\(sentenceEndCheckLength) = \(endMatchRatio)")
            
            // Adaptive threshold based on sentence length
            let endMatchThreshold = isShortSentence ? 0.8 : 0.7
            
            // If we've spoken the end of the current sentence, move to next!
            if endMatchRatio >= endMatchThreshold && currentSentenceIndex + 1 < sentences.count {
                print("   ✅ SENTENCE COMPLETE! Moving to next sentence.")
                currentSentenceIndex += 1
                resetAutoScrollTimer()
                return
            }
        }
        
        // STRATEGY 2: Check if we're clearly speaking the NEXT sentence (not current)
        if currentSentenceIndex + 1 < sentences.count {
            let nextSentence = sentences[currentSentenceIndex + 1]
            let nextSentenceWords = normalizeText(nextSentence).components(separatedBy: " ").filter { !$0.isEmpty }
            
            // Check if recent words match the BEGINNING of next sentence
            // For longer sentences, we need more words matched; for shorter, fewer is ok
            let nextSentenceLength = nextSentenceWords.count
            let checkLength = min(nextSentenceWords.count, currentWords.count, nextSentenceLength <= 5 ? 3 : 5)
            let minWordsNeeded = nextSentenceLength <= 5 ? 2 : 3
            
            if checkLength >= minWordsNeeded {
                let nextSentenceStart = Array(nextSentenceWords.prefix(checkLength))
                let spokenRecent = Array(currentWords.suffix(checkLength))
                
                var startMatches = 0
                for i in 0..<checkLength {
                    if nextSentenceStart[i] == spokenRecent[i] || fuzzyMatch(nextSentenceStart[i], spokenRecent[i]) {
                        startMatches += 1
                    } else {
                        break // Stop at first mismatch for start-of-sentence matching
                    }
                }
                
                let startMatchRatio = Double(startMatches) / Double(checkLength)
                print("   ⏭️  Next sentence start match: \(startMatches)/\(checkLength) = \(startMatchRatio)")
                
                // Must match at least the minimum words needed AND have good ratio
                let absoluteMatchThreshold = minWordsNeeded
                let ratioThreshold = 0.7
                
                if startMatches >= absoluteMatchThreshold && startMatchRatio >= ratioThreshold {
                    print("   ✅ SPEAKING NEXT SENTENCE! Moving forward.")
                    currentSentenceIndex += 1
                    resetAutoScrollTimer()
                    return
                }
            }
        }
        
        // STRATEGY 3: Progressive matching - how far through current sentence are we?
        // Match the spoken words against the current sentence from the beginning
        var matchedWordsInCurrent = 0
        let maxCheck = min(currentWords.count, currentSentenceWords.count)
        
        for i in 0..<maxCheck {
            let spokenIndex = currentWords.count - maxCheck + i
            if spokenIndex >= 0 && spokenIndex < currentWords.count {
                if currentWords[spokenIndex] == currentSentenceWords[i] ||
                   fuzzyMatch(currentWords[spokenIndex], currentSentenceWords[i]) {
                    matchedWordsInCurrent += 1
                } else {
                    // Allow 1 mismatch but then stop counting
                    if matchedWordsInCurrent > i - 2 {
                        break
                    }
                }
            }
        }
        
        let currentProgress = Double(matchedWordsInCurrent) / Double(max(currentSentenceWords.count, 1))
        let wordsRemaining = currentSentenceWords.count - matchedWordsInCurrent
        
        print("   📊 Progress in current: \(matchedWordsInCurrent)/\(currentSentenceWords.count) = \(currentProgress)")
        print("   📊 Words remaining: \(wordsRemaining)")
        
        // Use BOTH percentage AND absolute word count
        // For short sentences: need high percentage (85%)
        // For medium sentences: 75% OR only 3 words left
        // For long sentences: 70% OR only 4 words left
        var shouldAdvanceByProgress = false
        
        if isShortSentence {
            shouldAdvanceByProgress = currentProgress >= 0.85 || wordsRemaining <= 1
        } else if isMediumSentence {
            shouldAdvanceByProgress = currentProgress >= 0.75 || wordsRemaining <= 2
        } else { // long sentence
            shouldAdvanceByProgress = currentProgress >= 0.65 || wordsRemaining <= 3
        }
        
        if shouldAdvanceByProgress && currentSentenceIndex + 1 < sentences.count {
            print("   ✅ Near end of sentence (progress: \(currentProgress), remaining: \(wordsRemaining))! Moving to next.")
            currentSentenceIndex += 1
            resetAutoScrollTimer()
            return
        }
        
        // STRATEGY 4: Time-based jump forward (if we're stuck due to misrecognition)
        // Calculate which sentence we SHOULD be on based on time
        var cumulativeWordCounts: [Int] = []
        var totalWords = 0
        for sentence in sentences {
            let words = normalizeText(sentence).components(separatedBy: " ").filter { !$0.isEmpty }
            totalWords += words.count
            cumulativeWordCounts.append(totalWords)
        }
        
        var expectedSentenceByTime = currentSentenceIndex
        for (index, wordCount) in cumulativeWordCounts.enumerated() {
            if Double(wordCount) <= wordsSpokenByTime {
                expectedSentenceByTime = index
            } else {
                break
            }
        }
        
        print("   ⏰ Expected sentence by time: [\(expectedSentenceByTime)]")
        
        // If we're more than 2 sentences behind where we should be, try to catch up
        if expectedSentenceByTime > currentSentenceIndex + 2 {
            // Check if we're speaking a sentence ahead - do a broad search
            var bestForwardMatch = currentSentenceIndex
            var bestForwardScore = 0.0
            
            for index in (currentSentenceIndex + 1)...min(expectedSentenceByTime, sentences.count - 1) {
                let sentence = sentences[index]
                let sentenceWords = normalizeText(sentence).components(separatedBy: " ").filter { !$0.isEmpty }
                
                // Check if recent words match this sentence's beginning
                let checkLen = min(sentenceWords.count, currentWords.count, 7)
                if checkLen >= 3 {
                    let sentenceStart = Array(sentenceWords.prefix(checkLen))
                    let spokenRecent = Array(currentWords.suffix(checkLen))
                    
                    var matches = 0
                    for i in 0..<checkLen {
                        if sentenceStart[i] == spokenRecent[i] || fuzzyMatch(sentenceStart[i], spokenRecent[i]) {
                            matches += 1
                        }
                    }
                    
                    let score = Double(matches) / Double(checkLen)
                    if score > bestForwardScore {
                        bestForwardScore = score
                        bestForwardMatch = index
                    }
                }
            }
            
            print("   🔍 Forward search: best match [\(bestForwardMatch)] with score \(bestForwardScore)")
            
            if bestForwardScore >= 0.5 && bestForwardMatch > currentSentenceIndex {
                print("   ✅ JUMPING FORWARD to catch up! [\(currentSentenceIndex)] -> [\(bestForwardMatch)]")
                currentSentenceIndex = bestForwardMatch
                resetAutoScrollTimer()
                return
            }
        }
        
        print("   ⏸️  Staying on [\(currentSentenceIndex)]")
    }
    
    private func countMatchingWords(spoken: [String], target: [String]) -> Int {
        var matchCount = 0
        let maxCheck = min(spoken.count, target.count)
        
        for i in 0..<maxCheck {
            if i < spoken.count && i < target.count {
                if spoken[i] == target[i] || fuzzyMatch(spoken[i], target[i]) {
                    matchCount += 1
                } else {
                    // Allow for small deviations but stop counting after 2 mismatches in a row
                    if i > 0 && matchCount < i - 1 {
                        break
                    }
                }
            }
        }
        
        return matchCount
    }
    
    private func calculateWordOverlap(spoken: [String], target: [String]) -> Double {
        if spoken.isEmpty || target.isEmpty {
            return 0.0
        }
        
        let spokenSet = Set(spoken)
        let targetSet = Set(target)
        let intersection = spokenSet.intersection(targetSet)
        
        // Calculate Jaccard similarity
        return Double(intersection.count) / Double(spokenSet.union(targetSet).count)
    }
    
    private func calculateSequenceMatch(spoken: [String], target: [String]) -> Double {
        if spoken.isEmpty || target.isEmpty {
            return 0.0
        }
        
        // Check how many words from the beginning match in sequence
        var matchCount = 0
        let maxCheck = min(spoken.count, target.count)
        
        for i in 0..<maxCheck {
            if spoken[i] == target[i] || fuzzyMatch(spoken[i], target[i]) {
                matchCount += 1
            } else {
                break
            }
        }
        
        return Double(matchCount) / Double(max(spoken.count, target.count))
    }
    
    private func normalizeText(_ text: String) -> String {
        return text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func fuzzyMatch(_ word1: String, _ word2: String) -> Bool {
        // Exact match
        if word1 == word2 {
            return true
        }
        
        // Similar length and high character overlap
        let lengthDiff = abs(word1.count - word2.count)
        if lengthDiff <= 2 {
            let commonChars = Set(word1).intersection(Set(word2)).count
            let threshold = min(word1.count, word2.count) - 2
            if commonChars >= threshold {
                return true
            }
        }
        
        return false
    }
    
    func userIsScrolling() {
        shouldAutoScroll = false
        autoScrollTimer?.invalidate()
        
        // Re-enable auto-scroll after 3 seconds of no scrolling
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.shouldAutoScroll = true
        }
    }
    
    private func resetAutoScrollTimer() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.shouldAutoScroll = true
        }
    }
}

// Preview
struct TeleprompterView_Previews: PreviewProvider {
    static var previews: some View {
        TeleprompterView()
    }
}
