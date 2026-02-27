// SwiftDataStore.swift
// VeloBrowser
//
// SwiftData model definitions for persistent entities.

import Foundation
import SwiftData

/// SwiftData persistent model for bookmarks.
@Model
final class BookmarkEntity {
    /// Unique identifier.
    @Attribute(.unique) var id: UUID

    /// The bookmarked URL string.
    var urlString: String

    /// User-visible title.
    var title: String

    /// Optional folder for organization.
    var folder: String?

    /// Favicon URL string, if available.
    var faviconURLString: String?

    /// Creation date.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        urlString: String,
        title: String,
        folder: String? = nil,
        faviconURLString: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.folder = folder
        self.faviconURLString = faviconURLString
        self.createdAt = createdAt
    }

    /// Converts this entity to a domain model.
    func toDomain() -> Bookmark? {
        guard let url = URL(string: urlString) else { return nil }
        return Bookmark(
            id: id,
            url: url,
            title: title,
            folder: folder,
            faviconURL: faviconURLString.flatMap { URL(string: $0) }
        )
    }

    /// Updates this entity from a domain model.
    func update(from bookmark: Bookmark) {
        self.urlString = bookmark.url.absoluteString
        self.title = bookmark.title
        self.folder = bookmark.folder
        self.faviconURLString = bookmark.faviconURL?.absoluteString
    }
}

/// SwiftData persistent model for history entries.
@Model
final class HistoryEntryEntity {
    /// Unique identifier.
    @Attribute(.unique) var id: UUID

    /// The visited URL string.
    var urlString: String

    /// The page title.
    var title: String

    /// When the page was visited.
    var visitedAt: Date

    init(
        id: UUID = UUID(),
        urlString: String,
        title: String,
        visitedAt: Date = Date()
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.visitedAt = visitedAt
    }

    /// Converts this entity to a domain model.
    func toDomain() -> HistoryEntry? {
        guard let url = URL(string: urlString) else { return nil }
        return HistoryEntry(id: id, url: url, title: title, visitedAt: visitedAt)
    }
}

/// SwiftData persistent model for download items.
@Model
final class DownloadItemEntity {
    /// Unique identifier.
    @Attribute(.unique) var id: UUID

    /// Source URL string.
    var sourceURLString: String

    /// Local file URL string, if saved.
    var localURLString: String?

    /// Display file name.
    var fileName: String

    /// MIME type string.
    var mimeType: String?

    /// Total file size in bytes.
    var totalBytes: Int64?

    /// Downloaded bytes so far.
    var downloadedBytes: Int64

    /// Current download status raw value.
    var statusRawValue: String

    /// Creation date.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceURLString: String,
        localURLString: String? = nil,
        fileName: String,
        mimeType: String? = nil,
        totalBytes: Int64? = nil,
        downloadedBytes: Int64 = 0,
        statusRawValue: String = DownloadStatus.pending.rawValue,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceURLString = sourceURLString
        self.localURLString = localURLString
        self.fileName = fileName
        self.mimeType = mimeType
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.statusRawValue = statusRawValue
        self.createdAt = createdAt
    }

    /// Converts this entity to a domain model.
    func toDomain() -> DownloadItem? {
        guard let sourceURL = URL(string: sourceURLString) else { return nil }
        var item = DownloadItem(
            id: id,
            sourceURL: sourceURL,
            fileName: fileName,
            mimeType: mimeType,
            totalBytes: totalBytes
        )
        item.localURL = localURLString.flatMap { URL(string: $0) }
        item.downloadedBytes = downloadedBytes
        item.status = DownloadStatus(rawValue: statusRawValue) ?? .pending
        return item
    }

    /// Updates this entity from a domain model.
    func update(from item: DownloadItem) {
        self.sourceURLString = item.sourceURL.absoluteString
        self.localURLString = item.localURL?.absoluteString
        self.fileName = item.fileName
        self.mimeType = item.mimeType
        self.totalBytes = item.totalBytes
        self.downloadedBytes = item.downloadedBytes
        self.statusRawValue = item.status.rawValue
    }
}

// MARK: - ReadingListItemEntity

/// SwiftData persistent model for reading list items.
@Model
final class ReadingListItemEntity {
    /// Unique identifier.
    @Attribute(.unique) var id: UUID

    /// The saved page URL string.
    var urlString: String

    /// Article title.
    var title: String

    /// Short excerpt or description.
    var excerpt: String

    /// Date the item was added.
    var dateAdded: Date

    /// Whether the item has been read.
    var isRead: Bool

    init(
        id: UUID = UUID(),
        urlString: String,
        title: String,
        excerpt: String = "",
        dateAdded: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.excerpt = excerpt
        self.dateAdded = dateAdded
        self.isRead = isRead
    }

    /// Converts this entity to a domain model.
    func toDomain() -> ReadingListItem? {
        guard let url = URL(string: urlString) else { return nil }
        return ReadingListItem(
            id: id,
            url: url,
            title: title,
            excerpt: excerpt,
            dateAdded: dateAdded,
            isRead: isRead
        )
    }

    /// Updates this entity from a domain model.
    func update(from item: ReadingListItem) {
        self.urlString = item.url.absoluteString
        self.title = item.title
        self.excerpt = item.excerpt
        self.isRead = item.isRead
    }
}
