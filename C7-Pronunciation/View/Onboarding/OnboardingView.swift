//
//  OnboardingView.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 14/11/25.
//

import SwiftUI

struct OnboardingView: View {
    
    @StateObject private var viewModel: OnboardingViewModel
    
    init(onOnboardingFinished: @escaping () -> Void) {
        self._viewModel = StateObject(
            wrappedValue: OnboardingViewModel(onOnboardingFinished: onOnboardingFinished)
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    if viewModel.currentPageIndex == index {
                        OnboardingPageView(page: page)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ).combined(with: .opacity))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: viewModel.currentPageIndex)

            PageIndicatorView(pageCount: viewModel.pages.count, currentPageIndex: $viewModel.currentPageIndex)
            
            Spacer()

            HStack {
                Button(action: viewModel.finishOnboarding) {
                    Text("SKIP")
                        .font(.headline)
                        .padding(16)
                        .foregroundColor(Color(.systemGray)) // Changed to match screenshot
                        .cornerRadius(12)
                }
                .opacity(viewModel.isLastPage ? 0 : 1)
                .animation(.default, value: viewModel.isLastPage)

                Spacer()
                
                Button(action: viewModel.goToNextPage) {
                    Text(viewModel.isLastPage ? "GET STARTED" : "NEXT")
                        .font(.headline)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 30)
                        .foregroundColor(.primary)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onOnboardingFinished: {
            print("Preview: Onboarding finished.")
        })
    }
}
