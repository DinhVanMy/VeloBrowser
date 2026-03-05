// FavoritesGridWidget.swift
// VeloBrowserWidgets
//
// A medium widget showing top 4 favorite bookmarks in a grid layout.

import WidgetKit
import SwiftUI

/// Timeline provider for the Favorites Grid widget.
///
/// Reads favorite bookmarks from shared App Group UserDefaults.
struct FavoritesGridProvider: TimelineProvider {
    private let dataProvider = SharedDataProvider()

    func placeholder(in context: Context) -> FavoritesGridEntry {
        FavoritesGridEntry(date: Date(), bookmarks: [
            SharedBookmark(id: "1", title: "Apple", urlString: "https://apple.com"),
            SharedBookmark(id: "2", title: "Google", urlString: "https://google.com"),
            SharedBookmark(id: "3", title: "GitHub", urlString: "https://github.com"),
            SharedBookmark(id: "4", title: "Swift", urlString: "https://swift.org"),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesGridEntry) -> Void) {
        let bookmarks = dataProvider.favoriteBookmarks
        completion(FavoritesGridEntry(date: Date(), bookmarks: bookmarks))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesGridEntry>) -> Void) {
        let bookmarks = dataProvider.favoriteBookmarks
        let entry = FavoritesGridEntry(date: Date(), bookmarks: bookmarks)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

/// Timeline entry for the Favorites Grid widget.
struct FavoritesGridEntry: TimelineEntry {
    let date: Date
    let bookmarks: [SharedBookmark]
}

/// View for the Favorites Grid widget.
///
/// Shows up to 4 bookmarks in a 2x2 grid. Each tile links to the bookmark URL.
struct FavoritesGridWidgetView: View {
    var entry: FavoritesGridProvider.Entry

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        if entry.bookmarks.isEmpty {
            emptyState
        } else {
            bookmarksGrid
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No Favorites")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Add bookmarks in VelGo")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "velobrowser://newtab"))
    }

    private var bookmarksGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(entry.bookmarks.prefix(4))) { bookmark in
                Link(destination: URL(string: "velobrowser://open?url=\(bookmark.urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bookmark.urlString)") ?? URL(string: "velobrowser://newtab")!) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Text(String(bookmark.title.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                        Text(bookmark.title)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(4)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Favorites Grid widget configuration.
///
/// A medium (systemMedium) widget showing the user's top 4 bookmarks.
struct FavoritesGridWidget: Widget {
    let kind: String = "FavoritesGridWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesGridProvider()) { entry in
            FavoritesGridWidgetView(entry: entry)
        }
        .configurationDisplayName("Favorites")
        .description("Quick access to your favorite bookmarks.")
        .supportedFamilies([.systemMedium])
    }
}
