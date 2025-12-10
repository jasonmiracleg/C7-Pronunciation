//
//  WaveformView.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 19/11/25.
//

import SwiftUI

struct WaveformView: View {
    /// An array of values between 0.0 and 1.0
    var levels: [Float]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            // Calculate height based on level, min height 4 so it doesn't disappear
                            .frame(height: max(geometry.size.height * CGFloat(level), 4))
                    }
                }
            }
        }
        .frame(height: 60) // Fixed height for the container
        .padding(.bottom, 20)
        .animation(.easeOut(duration: 0.05), value: levels)
    }
}
