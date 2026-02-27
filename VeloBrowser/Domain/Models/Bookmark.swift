// Bookmark.swift
// VeloBrowser
//
// Domain model representing a saved bookmark.

import Foundation

/// Represents a user-saved bookmark for quick access to web pages.
///
/// Bookmarks store the URL, a user-friendly title, and optional
/// folder organization. They are persisted via SwiftData.
struct Bookmark: Identifiable, Hashable, Sendable {
    /// Unique identifier for this bookmark.
    let id: UUID

    /// The bookmarked URL.
    var url: URL

    /// User-visible title for the bookmark.
    var title: String

    /// Optional folder name for organization.
    var folder: String?

    /// The favicon URL for display purposes, if available.
    var faviconURL: URL?

    /// The date this bookmark was created.
    let createdAt: Date

    /// Creates a new bookmark.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - url: The URL to bookmark.
    ///   - title: Display title for the bookmark.
    ///   - folder: Optional folder for organization.
    ///   - faviconURL: Optional favicon URL.
    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        folder: String? = nil,
        faviconURL: URL? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.folder = folder
        self.faviconURL = faviconURL
        self.createdAt = Date()
    }
}
