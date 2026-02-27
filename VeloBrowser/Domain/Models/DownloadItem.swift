// DownloadItem.swift
// VeloBrowser
//
// Domain model representing a file download.

import Foundation

/// The current state of a download operation.
enum DownloadStatus: String, Sendable, Codable {
    /// Download is waiting to start.
    case pending

    /// Download is actively transferring data.
    case downloading

    /// Download has been temporarily paused.
    case paused

    /// Download completed successfully.
    case completed

    /// Download failed with an error.
    case failed

    /// Download was cancelled by the user.
    case cancelled
}

/// Represents a file being downloaded or already downloaded.
///
/// Tracks the source URL, local file path, progress, and status
/// of a file download operation.
struct DownloadItem: Identifiable, Hashable, Sendable {
    /// Unique identifier for this download.
    let id: UUID

    /// The remote URL the file is being downloaded from.
    var sourceURL: URL

    /// The local file URL where the download is saved.
    var localURL: URL?

    /// User-visible file name.
    var fileName: String

    /// MIME type of the file, if known.
    var mimeType: String?

    /// Total file size in bytes, if known.
    var totalBytes: Int64?

    /// Number of bytes downloaded so far.
    var downloadedBytes: Int64

    /// Current status of the download.
    var status: DownloadStatus

    /// The date this download was initiated.
    let createdAt: Date

    /// Download progress as a fraction from 0.0 to 1.0.
    var progress: Double {
        guard let total = totalBytes, total > 0 else { return 0 }
        return Double(downloadedBytes) / Double(total)
    }

    /// Creates a new download item.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - sourceURL: The remote URL to download from.
    ///   - fileName: Display name for the file.
    ///   - mimeType: Optional MIME type.
    ///   - totalBytes: Optional total file size.
    init(
        id: UUID = UUID(),
        sourceURL: URL,
        fileName: String,
        mimeType: String? = nil,
        totalBytes: Int64? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.localURL = nil
        self.fileName = fileName
        self.mimeType = mimeType
        self.totalBytes = totalBytes
        self.downloadedBytes = 0
        self.status = .pending
        self.createdAt = Date()
    }
}
