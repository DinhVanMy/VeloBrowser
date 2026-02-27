// BookmarkRepository.swift
// VeloBrowser
//
// SwiftData implementation of BookmarkRepositoryProtocol.

import Foundation
import SwiftData

/// SwiftData-backed implementation of ``BookmarkRepositoryProtocol``.
///
/// Persists bookmarks using SwiftData's `ModelContext` and converts
/// between `BookmarkEntity` (persistence) and `Bookmark` (domain).
@MainActor
final class SwiftDataBookmarkRepository: BookmarkRepositoryProtocol {
    private let modelContext: ModelContext

    /// Creates a repository backed by the given model context.
    ///
    /// - Parameter modelContext: The SwiftData context for persistence operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll(folder: String?) async throws -> [Bookmark] {
        var descriptor = FetchDescriptor<BookmarkEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        if let folder {
            descriptor.predicate = #Predicate<BookmarkEntity> { entity in
                entity.folder == folder
            }
        }

        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }

    func save(_ bookmark: Bookmark) async throws {
        let entity = BookmarkEntity(
            id: bookmark.id,
            urlString: bookmark.url.absoluteString,
            title: bookmark.title,
            folder: bookmark.folder,
            faviconURLString: bookmark.faviconURL?.absoluteString,
            createdAt: bookmark.createdAt
        )
        modelContext.insert(entity)
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate<BookmarkEntity> { $0.id == id }
        )
        if let entity = try modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try modelContext.save()
        }
    }

    func update(_ bookmark: Bookmark) async throws {
        let targetID = bookmark.id
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate<BookmarkEntity> { $0.id == targetID }
        )
        if let entity = try modelContext.fetch(descriptor).first {
            entity.update(from: bookmark)
            try modelContext.save()
        }
    }

    func search(query: String) async throws -> [Bookmark] {
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate<BookmarkEntity> { entity in
                entity.title.localizedStandardContains(query) ||
                entity.urlString.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }
}
