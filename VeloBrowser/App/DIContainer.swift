// DIContainer.swift
// VeloBrowser
//
// Central dependency injection container using protocol-based registration.

import SwiftUI
import SwiftData

/// Central dependency injection container for VeloBrowser.
///
/// All services and repositories are registered as protocols,
/// enabling easy testing and swapping of implementations.
/// Uses `@Observable` for SwiftUI integration.
@Observable
@MainActor
final class DIContainer {
    // MARK: - SwiftData

    /// The shared SwiftData model container for persistent storage.
    let modelContainer: ModelContainer

    // MARK: - Repositories

    /// Repository for bookmark CRUD operations.
    let bookmarkRepository: BookmarkRepositoryProtocol

    /// Repository for browsing history operations.
    let historyRepository: HistoryRepositoryProtocol

    /// Repository for download item operations.
    let downloadRepository: DownloadRepositoryProtocol

    // MARK: - Services

    /// Tab management service.
    let tabManager: TabManager

    /// Ad blocking service.
    let adBlockService: AdBlockService

    /// Media player service for background audio and PiP.
    let mediaPlayerService: MediaPlayerService

    /// Now playing info manager for lock screen controls.
    let nowPlayingManager: NowPlayingManager

    /// Download manager service.
    let downloadManager: DownloadManagerService

    /// Network connectivity monitor.
    let networkMonitor: NetworkMonitor

    /// Reader mode content extraction service.
    let readerModeService: ReaderModeServiceProtocol

    /// Repository for reading list operations.
    let readingListRepository: ReadingListRepositoryProtocol

    /// HTTPS upgrade service for secure browsing.
    let httpsUpgradeService: HTTPSUpgradeServiceProtocol

    /// Biometric app lock service.
    let appLockService: AppLockServiceProtocol

    /// Tracking parameter removal service.
    let trackingProtectionService: TrackingProtectionServiceProtocol

    /// Browser fingerprint protection service.
    let fingerprintProtectionService: FingerprintProtectionServiceProtocol

    // MARK: - Initialization

    /// Creates a new DIContainer with all dependencies wired up.
    ///
    /// - Parameter inMemory: When `true`, uses in-memory storage (for testing).
    init(inMemory: Bool = false) {
        let schema = Schema([
            BookmarkEntity.self,
            HistoryEntryEntity.self,
            DownloadItemEntity.self,
            ReadingListItemEntity.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            self.modelContainer = container

            let context = container.mainContext
            self.bookmarkRepository = SwiftDataBookmarkRepository(modelContext: context)
            self.historyRepository = SwiftDataHistoryRepository(modelContext: context)
            self.downloadRepository = SwiftDataDownloadRepository(modelContext: context)

            // Services
            self.tabManager = TabManager(historyRepository: self.historyRepository)
            self.adBlockService = AdBlockService()
            self.nowPlayingManager = NowPlayingManager()
            self.mediaPlayerService = MediaPlayerService(nowPlayingManager: self.nowPlayingManager)
            self.downloadManager = DownloadManagerService(downloadRepository: self.downloadRepository)
            self.networkMonitor = NetworkMonitor()
            self.readerModeService = ReaderModeService()
            self.readingListRepository = SwiftDataReadingListRepository(modelContext: context)
            self.httpsUpgradeService = HTTPSUpgradeService()
            self.appLockService = AppLockService()
            self.trackingProtectionService = TrackingProtectionService()
            self.fingerprintProtectionService = FingerprintProtectionService()
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }
}
