// BookmarkRepositoryProtocol.swift
// VeloBrowser
//
// Protocol defining bookmark data access operations.

import Foundation

/// Defines the contract for bookmark persistence operations.
///
/// Implementations may use SwiftData, CoreData, or in-memory storage.
/// All methods are async to support concurrent data access.
@MainActor
protocol BookmarkRepositoryProtocol: Sendable {
    /// Fetches all bookmarks, optionally filtered by folder.
    ///
    /// - Parameter folder: Optional folder name to filter by.
    /// - Returns: An array of bookmarks matching the criteria.
    func fetchAll(folder: String?) async throws -> [Bookmark]

    /// Saves a new bookmark to persistent storage.
    ///
    /// - Parameter bookmark: The bookmark to save.
    func save(_ bookmark: Bookmark) async throws

    /// Deletes a bookmark by its identifier.
    ///
    /// - Parameter id: The unique identifier of the bookmark to delete.
    func delete(id: UUID) async throws

    /// Updates an existing bookmark.
    ///
    /// - Parameter bookmark: The bookmark with updated values.
    func update(_ bookmark: Bookmark) async throws

    /// Searches bookmarks by title or URL containing the query string.
    ///
    /// - Parameter query: The search string.
    /// - Returns: An array of matching bookmarks.
    func search(query: String) async throws -> [Bookmark]
}
