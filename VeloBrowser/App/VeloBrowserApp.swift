// VeloBrowserApp.swift
// VeloBrowser
//
// Entry point for the VeloBrowser application.

import SwiftUI
import SwiftData
import AVFoundation
import CoreSpotlight

/// Main application entry point for VeloBrowser.
///
/// Configures the SwiftData model container and initializes
/// the dependency injection container before presenting the root view.
/// Shows onboarding on first launch and handles incoming URLs,
/// Quick Actions, and Spotlight/Handoff continuations.
@main
struct VeloBrowserApp: App {
    /// Shared dependency injection container for the entire app.
    @State private var container = DIContainer()

    /// Whether onboarding has been completed.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Review manager for App Store review prompts.
    private let reviewManager = ReviewManager()

    init() {
        configureAudioSession()
        reviewManager.recordLaunch()
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
                        .onContinueUserActivity(CSSearchableItemActionType) { activity in
                            handleSpotlightActivity(activity)
                        }
                        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                            handleWebActivity(activity)
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

    /// Handles incoming URLs from deep links, widgets, and Quick Actions.
    ///
    /// Supported schemes:
    /// - `velobrowser://search` — new tab, focus address bar
    /// - `velobrowser://search?q=<query>` — search query
    /// - `velobrowser://open?url=<encoded_url>` — open URL
    /// - `velobrowser://newtab` — new blank tab
    /// - `velobrowser://privatetab` — new private tab
    /// - `velobrowser://settings` — open settings
    /// - `https://` or `http://` — open URL in new tab
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "velobrowser" else {
            if url.scheme == "https" || url.scheme == "http" {
                container.tabManager.createTab(url: url)
            }
            return
        }

        let host = url.host()
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch host {
        case "search":
            if let query = components?.queryItems?.first(where: { $0.name == "q" })?.value,
               !query.isEmpty {
                let searchEngine = UserDefaults.standard.string(forKey: "searchEngine") ?? "Google"
                let searchURL: URL? = switch searchEngine {
                case "DuckDuckGo":
                    URL(string: "https://duckduckgo.com/?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
                case "Bing":
                    URL(string: "https://www.bing.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
                default:
                    URL(string: "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
                }
                if let searchURL {
                    container.tabManager.createTab(url: searchURL)
                }
            } else {
                container.tabManager.createTab()
            }
        case "open":
            if let urlString = components?.queryItems?.first(where: { $0.name == "url" })?.value,
               let target = URL(string: urlString) {
                container.tabManager.createTab(url: target)
            }
        case "newtab":
            container.tabManager.createTab()
        case "privatetab":
            container.tabManager.createTab(isPrivate: true)
        case "settings":
            // Settings navigation handled via coordinator
            break
        default:
            break
        }
    }

    // MARK: - Spotlight & Handoff

    /// Handles Spotlight search result taps.
    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        // Extract URL from activity
        if let url = activity.contentAttributeSet?.url {
            container.tabManager.createTab(url: url)
        } else if identifier.hasPrefix("bookmark-") || identifier.hasPrefix("history-") {
            // Fallback: try webpageURL
            if let url = activity.webpageURL {
                container.tabManager.createTab(url: url)
            }
        }
    }

    /// Handles Handoff web browsing activity.
    private func handleWebActivity(_ activity: NSUserActivity) {
        if let url = activity.webpageURL {
            container.tabManager.createTab(url: url)
        }
    }

    // MARK: - Widget Data Sync

    /// Syncs privacy stats and bookmarks to the App Group shared container for widgets.
    private func syncWidgetData() {
        let adsBlocked = container.adBlockService.totalAdsBlocked
        let trackersStripped = container.trackingProtectionService.strippedCount
        WidgetDataSync.syncStats(adsBlocked: adsBlocked, trackersStripped: trackersStripped)
    }

    // MARK: - Scene Phase

    /// Handles app lifecycle changes for biometric lock and review prompts.
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            container.appLockService.appDidEnterBackground()
            syncWidgetData()
        case .active:
            container.appLockService.appDidBecomeActive()
            reviewManager.requestReviewIfAppropriate()
        @unknown default:
            break
        }
    }
}
