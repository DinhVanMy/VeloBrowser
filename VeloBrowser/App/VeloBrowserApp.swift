// VeloBrowserApp.swift
// VeloBrowser
//
// Entry point for the VeloBrowser application.

import SwiftUI
import SwiftData

/// Main application entry point for VeloBrowser.
///
/// Configures the SwiftData model container and initializes
/// the dependency injection container before presenting the root view.
/// Shows onboarding on first launch and handles incoming URLs.
@main
struct VeloBrowserApp: App {
    /// Shared dependency injection container for the entire app.
    @State private var container = DIContainer()

    /// Whether onboarding has been completed.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                AppCoordinatorView()
                    .environment(container)
                    .modelContainer(container.modelContainer)
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
            } else {
                FirstLaunchView {
                    withAnimation(.easeInOut(duration: DesignSystem.AnimationDuration.standard)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }

    // MARK: - URL Handling

    /// Handles incoming URLs from other apps or URL schemes.
    ///
    /// Supports `velobrowser://open?url=<encoded_url>` and
    /// direct `https://` URLs via Universal Links.
    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "velobrowser" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryURL = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let target = URL(string: queryURL) {
                container.tabManager.createTab(url: target)
            }
        } else if url.scheme == "https" || url.scheme == "http" {
            container.tabManager.createTab(url: url)
        }
    }
}
