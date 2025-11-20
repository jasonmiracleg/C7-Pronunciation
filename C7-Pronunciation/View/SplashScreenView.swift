//
//  SplashScreenView.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 19/11/25.
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.darkBlue : Color.accentColor)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Image("splash_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(.bottom, 50)
                    .foregroundColor(.white)
                
                Text("The first step to becoming a good speaker is to just be ***Talkative***.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                .frame(width: 300)
                
                Spacer()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
