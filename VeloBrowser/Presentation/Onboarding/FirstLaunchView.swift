// FirstLaunchView.swift
// VeloBrowser
//
// Onboarding flow shown on first app launch.

import SwiftUI

/// A single onboarding page model.
private struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String
}

/// Onboarding view shown on first launch with a 3-page introduction.
///
/// Presents the app's key features using tabbed pages with
/// SF Symbols, then saves a completion flag to UserDefaults.
struct FirstLaunchView: View {
    /// Callback invoked when the user completes onboarding.
    var onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            icon: "bolt.fill",
            title: "Fast Browsing",
            subtitle: "Lightning-fast web browsing with a clean, native experience built for iOS."
        ),
        OnboardingPage(
            id: 1,
            icon: "shield.fill",
            title: "Ad-Free Experience",
            subtitle: "Built-in ad blocker removes ads and trackers for faster, cleaner pages."
        ),
        OnboardingPage(
            id: 2,
            icon: "headphones",
            title: "Background Audio & PiP",
            subtitle: "Keep listening when you switch apps. Watch videos in Picture-in-Picture."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    pageView(page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 360)

            Spacer()

            // Bottom action area
            VStack(spacing: DesignSystem.Spacing.md) {
                if currentPage == pages.count - 1 {
                    Button(action: onComplete) {
                        Text("Get Started")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: DesignSystem.minimumTouchTarget)
                            .background(DesignSystem.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
                    }
                    .accessibilityLabel("Get started with VeloBrowser")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    } label: {
                        Text("Continue")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: DesignSystem.minimumTouchTarget)
                            .background(DesignSystem.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
                    }
                    .accessibilityLabel("Continue to next page")
                }

                Button("Skip") {
                    onComplete()
                }
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .accessibilityLabel("Skip onboarding")
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.bottom, DesignSystem.Spacing.xl)
            .animation(.easeInOut(duration: DesignSystem.AnimationDuration.fast), value: currentPage)
        }
        .background(DesignSystem.Colors.backgroundPrimary)
    }

    // MARK: - Page View

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: page.icon)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(DesignSystem.Colors.accent)
                .accessibilityHidden(true)

            Text(page.title)
                .font(DesignSystem.Typography.title)
                .fontWeight(.bold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(DesignSystem.Spacing.md)
    }
}
