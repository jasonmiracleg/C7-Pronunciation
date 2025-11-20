import SwiftUI

struct CustomMainView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDone: Bool = false
    @State var text = ""
    @State var isEnable: Bool = true
    @State private var isPresented: Bool = false
    @FocusState private var focusField: Bool
    @State private var showEvaluationView: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    
    @ObservedObject var viewModel: CustomViewModel
    
    // MARK: - Word Limit Logic
    let wordLimit = 100
    
    var currentWordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var showTeleprompter: Bool {
        return viewModel.isRecording || viewModel.isLoading || isDone
    }
    
    var showWaveform: Bool {
        return viewModel.isRecording || viewModel.isLoading
    }
    
    var showMicButton: Bool {
        return !viewModel.isLoading
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // MARK: - Content Area
                    if showTeleprompter {
                        TeleprompterDisplayView(
                            sentences: viewModel.teleprompterSentences,
                            currentSentenceIndex: viewModel.currentSentenceIndex,
                            shouldAutoScroll: viewModel.shouldAutoScroll,
                            onUserScroll: {
                                viewModel.userIsScrolling()
                            }
                        )
                        .frame(height: 500)
                        .padding(.horizontal, 6)
                        .transition(.opacity)
                    } else {
                        VStack(spacing: 4) {
                            Text("Write Anything on Your Mind Below")
                            Text("Hit Record to Check Your Pronunciation")
                        }
                        .padding(.bottom, 16)
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            TextEditor(text: $text)
                                .customStyleEditor(placeholder: "Write Here", userInput: $text, isEnabled: isEnable)
                                .frame(height: 350)
                                .focused($focusField)
                                .onChange(of: text) { oldValue, newValue in
                                    let words = newValue.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                                    if words.count >= wordLimit {
                                        let truncatedWords = words.prefix(wordLimit)
                                        text = truncatedWords.joined(separator: " ")
                                    }
                                }
                                .submitLabel(.done)
                                .onSubmit {
                                    focusField = false
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
                        .transition(.opacity)
                    }
                    
                    Spacer()
                    
                    if isDone {
                        HStack {
                            Button(action: {
                                isEnable.toggle()
                                isDone.toggle()
                                viewModel.resetTeleprompter()
                            }) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(Color.white)
                            }
                            .glassEffect( .regular.tint(Color.accentColor))
                            
                            Spacer()
                            
                            Button(action: {
                                showEvaluationView = true
                            }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.white)
                            }
                            .glassEffect( .regular.tint(Color.accentColor))
                        }
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))

                    } else {
                        if showWaveform {
                            WaveformView(levels: viewModel.audioLevels)
                                .padding(.horizontal, 40)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Color.clear.frame(height: 50)
                        }
                        
                        Button(action: {
                            if !viewModel.isRecording {
                                viewModel.setTargetSentence(text)
                                viewModel.prepareTeleprompter(with: text)
                                viewModel.toggleRecording()
                                isEnable.toggle()
                            } else {
                                viewModel.toggleRecording()
                            }
                        }) {
                            Image(systemName: (!viewModel.isRecording && !viewModel.isLoading) ? "microphone.circle.fill" : "stop.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                        }
                        .glassEffect(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?  .regular.tint(Color.secondary) : .regular.tint(Color.accentColor))
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                    }
                    Spacer()
                }
                
                // Manual keyboard toolbar :(
                VStack {
                    Spacer()
                    
                    // Only show if the keyboard is actually up (height > 0) or the field is focused
                    if focusField && currentWordCount > 0 {
                        HStack {
                            Spacer()
                            Button("Done") {
                                focusField = false
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(.bar.opacity(0.5), in: .capsule)
                            .glassEffect()
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        }
                        .padding(.bottom, keyboardHeight - 20)
                        .padding(.trailing, 10)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: focusField && currentWordCount > 0)
            }
            // MARK: -- Keyboard Dismiss Modifiers
            // Remember keyboard height for device
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    self.keyboardHeight = keyboardFrame.height
                }
            }
            .onTapGesture {
                focusField = false
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            // MARK: -- Eval View Modifiers
            .sheet(isPresented: $viewModel.isLoading) {
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
            .onChange(of: viewModel.isLoading) { oldValue, isLoading in
                if !isLoading && oldValue {
                    if viewModel.hasRecorded {
                        isDone = true
                        showEvaluationView = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showEvaluationView) {
            } content: {
                EvaluationView()
                    .environmentObject(viewModel)
            }
            
            // MARK: -- Actual View Modifiers
            .navigationTitle("Custom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
