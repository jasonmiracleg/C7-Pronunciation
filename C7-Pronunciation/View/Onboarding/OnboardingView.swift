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

            TabView(selection: $viewModel.currentPageIndex) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index) // Associates the view with the index
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Use paging style, hide default dots
            
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: viewModel.currentPageIndex) // Animate page changes

            PageIndicatorView(pageCount: viewModel.pages.count, currentPageIndex: $viewModel.currentPageIndex)
            
            Spacer()

            HStack {
                // Button actions no longer need to track previousPageIndex
                Button(action: viewModel.finishOnboarding) {
                    Text("SKIP")
                        .font(.headline)
                        .padding(16)
                        .foregroundColor(Color(.systemGray))
                        .cornerRadius(12)
                }
                .opacity(viewModel.isLastPage ? 0 : 1)
                .animation(.default, value: viewModel.isLastPage)

                Spacer()
                
                Button(action: viewModel.goToNextPage) {
                    Text(viewModel.isLastPage ? "START" : "NEXT")
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

#Preview {
    OnboardingView(onOnboardingFinished: {})
}
