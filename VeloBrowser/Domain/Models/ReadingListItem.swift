// ReadingListItem.swift
// VeloBrowser
//
// Domain model for reading list entries.

import Foundation

/// Represents an article saved to the reading list.
///
/// Reading list items store a page URL and metadata for offline reference.
/// Items can be marked as read/unread for tracking progress.
struct ReadingListItem: Identifiable, Sendable, Equatable {
    /// Unique identifier.
    let id: UUID

    /// The saved page URL.
    let url: URL

    /// Article title.
    let title: String

    /// Short excerpt or description.
    let excerpt: String

    /// Date the item was added.
    let dateAdded: Date

    /// Whether the item has been read.
    var isRead: Bool

    /// Creates a new reading list item.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - url: The saved page URL.
    ///   - title: Article title.
    ///   - excerpt: Short excerpt or description.
    ///   - dateAdded: Date added (defaults to now).
    ///   - isRead: Whether the item has been read (defaults to false).
    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        excerpt: String = "",
        dateAdded: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.excerpt = excerpt
        self.dateAdded = dateAdded
        self.isRead = isRead
    }
}
