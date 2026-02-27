// DownloadRepositoryProtocol.swift
// VeloBrowser
//
// Protocol defining download item data access operations.

import Foundation

/// Defines the contract for download item persistence operations.
///
/// Implementations may use SwiftData, CoreData, or in-memory storage.
/// All methods are async to support concurrent data access.
@MainActor
protocol DownloadRepositoryProtocol: Sendable {
    /// Fetches all download items, optionally filtered by status.
    ///
    /// - Parameter status: Optional status filter.
    /// - Returns: An array of download items matching the criteria.
    func fetchAll(status: DownloadStatus?) async throws -> [DownloadItem]

    /// Saves a new download item to persistent storage.
    ///
    /// - Parameter item: The download item to save.
    func save(_ item: DownloadItem) async throws

    /// Updates an existing download item (e.g., progress, status).
    ///
    /// - Parameter item: The download item with updated values.
    func update(_ item: DownloadItem) async throws

    /// Deletes a download item by its identifier.
    ///
    /// - Parameter id: The unique identifier of the item to delete.
    func delete(id: UUID) async throws

    /// Clears all completed or failed downloads.
    func clearCompleted() async throws
}
