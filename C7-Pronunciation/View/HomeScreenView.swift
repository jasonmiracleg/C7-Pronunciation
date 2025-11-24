//
//  HomeScreen.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 14/11/25.
//

import SwiftUI

struct HomeScreenView: View {
    @State private var isCustomPresented = false
    @State private var isFlashCardPresented = false
    @EnvironmentObject var user: User
    
    var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 0..<12:
            return "Good Morning!"
        case 12..<17:
            return "Good Afternoon!"
        default:
            return "Good Evening!"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(timeBasedGreeting)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("How would you like to practice today?")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                
                NavigationCard(title: "Flash Cards", imgName: "Home Card_1", desc: "Short, bite-sized chunks of practice. Helps you get used to saying common phrases.", gradientColor: [Color("DarkBlue"), .accentColor]) {
                    isFlashCardPresented.toggle()
                }
                
                NavigationCard(title: "Custom Mode", imgName: "Home Card_2", desc: "Practice with your own script and get a comprehensive review of how you did.", gradientColor: [Color("DarkPurple"), Color("LightPurple")]) {
                    isCustomPresented.toggle()
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .fullScreenCover(isPresented: $isCustomPresented) {
                CustomMainView(viewModel: CustomViewModel())
            }
            .fullScreenCover(isPresented: $isFlashCardPresented) {
                FlashcardPageView()
            }
        }
    }
    
    struct NavigationCard: View {
        let title: String
        let imgName: String
        let desc: String
        let gradientColor: [Color]
        var onTap: (() -> Void)? = nil
        
        var body: some View {
            HStack(spacing: 20) {
                Image(imgName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .frame(width: 120)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .lineLimit(1)
                        .font(.title2)
                        .bold()
                    
                    Text(desc)
                        .font(.caption)
                }
                .padding(.trailing, 5)
                .padding(.vertical, 10)
                .foregroundColor(Color.white)
                
                Spacer(minLength: 0)
            }
            .onTapGesture {
                onTap?()
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradientColor),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(15)
        }
    }
}

#Preview {
    HomeScreenView()
}
