// HistoryRepository.swift
// VeloBrowser
//
// SwiftData implementation of HistoryRepositoryProtocol.

import Foundation
import SwiftData

/// SwiftData-backed implementation of ``HistoryRepositoryProtocol``.
///
/// Persists browsing history using SwiftData's `ModelContext` and converts
/// between `HistoryEntryEntity` (persistence) and `HistoryEntry` (domain).
@MainActor
final class SwiftDataHistoryRepository: HistoryRepositoryProtocol {
    private let modelContext: ModelContext

    /// Creates a repository backed by the given model context.
    ///
    /// - Parameter modelContext: The SwiftData context for persistence operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch(from startDate: Date?, to endDate: Date?, limit: Int) async throws -> [HistoryEntry] {
        var descriptor = FetchDescriptor<HistoryEntryEntity>(
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        if let startDate, let endDate {
            descriptor.predicate = #Predicate<HistoryEntryEntity> { entity in
                entity.visitedAt >= startDate && entity.visitedAt <= endDate
            }
        } else if let startDate {
            descriptor.predicate = #Predicate<HistoryEntryEntity> { entity in
                entity.visitedAt >= startDate
            }
        } else if let endDate {
            descriptor.predicate = #Predicate<HistoryEntryEntity> { entity in
                entity.visitedAt <= endDate
            }
        }

        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }

    func record(_ entry: HistoryEntry) async throws {
        let entity = HistoryEntryEntity(
            id: entry.id,
            urlString: entry.url.absoluteString,
            title: entry.title,
            visitedAt: entry.visitedAt
        )
        modelContext.insert(entity)
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<HistoryEntryEntity>(
            predicate: #Predicate<HistoryEntryEntity> { $0.id == id }
        )
        if let entity = try modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try modelContext.save()
        }
    }

    func clearAll() async throws {
        let descriptor = FetchDescriptor<HistoryEntryEntity>()
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    func search(query: String) async throws -> [HistoryEntry] {
        let descriptor = FetchDescriptor<HistoryEntryEntity>(
            predicate: #Predicate<HistoryEntryEntity> { entity in
                entity.title.localizedStandardContains(query) ||
                entity.urlString.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }
}
