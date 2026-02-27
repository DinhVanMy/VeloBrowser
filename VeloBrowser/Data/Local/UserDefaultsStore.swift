// UserDefaultsStore.swift
// VeloBrowser
//
// Lightweight wrapper around UserDefaults for app preferences.

import Foundation

/// Type-safe wrapper around `UserDefaults` for app settings.
///
/// Provides strongly-typed access to user preferences with
/// sensible defaults. Uses `@MainActor` isolation for thread safety.
@MainActor
struct UserDefaultsStore {
    private let defaults: UserDefaults

    /// Keys for stored preferences.
    enum Key: String, Sendable {
        case isAdBlockEnabled
        case isPrivateBrowsingDefault
        case searchEngine
        case homepageURL
        case hasCompletedOnboarding
    }

    /// Creates a store backed by the given UserDefaults suite.
    ///
    /// - Parameter defaults: The UserDefaults instance (defaults to `.standard`).
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether the ad blocker is enabled. Defaults to `true`.
    var isAdBlockEnabled: Bool {
        get { defaults.object(forKey: Key.isAdBlockEnabled.rawValue) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.isAdBlockEnabled.rawValue) }
    }

    /// Whether new tabs default to private browsing. Defaults to `false`.
    var isPrivateBrowsingDefault: Bool {
        get { defaults.bool(forKey: Key.isPrivateBrowsingDefault.rawValue) }
        nonmutating set { defaults.set(newValue, forKey: Key.isPrivateBrowsingDefault.rawValue) }
    }

    /// The default search engine URL template. Defaults to Google.
    var searchEngine: String {
        get {
            defaults.string(forKey: Key.searchEngine.rawValue)
                ?? "https://www.google.com/search?q=%@"
        }
        nonmutating set { defaults.set(newValue, forKey: Key.searchEngine.rawValue) }
    }

    /// The homepage URL. Defaults to `nil` (show new tab page).
    var homepageURL: String? {
        get { defaults.string(forKey: Key.homepageURL.rawValue) }
        nonmutating set { defaults.set(newValue, forKey: Key.homepageURL.rawValue) }
    }

    /// Whether the user has completed onboarding. Defaults to `false`.
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue) }
        nonmutating set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue) }
    }
}
