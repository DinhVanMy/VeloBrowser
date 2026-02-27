// WidgetDataSync.swift
// VeloBrowser
//
// Syncs app statistics to the shared App Group container
// so widgets can display up-to-date data.

import Foundation
import WidgetKit

/// Synchronizes key app data to the App Group shared UserDefaults
/// for consumption by the VeloBrowserWidgets extension.
///
/// Call ``sync(adsBlocked:trackersStripped:bookmarks:)`` whenever
/// relevant data changes, or at minimum on scene phase transitions.
@MainActor
enum WidgetDataSync {
    /// App Group suite name matching the widget extension.
    private static let suiteName = "group.com.velobrowser.shared"

    /// Syncs all widget-relevant data to the shared container.
    ///
    /// - Parameters:
    ///   - adsBlocked: Total cumulative ads blocked.
    ///   - trackersStripped: Total cumulative tracking parameters removed.
    ///   - bookmarks: Top bookmarks to display in the Favorites widget.
    static func sync(
        adsBlocked: Int,
        trackersStripped: Int,
        bookmarks: [(id: String, title: String, urlString: String)]
    ) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        defaults.set(adsBlocked, forKey: "widget_adsBlockedCount")
        defaults.set(trackersStripped, forKey: "widget_trackersStrippedCount")

        // Encode bookmarks as JSON
        let bookmarkDicts = bookmarks.prefix(4).map { bookmark in
            ["id": bookmark.id, "title": bookmark.title, "urlString": bookmark.urlString]
        }
        if let data = try? JSONSerialization.data(withJSONObject: bookmarkDicts) {
            defaults.set(data, forKey: "widget_favoriteBookmarks")
        }

        // Request widget timeline refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Quick sync for just the privacy statistics (ads + trackers).
    ///
    /// - Parameters:
    ///   - adsBlocked: Total cumulative ads blocked.
    ///   - trackersStripped: Total cumulative tracking parameters removed.
    static func syncStats(adsBlocked: Int, trackersStripped: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(adsBlocked, forKey: "widget_adsBlockedCount")
        defaults.set(trackersStripped, forKey: "widget_trackersStrippedCount")
    }
}
