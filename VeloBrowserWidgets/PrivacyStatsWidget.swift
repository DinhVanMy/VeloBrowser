// PrivacyStatsWidget.swift
// VeloBrowserWidgets
//
// A small widget displaying ad blocking and tracker protection statistics.

import WidgetKit
import SwiftUI

/// Timeline provider for the Privacy Stats widget.
///
/// Reads ad block and tracker counts from shared App Group UserDefaults.
struct PrivacyStatsProvider: TimelineProvider {
    private let dataProvider = SharedDataProvider()

    func placeholder(in context: Context) -> PrivacyStatsEntry {
        PrivacyStatsEntry(date: Date(), adsBlocked: 1234, trackersStripped: 567)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrivacyStatsEntry) -> Void) {
        let entry = PrivacyStatsEntry(
            date: Date(),
            adsBlocked: dataProvider.adsBlockedCount,
            trackersStripped: dataProvider.trackersStrippedCount
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrivacyStatsEntry>) -> Void) {
        let entry = PrivacyStatsEntry(
            date: Date(),
            adsBlocked: dataProvider.adsBlockedCount,
            trackersStripped: dataProvider.trackersStrippedCount
        )
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

/// Timeline entry for the Privacy Stats widget.
struct PrivacyStatsEntry: TimelineEntry {
    let date: Date
    let adsBlocked: Int
    let trackersStripped: Int
}

/// View for the Privacy Stats widget.
///
/// Shows ad blocked count and tracker stripped count with icons.
struct PrivacyStatsWidgetView: View {
    var entry: PrivacyStatsProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(.green)
                Spacer()
                Text("Privacy")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                statRow(
                    icon: "nosign",
                    label: "Ads Blocked",
                    value: entry.adsBlocked,
                    color: .orange
                )
                statRow(
                    icon: "eye.slash",
                    label: "Trackers Stripped",
                    value: entry.trackersStripped,
                    color: .purple
                )
            }

            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "velobrowser://settings"))
    }

    private func statRow(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(formattedCount(value))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Formats large numbers with abbreviated suffixes.
    private func formattedCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

/// Privacy Stats widget configuration.
///
/// A small (systemSmall) widget showing ads blocked and trackers stripped counts.
struct PrivacyStatsWidget: Widget {
    let kind: String = "PrivacyStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrivacyStatsProvider()) { entry in
            PrivacyStatsWidgetView(entry: entry)
        }
        .configurationDisplayName("Privacy Stats")
        .description("See how many ads and trackers VelGo has blocked.")
        .supportedFamilies([.systemSmall])
    }
}
