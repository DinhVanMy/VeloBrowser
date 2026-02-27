// Tab.swift
// VeloBrowser
//
// Domain model representing a browser tab.

import Foundation

/// Represents a single browser tab in the application.
///
/// Tabs are identified by a unique UUID and track their current URL,
/// title, and whether they are in private browsing mode.
struct Tab: Identifiable, Hashable, Sendable {
    /// Unique identifier for this tab.
    let id: UUID

    /// The current URL being displayed, if any.
    var url: URL?

    /// The page title extracted from the loaded web content.
    var title: String

    /// Whether this tab is in private browsing mode.
    var isPrivate: Bool

    /// Whether this tab is currently the active/visible tab.
    var isActive: Bool

    /// The URL of the page's favicon, if detected.
    var faviconURL: URL?

    /// The date and time this tab was created.
    let createdAt: Date

    /// The date and time this tab was last accessed.
    var lastAccessedAt: Date

    /// Creates a new browser tab.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - url: Initial URL to load.
    ///   - title: Initial page title.
    ///   - isPrivate: Whether the tab uses private browsing.
    ///   - isActive: Whether the tab is currently visible.
    init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "New Tab",
        isPrivate: Bool = false,
        isActive: Bool = false,
        faviconURL: URL? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.isPrivate = isPrivate
        self.isActive = isActive
        self.faviconURL = faviconURL
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
    }

    /// The display-friendly host name, or "New Tab" if no URL.
    var displayHost: String {
        url?.host() ?? "New Tab"
    }
}
