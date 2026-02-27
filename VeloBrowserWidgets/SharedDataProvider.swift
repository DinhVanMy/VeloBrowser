// SharedDataProvider.swift
// VeloBrowserWidgets
//
// Provides shared data access between the main app and widget extension
// via App Group shared UserDefaults.

import Foundation
import WidgetKit

/// Keys used for shared data between the main app and widget extension.
enum SharedDataKey {
    /// App Group suite name for shared UserDefaults.
    static let suiteName = "group.com.velobrowser.shared"

    /// Total number of ads blocked (Int).
    static let adsBlockedCount = "widget_adsBlockedCount"

    /// Total number of tracking parameters removed (Int).
    static let trackersStrippedCount = "widget_trackersStrippedCount"

    /// JSON-encoded array of favorite bookmarks for the widget.
    static let favoriteBookmarks = "widget_favoriteBookmarks"
}

/// A lightweight bookmark representation shared between the main app and widgets.
struct SharedBookmark: Codable, Identifiable {
    /// Unique identifier.
    let id: String

    /// Display title.
    let title: String

    /// Bookmark URL string.
    let urlString: String

    /// The URL constructed from the URL string, if valid.
    var url: URL? { URL(string: urlString) }
}

/// Provides read access to shared data stored in App Group UserDefaults.
///
/// Used by widget extensions to display bookmarks, ad block stats, etc.
struct SharedDataProvider {
    /// Shared UserDefaults backed by the App Group container.
    private let defaults: UserDefaults

    /// Creates a new shared data provider.
    init() {
        self.defaults = UserDefaults(suiteName: SharedDataKey.suiteName) ?? .standard
    }

    /// The total number of ads blocked across all sessions.
    var adsBlockedCount: Int {
        defaults.integer(forKey: SharedDataKey.adsBlockedCount)
    }

    /// The total number of tracking parameters stripped from URLs.
    var trackersStrippedCount: Int {
        defaults.integer(forKey: SharedDataKey.trackersStrippedCount)
    }

    /// The user's favorite bookmarks (up to 4) for the Favorites widget.
    var favoriteBookmarks: [SharedBookmark] {
        guard let data = defaults.data(forKey: SharedDataKey.favoriteBookmarks) else {
            return []
        }
        return (try? JSONDecoder().decode([SharedBookmark].self, from: data)) ?? []
    }

    // MARK: - Write (called from main app)

    /// Updates the ads blocked count in shared storage.
    ///
    /// - Parameter count: The total number of ads blocked.
    static func updateAdsBlockedCount(_ count: Int) {
        let defaults = UserDefaults(suiteName: SharedDataKey.suiteName) ?? .standard
        defaults.set(count, forKey: SharedDataKey.adsBlockedCount)
        WidgetCenter.shared.reloadTimelines(ofKind: "PrivacyStatsWidget")
    }

    /// Updates the trackers stripped count in shared storage.
    ///
    /// - Parameter count: The total number of tracking parameters removed.
    static func updateTrackersStrippedCount(_ count: Int) {
        let defaults = UserDefaults(suiteName: SharedDataKey.suiteName) ?? .standard
        defaults.set(count, forKey: SharedDataKey.trackersStrippedCount)
        WidgetCenter.shared.reloadTimelines(ofKind: "PrivacyStatsWidget")
    }

    /// Updates the favorite bookmarks in shared storage.
    ///
    /// - Parameter bookmarks: An array of shared bookmark representations (max 4).
    static func updateFavoriteBookmarks(_ bookmarks: [SharedBookmark]) {
        let defaults = UserDefaults(suiteName: SharedDataKey.suiteName) ?? .standard
        let limited = Array(bookmarks.prefix(4))
        if let data = try? JSONEncoder().encode(limited) {
            defaults.set(data, forKey: SharedDataKey.favoriteBookmarks)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FavoritesGridWidget")
    }
}
