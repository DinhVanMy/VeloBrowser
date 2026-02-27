// VeloBrowserWidgetsBundle.swift
// VeloBrowserWidgets
//
// Entry point for the VeloBrowser widget extension.
// Registers all available widgets.

import WidgetKit
import SwiftUI

/// Widget bundle containing all VeloBrowser home screen widgets.
///
/// Includes:
/// - **Quick Search**: Small widget to open browser search.
/// - **Favorites Grid**: Medium widget showing top 4 bookmarks.
/// - **Privacy Stats**: Small widget showing ad block & tracker stats.
@main
struct VeloBrowserWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickSearchWidget()
        FavoritesGridWidget()
        PrivacyStatsWidget()
    }
}
