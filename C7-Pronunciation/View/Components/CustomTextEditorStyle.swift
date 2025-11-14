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
                            .foregroundColor(Color(UIColor.systemGray2))
                    }
                }
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .scrollContentBackground(.hidden)
                .font(.system(size: 16))
    }
}

extension TextEditor {
    func customStyleEditor(placeholder: String, userInput: Binding<String>) -> some View {
        self.modifier(CustomTextEditorStyle(placeholder: placeholder, text: userInput))
    }
}
