// HistoryEntry.swift
// VeloBrowser
//
// Domain model representing a browsing history entry.

import Foundation

/// Represents a single entry in the user's browsing history.
///
/// History entries are automatically recorded as the user browses
/// and can be searched by title or URL.
struct HistoryEntry: Identifiable, Hashable, Sendable {
    /// Unique identifier for this history entry.
    let id: UUID

    /// The URL that was visited.
    var url: URL

    /// The page title at the time of the visit.
    var title: String

    /// The date and time of the visit.
    let visitedAt: Date

    /// Creates a new history entry.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - url: The visited URL.
    ///   - title: The page title.
    ///   - visitedAt: When the page was visited (defaults to now).
    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        visitedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
    }
}
