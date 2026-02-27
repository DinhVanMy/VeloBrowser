// SpotlightIndexer.swift
// VeloBrowser
//
// Indexes bookmarks and history into Core Spotlight for system-wide search
// and configures NSUserActivity for Handoff support.

@preconcurrency import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

/// Service for indexing browser content into Core Spotlight search.
///
/// Indexes bookmarks and frequently visited history entries so users
/// can find them from the iOS system search.
@MainActor
final class SpotlightIndexer {
    /// Domain identifier for bookmark entries.
    private static let bookmarkDomain = "com.velobrowser.bookmarks"
    /// Domain identifier for history entries.
    private static let historyDomain = "com.velobrowser.history"

    // MARK: - Bookmark Indexing

    /// Indexes all bookmarks into Core Spotlight.
    ///
    /// - Parameter bookmarks: The bookmarks to index.
    func indexBookmarks(_ bookmarks: [Bookmark]) {
        let items = bookmarks.map { bookmark -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .url)
            attributes.title = bookmark.title
            attributes.contentDescription = bookmark.url.absoluteString
            attributes.url = bookmark.url
            attributes.domainIdentifier = Self.bookmarkDomain
            return CSSearchableItem(
                uniqueIdentifier: "bookmark-\(bookmark.id.uuidString)",
                domainIdentifier: Self.bookmarkDomain,
                attributeSet: attributes
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items)
    }

    /// Removes a single bookmark from the Spotlight index.
    ///
    /// - Parameter bookmark: The bookmark to remove.
    func removeBookmark(_ bookmark: Bookmark) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: ["bookmark-\(bookmark.id.uuidString)"]
        )
    }

    // MARK: - History Indexing

    /// Indexes the top visited history entries into Core Spotlight.
    ///
    /// - Parameter entries: The history entries to index (max 50).
    func indexHistory(_ entries: [HistoryEntry]) {
        let top = Array(entries.prefix(50))
        let items = top.map { entry -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .url)
            attributes.title = entry.title
            attributes.contentDescription = entry.url.absoluteString
            attributes.url = entry.url
            attributes.domainIdentifier = Self.historyDomain
            return CSSearchableItem(
                uniqueIdentifier: "history-\(entry.id.uuidString)",
                domainIdentifier: Self.historyDomain,
                attributeSet: attributes
            )
        }
        // Clear old history items first, then re-index
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [Self.historyDomain]
        ) { _ in
            CSSearchableIndex.default().indexSearchableItems(items)
        }
    }

    // MARK: - Cleanup

    /// Removes all indexed content from Spotlight.
    func removeAllIndexedItems() {
        CSSearchableIndex.default().deleteAllSearchableItems()
    }
}
