// VeloBrowserApp.swift
// VeloBrowser
//
// Entry point for the VeloBrowser application.

import SwiftUI
import SwiftData
import AVFoundation

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

    init() {
        // Configure audio session at launch for WKWebView background audio
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
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

                // Lock screen overlay
                if container.appLockService.isLocked {
                    LockScreenView(appLockService: container.appLockService)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Audio Session

    /// Configures AVAudioSession for background audio playback.
    ///
    /// Must be called early so WKWebView audio continues when the app
    /// is backgrounded or the screen is locked (e.g., YouTube music).
    /// Uses `.playback` category WITHOUT `.mixWithOthers` so iOS treats
    /// this as the primary audio source and does not suspend the process.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            // Audio session setup failed — background audio may not work
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

    // MARK: - Scene Phase

    /// Handles app lifecycle changes for biometric lock.
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            container.appLockService.appDidEnterBackground()
        case .active:
            container.appLockService.appDidBecomeActive()
        @unknown default:
            break
        }
    }
}
