// HistoryRepositoryProtocol.swift
// VeloBrowser
//
// Protocol defining browsing history data access operations.

import Foundation

/// Defines the contract for browsing history persistence operations.
///
/// Implementations may use SwiftData, CoreData, or in-memory storage.
/// All methods are async to support concurrent data access.
@MainActor
protocol HistoryRepositoryProtocol: Sendable {
    /// Fetches history entries within a date range.
    ///
    /// - Parameters:
    ///   - from: Start date (inclusive). Defaults to the beginning of time.
    ///   - to: End date (inclusive). Defaults to now.
    ///   - limit: Maximum number of entries to return.
    /// - Returns: An array of history entries, most recent first.
    func fetch(from: Date?, to: Date?, limit: Int) async throws -> [HistoryEntry]

    /// Records a new history entry.
    ///
    /// - Parameter entry: The history entry to save.
    func record(_ entry: HistoryEntry) async throws

    /// Deletes a specific history entry by its identifier.
    ///
    /// - Parameter id: The unique identifier of the entry to delete.
    func delete(id: UUID) async throws

    /// Clears all browsing history.
    func clearAll() async throws

    /// Searches history entries by title or URL containing the query.
    ///
    /// - Parameter query: The search string.
    /// - Returns: An array of matching history entries.
    func search(query: String) async throws -> [HistoryEntry]
}
