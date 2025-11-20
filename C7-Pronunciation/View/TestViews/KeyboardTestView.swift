//
//  KeyboardTestView.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 20/11/25.
//

import SwiftUI

struct KeyboardTestView: View {
    @State private var name = "Taylor"

    var body: some View {
        TextField("Enter your name", text: $name)
            .textFieldStyle(.roundedBorder)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Click me!") {
                        print("Clicked")
                    }
                }
            }
    }
}

#Preview {
    KeyboardTestView()
}
