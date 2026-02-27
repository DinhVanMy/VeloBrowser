// ReadingListRepositoryProtocol.swift
// VeloBrowser
//
// Protocol defining reading list data access operations.

import Foundation

/// Defines the contract for reading list persistence operations.
///
/// Implementations may use SwiftData, CoreData, or in-memory storage.
/// All methods are async to support concurrent data access.
@MainActor
protocol ReadingListRepositoryProtocol: Sendable {
    /// Fetches all reading list items, sorted by date added (newest first).
    ///
    /// - Returns: An array of all reading list items.
    func fetchAll() async throws -> [ReadingListItem]

    /// Saves a new reading list item to persistent storage.
    ///
    /// - Parameter item: The reading list item to save.
    func save(_ item: ReadingListItem) async throws

    /// Deletes a reading list item by its identifier.
    ///
    /// - Parameter id: The unique identifier of the item to delete.
    func delete(id: UUID) async throws

    /// Toggles the read/unread status of a reading list item.
    ///
    /// - Parameter id: The unique identifier of the item.
    func toggleRead(id: UUID) async throws

    /// Searches reading list items by title or URL containing the query string.
    ///
    /// - Parameter query: The search string.
    /// - Returns: An array of matching reading list items.
    func search(query: String) async throws -> [ReadingListItem]

    /// Deletes all reading list items.
    func deleteAll() async throws
}
