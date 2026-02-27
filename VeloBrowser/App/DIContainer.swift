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
/// Non-critical services are lazily initialized for faster startup.
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

    // MARK: - Core Services (eager)

    /// Tab management service.
    let tabManager: TabManager

    /// Ad blocking service.
    let adBlockService: AdBlockService

    /// Network connectivity and system monitor.
    let networkMonitor: NetworkMonitor

    /// Tab suspension manager for memory optimization.
    let tabSuspensionManager: TabSuspensionManager

    // MARK: - Lazy Services (initialized on first access)

    /// Media player service for background audio and PiP.
    var mediaPlayerService: MediaPlayerService {
        if let existing = _mediaPlayerService { return existing }
        let service = MediaPlayerService(nowPlayingManager: nowPlayingManager)
        _mediaPlayerService = service
        return service
    }
    private var _mediaPlayerService: MediaPlayerService?

    /// Now playing info manager for lock screen controls.
    var nowPlayingManager: NowPlayingManager {
        if let existing = _nowPlayingManager { return existing }
        let manager = NowPlayingManager()
        _nowPlayingManager = manager
        return manager
    }
    private var _nowPlayingManager: NowPlayingManager?

    /// Download manager service.
    var downloadManager: DownloadManagerService {
        if let existing = _downloadManager { return existing }
        let service = DownloadManagerService(downloadRepository: downloadRepository)
        _downloadManager = service
        return service
    }
    private var _downloadManager: DownloadManagerService?

    /// Reader mode content extraction service.
    var readerModeService: ReaderModeServiceProtocol {
        if let existing = _readerModeService { return existing }
        let service = ReaderModeService()
        _readerModeService = service
        return service
    }
    private var _readerModeService: ReaderModeService?

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

            // Core services (eager — needed at startup)
            self.tabManager = TabManager(historyRepository: self.historyRepository)
            self.adBlockService = AdBlockService()
            self.networkMonitor = NetworkMonitor()
            self.tabSuspensionManager = TabSuspensionManager()
            self.readingListRepository = SwiftDataReadingListRepository(modelContext: context)
            self.httpsUpgradeService = HTTPSUpgradeService()
            self.appLockService = AppLockService()
            self.trackingProtectionService = TrackingProtectionService()
            self.fingerprintProtectionService = FingerprintProtectionService()

            // Wire tab suspension to tab manager and memory warnings
            self.tabSuspensionManager.configure(tabManager: self.tabManager)
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }
}
