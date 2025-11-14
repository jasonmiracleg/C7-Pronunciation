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
    
    var body: some View {
        NavigationStack {
            VStack() {
                Text("Write Anything on Your Mind Below")
                Text("Hit Record to Check Your Pronunciation")
                
                Spacer()
                
                TextEditor(text: $text)
                    .customStyleEditor(placeholder: "Write Here", userInput: $text)
                    .frame(height: 350)
                    .padding(.horizontal, 16)
                
                Spacer()
                
                if isDone {
                    HStack {
                        Button(action: {

                        }) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.interactive)
                                .padding()
                        }
                        
                        Spacer()
                        
                        Button(action: {

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
            .padding()
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Custom")
                }
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
