//
//  PageIndicatorView.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 14/11/25.
//

import SwiftUI

struct PageIndicatorView: View {
    let pageCount: Int
    @Binding var currentPageIndex: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(currentPageIndex == index ? Color.accentColor : Color(.systemGray4))
                    .frame(width: currentPageIndex == index ? 20 : 8, height: 8)
            }
        }
        .animation(.default, value: currentPageIndex) 
    }
}
