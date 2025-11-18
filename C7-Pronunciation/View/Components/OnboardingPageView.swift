//
//  OnboardingPageView.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 14/11/25.
//

import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer() // Pushes content down from the top

            // Placeholder for the image
            Image(page.imageName)
                .resizable()
                .frame(width: .infinity, height: 200)
                .scaledToFit()
                .padding(.horizontal)
            
            // Text content
            VStack(spacing: 15) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}
#Preview {
    OnboardingPageView(
        page: OnboardingPage(
            imageName: "speaker.wave.2.fill",
            title: "Speak Confidently at Workplace",
            description: "Master your English pronunciation for your career, anytime and anywhere."
        )
    )
}
