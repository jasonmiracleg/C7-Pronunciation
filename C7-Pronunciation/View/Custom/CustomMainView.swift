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
    
    @Binding var viewModel: CustomViewModel
    
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
                                .foregroundStyle(Color.interactive)
                                .padding()
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isPresented.toggle()
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.interactive)
                                .padding()
                        }
                    }

                } else {
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
                            .foregroundStyle(Color.interactive)
                            .padding()
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
