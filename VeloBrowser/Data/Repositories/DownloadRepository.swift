// DownloadRepository.swift
// VeloBrowser
//
// SwiftData implementation of DownloadRepositoryProtocol.

import Foundation
import SwiftData

/// SwiftData-backed implementation of ``DownloadRepositoryProtocol``.
///
/// Persists download items using SwiftData's `ModelContext` and converts
/// between `DownloadItemEntity` (persistence) and `DownloadItem` (domain).
@MainActor
final class SwiftDataDownloadRepository: DownloadRepositoryProtocol {
    private let modelContext: ModelContext

    /// Creates a repository backed by the given model context.
    ///
    /// - Parameter modelContext: The SwiftData context for persistence operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll(status: DownloadStatus?) async throws -> [DownloadItem] {
        var descriptor = FetchDescriptor<DownloadItemEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        if let status {
            let statusRaw = status.rawValue
            descriptor.predicate = #Predicate<DownloadItemEntity> { entity in
                entity.statusRawValue == statusRaw
            }
        }

        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }

    func save(_ item: DownloadItem) async throws {
        let entity = DownloadItemEntity(
            id: item.id,
            sourceURLString: item.sourceURL.absoluteString,
            localURLString: item.localURL?.absoluteString,
            fileName: item.fileName,
            mimeType: item.mimeType,
            totalBytes: item.totalBytes,
            downloadedBytes: item.downloadedBytes,
            statusRawValue: item.status.rawValue,
            createdAt: item.createdAt
        )
        modelContext.insert(entity)
        try modelContext.save()
    }

    func update(_ item: DownloadItem) async throws {
        let targetID = item.id
        let descriptor = FetchDescriptor<DownloadItemEntity>(
            predicate: #Predicate<DownloadItemEntity> { $0.id == targetID }
        )
        if let entity = try modelContext.fetch(descriptor).first {
            entity.update(from: item)
            try modelContext.save()
        }
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<DownloadItemEntity>(
            predicate: #Predicate<DownloadItemEntity> { $0.id == id }
        )
        if let entity = try modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try modelContext.save()
        }
    }

    func clearCompleted() async throws {
        let completedRaw = DownloadStatus.completed.rawValue
        let failedRaw = DownloadStatus.failed.rawValue
        let cancelledRaw = DownloadStatus.cancelled.rawValue
        let descriptor = FetchDescriptor<DownloadItemEntity>(
            predicate: #Predicate<DownloadItemEntity> { entity in
                entity.statusRawValue == completedRaw ||
                entity.statusRawValue == failedRaw ||
                entity.statusRawValue == cancelledRaw
            }
        )
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }
}
