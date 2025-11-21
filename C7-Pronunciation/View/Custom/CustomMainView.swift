import SwiftUI

struct CustomMainView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CustomViewModel
    
    // MARK: - State
    @State private var isDone: Bool = false
    @State var text = ""
    @State var isEnable: Bool = true
    @FocusState private var focusField: Bool
    @State private var showEvaluationView: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    
    // MARK: - Constants
    let wordLimit = 100
    
    // MARK: - Computed Properties
    var currentWordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var showTeleprompter: Bool {
        return viewModel.isRecording || viewModel.isLoading || isDone
    }
    
    var showWaveform: Bool {
        return viewModel.isRecording || viewModel.isLoading
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Main Content
                VStack {
                    Spacer().frame(height: focusField ? 50 : 30)
                        .animation(.easeInOut(duration: 0.3), value: focusField)
                    
                    contentArea
                    
                    Spacer()
                    
                    controlsArea
                }
                
                // Floating Keyboard Toolbar
                keyboardToolbar
            }
            // MARK: -- Modifiers
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                focusField = true
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    self.keyboardHeight = keyboardFrame.height
                }
            }
            .onTapGesture { focusField = false }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            // Loading Sheet
            .sheet(isPresented: $viewModel.isLoading) {
                loadingSheet
            }
            // Logic Trigger
            .onChange(of: viewModel.isLoading) { oldValue, isLoading in
                if !isLoading && oldValue {
                    if viewModel.hasRecorded {
                        isDone = true
                        showEvaluationView = true
                    }
                }
            }
            // Evaluation View
            .fullScreenCover(isPresented: $showEvaluationView) {
                EvaluationView()
                    .environmentObject(viewModel)
            }
            // Navigation
            .navigationTitle("Custom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
    
    // MARK: - Component: Content Area
    @ViewBuilder
    var contentArea: some View {
        if showTeleprompter {
            TeleprompterDisplayView(
                sentences: viewModel.teleprompterSentences,
                currentSentenceIndex: viewModel.currentSentenceIndex,
                shouldAutoScroll: viewModel.shouldAutoScroll,
                onUserScroll: { viewModel.userIsScrolling() }
            )
            .frame(height: 480)
            .padding(.horizontal, 6)
            .transition(.opacity)
        } else {
            ZStack(alignment: .top) {
                VStack(spacing: 4) {
                    Text("Write Anything on Your Mind Below")
                    Text("Hit Record to Check Your Pronunciation")
                }
                .offset(y: focusField ? 20 : -80)
                .zIndex(0)
                
                // 2. Editor (Foreground Layer)
                VStack(alignment: .trailing, spacing: 8) {
                    TextEditor(text: $text)
                        .customStyleEditor(placeholder: "Write Here", userInput: $text, isEnabled: isEnable)
                        .frame(height: 320)
                        .focused($focusField)
                        .onChange(of: text) { _, newValue in
                            let words = newValue.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                            if words.count >= wordLimit {
                                let truncatedWords = words.prefix(wordLimit)
                                text = truncatedWords.joined(separator: " ")
                            }
                        }
                    
                    HStack {
                        Spacer()
                        Text("\(currentWordCount)/\(wordLimit) words")
                            .font(.caption)
                            .foregroundStyle(currentWordCount >= wordLimit ? .red : .secondary)
                            .padding(.trailing, 4)
                    }
                }
                .padding(.horizontal, 24)
                .background(Color(UIColor.systemGroupedBackground))
                .zIndex(1)
            }
            .padding(.top, 90)
            .animation(.easeInOut(duration: 0.3), value: focusField)
            .transition(.opacity)
        }
    }
    
    // MARK: - Component: Controls Area
    @ViewBuilder
    var controlsArea: some View {
        VStack {
            if isDone {
                HStack {
                    // Retry Button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            isEnable.toggle()
                            isDone.toggle()
                        }
                        viewModel.resetTeleprompter()
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.white)
                    }
                    .glassEffect(.regular.tint(Color.accentColor))
                    
                    Spacer()
                    
                    // Check Button
                    Button(action: {
                        showEvaluationView = true
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                    }
                    .glassEffect(.regular.tint(Color.accentColor))
                }
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0).combined(with: .opacity),
                    removal: .scale(scale: 0).combined(with: .opacity)
                ))
                
            } else {
                VStack {
                    if showWaveform {
                        WaveformView(levels: viewModel.audioLevels)
                            .padding(.horizontal, 40)
                            .transition(.scale(scale: 0).combined(with: .opacity))
                    } else {
                        Color.clear.frame(height: 60)
                    }
                    
                    Button(action: {
                        if !viewModel.isRecording {
                            viewModel.setTargetSentence(text)
                            viewModel.prepareTeleprompter(with: text)
                            viewModel.toggleRecording()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                isEnable.toggle()
                            }
                        } else {
                            viewModel.toggleRecording()
                        }
                    }) {
                        Image(systemName: (!viewModel.isRecording && !viewModel.isLoading) ? "microphone.circle.fill" : "stop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                    }
                    .glassEffect(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .regular.tint(Color.secondary) : .regular.tint(Color.accentColor))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0).combined(with: .opacity),
                    removal: .scale(scale: 0).combined(with: .opacity)
                ))
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Component: Keyboard Toolbar
    @ViewBuilder
    var keyboardToolbar: some View {
        VStack {
            Spacer()
            
            if focusField {
                HStack(spacing: 12) {
                    Spacer()
                    
                    // Select All Button
                    if currentWordCount > 0 {
                        Button("Select All") {
                            selectAllText()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(.bar.opacity(0.5), in: .capsule)
                        .glassEffect()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)),
                            removal: .move(edge: .trailing).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    }
                    
                    // Paste Button
                    if UIPasteboard.general.hasStrings {
                        Button("Paste") {
                            if let clipboardText = UIPasteboard.general.string {
                                text += clipboardText
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(.bar.opacity(0.5), in: .capsule)
                        .glassEffect()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.05)),
                            removal: .move(edge: .trailing).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    }
                    
                    // Done Button
                    if currentWordCount > 0 {
                        Button("Done") {
                            focusField = false
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(.bar.opacity(0.5), in: .capsule)
                        .glassEffect()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                            removal: .move(edge: .trailing).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    }
                }
                .padding(.bottom, keyboardHeight - 20)
                .padding(.trailing, 10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: focusField)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentWordCount > 0)
    }

    // MARK: - Helper: Select All Text
    private func selectAllText() {
        // Send notification to select all text in the focused TextEditor
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
        }
    }
    // MARK: - Component: Loading Sheet
    var loadingSheet: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            
            Text("Evaluating Speech...")
                .font(.headline)
            
            Text("Please wait while we analyze your speech.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}
