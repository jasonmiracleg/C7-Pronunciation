//
//  CustomTextEditorStyle.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 14/11/25.
//

import SwiftUI

struct CustomTextEditorStyle: ViewModifier {
    
    let placeholder: String
    @Binding var text: String
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(15)
            .background(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .lineSpacing(10)
                        .padding(20)
                        .padding(.top, 2)
                        .font(.system(size: 14))
                        .foregroundColor(isEnabled ?
                                         Color(UIColor.systemGray2) :
                                         Color(UIColor.systemGray3))
                }
            }
            .textInputAutocapitalization(.none)
            .autocorrectionDisabled()
            .foregroundColor(isEnabled ? .primary : .primary.opacity(0.8))
            .background(
                isEnabled ?
                Color(UIColor.systemGray6) :
                Color(UIColor.systemGray5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .scrollContentBackground(.hidden)
            .font(.system(size: 16))
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.6)
    }
}


extension TextEditor {
    func customStyleEditor(placeholder: String, userInput: Binding<String>, isEnabled: Bool = true) -> some View {
        self.modifier(CustomTextEditorStyle(placeholder: placeholder, text: userInput, isEnabled: isEnabled))
    }
}
