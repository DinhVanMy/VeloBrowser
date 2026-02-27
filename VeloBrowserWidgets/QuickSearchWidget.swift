// QuickSearchWidget.swift
// VeloBrowserWidgets
//
// A small widget that opens VeloBrowser with the address bar focused for quick search.

import WidgetKit
import SwiftUI

/// Timeline provider for the Quick Search widget.
///
/// This widget is static — it always shows the same "Search" prompt,
/// so the timeline never changes.
struct QuickSearchProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickSearchEntry {
        QuickSearchEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickSearchEntry) -> Void) {
        completion(QuickSearchEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickSearchEntry>) -> Void) {
        let entry = QuickSearchEntry(date: Date())
        // Static widget — refresh far in the future
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

/// Timeline entry for the Quick Search widget.
struct QuickSearchEntry: TimelineEntry {
    let date: Date
}

/// View for the Quick Search widget.
///
/// Displays the Velo Browser icon and a "Search the web" prompt.
/// Tapping opens the app with the address bar focused.
struct QuickSearchWidgetView: View {
    var entry: QuickSearchProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.blue)

            Text("Velo Browser")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2)
                Text("Search")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "velobrowser://search"))
    }
}

/// Quick Search widget configuration.
///
/// A small (systemSmall) widget that deep-links to the browser's search bar.
struct QuickSearchWidget: Widget {
    let kind: String = "QuickSearchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickSearchProvider()) { entry in
            QuickSearchWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Search")
        .description("Tap to search the web with Velo Browser.")
        .supportedFamilies([.systemSmall])
    }
}
