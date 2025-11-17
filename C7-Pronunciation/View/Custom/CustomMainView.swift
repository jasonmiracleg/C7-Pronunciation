//
//  CustomMainView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 13/11/25.
//

import SwiftUI

struct CustomMainView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording: Bool = false
    @State private var isDone: Bool = false
    @State var text = ""
    @State var isEnable: Bool = true
    @State private var isPresented: Bool = false
    
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
                            isRecording.toggle()
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
                        if !isRecording {
                            isRecording.toggle()
                            isEnable.toggle()
                        } else {
                            isDone.toggle()
                        }
                    }) {
                        Image(systemName: !isRecording ? "microphone.circle.fill" : "stop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.interactive)
                            .padding()
                    }
                }
                Spacer()
            }
            .fullScreenCover(isPresented: $isPresented) {
                EvaluationView()
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

#Preview {
    CustomMainView()
}
