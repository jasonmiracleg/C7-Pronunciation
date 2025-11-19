//
//  CustomMainView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 13/11/25.
//

import SwiftUI

struct CustomMainView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDone: Bool = false
    @State var text = ""
    @State var isEnable: Bool = true
    @State private var isPresented: Bool = false
    
    @ObservedObject var viewModel: CustomViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                Text("Write Anything on Your Mind Below")
                Text("Hit Record to Check Your Pronunciation")
                
                Spacer()
                
                TextEditor(text: $text)
                    .customStyleEditor(placeholder: "Write Here", userInput: $text, isEnabled: isEnable)
                    .frame(height: 350)
                    .padding(.horizontal, 16)
                
                Spacer()
                
                if isDone {
                    HStack {
                        Button(action: {
                            isEnable.toggle()
                            isDone.toggle()
                        }) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.accentColor) // Ensure this color exists or use .accentColor
                                .padding()
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isPresented.toggle()
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.accentColor)
                                .padding()
                        }
                    }

                } else {
                    // Encapsulate Mic and Waveform in a VStack
                    VStack(spacing: 16) {
                        
                        // Show waveform only when recording
                        if viewModel.isRecording {
                            WaveformView(levels: viewModel.audioLevels)
                                .padding(.horizontal, 40)
                                .transition(.opacity.animation(.easeInOut))
                        } else {
                            // Placeholder to keep layout stable (optional, remove if you want button to jump)
                            Color.clear.frame(height: 50)
                        }
                        
                        Button(action: {
                            if !viewModel.isRecording {
                                viewModel.setTargetSentence(text)
                                viewModel.toggleRecording()
                                
                                isEnable.toggle()
                            } else {
                                viewModel.toggleRecording()
                                isDone.toggle()
                            }
                        }) {
                            Image(systemName: !viewModel.isRecording ? "microphone.circle.fill" : "stop.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.accentColor)
                                .padding()
                                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Spacer()
            }
            .fullScreenCover(isPresented: $isPresented) {
                EvaluationView()
                    .environmentObject(viewModel)
            }
            .navigationTitle("Custom")
            .navigationBarTitleDisplayMode(.inline)
            .padding(.horizontal)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
