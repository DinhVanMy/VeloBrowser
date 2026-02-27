// ReadingListRepository.swift
// VeloBrowser
//
// SwiftData implementation of ReadingListRepositoryProtocol.

import Foundation
import SwiftData

/// SwiftData-backed implementation of ``ReadingListRepositoryProtocol``.
///
/// Persists reading list items using SwiftData's `ModelContext` and converts
/// between `ReadingListItemEntity` (persistence) and `ReadingListItem` (domain).
@MainActor
final class SwiftDataReadingListRepository: ReadingListRepositoryProtocol {
    private let modelContext: ModelContext

    /// Creates a repository backed by the given model context.
    ///
    /// - Parameter modelContext: The SwiftData context for persistence operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() async throws -> [ReadingListItem] {
        let descriptor = FetchDescriptor<ReadingListItemEntity>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }

    func save(_ item: ReadingListItem) async throws {
        let entity = ReadingListItemEntity(
            id: item.id,
            urlString: item.url.absoluteString,
            title: item.title,
            excerpt: item.excerpt,
            dateAdded: item.dateAdded,
            isRead: item.isRead
        )
        modelContext.insert(entity)
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<ReadingListItemEntity>(
            predicate: #Predicate<ReadingListItemEntity> { $0.id == id }
        )
        if let entity = try modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try modelContext.save()
        }
    }

    func toggleRead(id: UUID) async throws {
        let descriptor = FetchDescriptor<ReadingListItemEntity>(
            predicate: #Predicate<ReadingListItemEntity> { $0.id == id }
        )
        if let entity = try modelContext.fetch(descriptor).first {
            entity.isRead.toggle()
            try modelContext.save()
        }
    }

    func search(query: String) async throws -> [ReadingListItem] {
        let descriptor = FetchDescriptor<ReadingListItemEntity>(
            predicate: #Predicate<ReadingListItemEntity> { entity in
                entity.title.localizedStandardContains(query) ||
                entity.urlString.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }

    func deleteAll() async throws {
        let descriptor = FetchDescriptor<ReadingListItemEntity>()
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }
}
