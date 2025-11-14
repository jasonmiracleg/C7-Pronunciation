//
//  BeforeCustomView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 13/11/25.
//

import SwiftUI

struct BeforeCustomView: View {
    @State private var isPresented: Bool = false
    var body: some View {
        VStack {
            Button("Custom Mode") {
                isPresented.toggle()
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            CustomMainView()
        }
    }
}

#Preview {
    BeforeCustomView()
}
