// TabManager.swift
// VeloBrowser
//
// Service managing browser tabs — create, close, switch, reorder.

import SwiftUI
import WebKit

/// Protocol defining tab management operations.
@MainActor
protocol TabManagerProtocol {
    /// All currently open tabs.
    var tabs: [Tab] { get }

    /// The currently active tab.
    var activeTab: Tab? { get }

    /// The index of the active tab.
    var activeTabIndex: Int? { get }

    /// Creates a new tab and makes it active.
    @discardableResult
    func createTab(url: URL?, isPrivate: Bool) -> Tab

    /// Closes a tab by its ID.
    func closeTab(id: UUID)

    /// Switches to a tab by its ID.
    func switchToTab(id: UUID)

    /// Reorders tabs.
    func moveTab(from source: IndexSet, to destination: Int)

    /// Closes all tabs (optionally only private ones).
    func closeAllTabs(privateOnly: Bool)
}

/// Manages the browser's tab collection.
///
/// Enforces a maximum of 100 tabs, handles private browsing tabs
/// with separate data stores, and provides the active tab's
/// ``BrowserViewModel``.
@Observable
@MainActor
final class TabManager: TabManagerProtocol {
    /// Maximum number of allowed tabs.
    static let maxTabs = 100

    /// All open tabs.
    private(set) var tabs: [Tab] = []

    /// Currently active tab, derived from the tabs array.
    var activeTab: Tab? {
        tabs.first { $0.isActive }
    }

    /// Index of the currently active tab.
    var activeTabIndex: Int? {
        tabs.firstIndex { $0.isActive }
    }

    /// View models keyed by tab ID.
    private(set) var viewModels: [UUID: BrowserViewModel] = [:]

    /// Tab page snapshots keyed by tab ID.
    private(set) var snapshots: [UUID: UIImage] = [:]

    /// The view model for the active tab.
    var activeViewModel: BrowserViewModel? {
        guard let tab = activeTab else { return nil }
        return viewModels[tab.id]
    }

    /// Number of open tabs.
    var tabCount: Int { tabs.count }

    // MARK: - Dependencies

    private let historyRepository: HistoryRepositoryProtocol

    // MARK: - Init

    /// Creates a new TabManager.
    ///
    /// - Parameter historyRepository: Repository for recording browsing history in tab view models.
    init(historyRepository: HistoryRepositoryProtocol) {
        self.historyRepository = historyRepository
        // Restore persisted tabs or create initial blank tab
        if !restoreTabs() {
            createTab(url: nil, isPrivate: false)
        }
    }

    // MARK: - Tab Persistence

    /// Key used to store tab data in UserDefaults.
    private static let tabsStorageKey = "persistedTabs"

    /// Lightweight structure for serializing tab state to disk.
    private struct PersistedTab: Codable {
        let urlString: String?
        let title: String
        let isActive: Bool
    }

    /// Saves the current non-private tabs to UserDefaults.
    ///
    /// Call this when the app enters the background or is about to terminate.
    /// Private tabs are intentionally NOT persisted.
    func saveTabs() {
        let persistable = tabs.compactMap { tab -> PersistedTab? in
            guard !tab.isPrivate else { return nil }
            return PersistedTab(
                urlString: tab.url?.absoluteString,
                title: tab.title,
                isActive: tab.isActive
            )
        }
        guard !persistable.isEmpty else { return }
        if let data = try? JSONEncoder().encode(persistable) {
            UserDefaults.standard.set(data, forKey: Self.tabsStorageKey)
        }
    }

    /// Restores previously saved tabs from UserDefaults.
    ///
    /// - Returns: `true` if tabs were successfully restored.
    @discardableResult
    private func restoreTabs() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.tabsStorageKey),
              let persisted = try? JSONDecoder().decode([PersistedTab].self, from: data),
              !persisted.isEmpty else {
            return false
        }

        // Clear storage after reading to avoid stale state
        UserDefaults.standard.removeObject(forKey: Self.tabsStorageKey)

        var restoredAny = false
        var hasActiveTab = false

        for saved in persisted {
            let url = saved.urlString.flatMap { URL(string: $0) }
            let tab = Tab(
                url: url,
                title: saved.title,
                isPrivate: false,
                isActive: saved.isActive,
                createdAt: .now,
                lastAccessedAt: .now
            )

            if tab.isActive {
                // Deactivate any previously active tab
                for index in tabs.indices { tabs[index].isActive = false }
                hasActiveTab = true
            }

            tabs.append(tab)

            let vm = BrowserViewModel(
                historyRepository: historyRepository,
                searchEngineTemplate: searchEngineTemplate,
                isPrivate: false
            )
            if let url {
                vm.loadURL(url)
            }
            viewModels[tab.id] = vm
            restoredAny = true
        }

        // Ensure at least one tab is active
        if restoredAny && !hasActiveTab {
            tabs[tabs.count - 1].isActive = true
        }

        return restoredAny
    }

    // MARK: - Tab Operations

    /// Updates a tab's title, URL, and/or favicon from its ViewModel state.
    ///
    /// - Parameters:
    ///   - id: The tab ID to update.
    ///   - title: New page title.
    ///   - url: New page URL.
    ///   - faviconURL: Detected favicon URL.
    func updateTab(id: UUID, title: String? = nil, url: URL? = nil, faviconURL: URL? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if let title, !title.isEmpty {
            tabs[index].title = title
        }
        if let url {
            tabs[index].url = url
        }
        if let faviconURL {
            tabs[index].faviconURL = faviconURL
        }
    }

    /// Resets a tab to the home/new-tab state.
    ///
    /// Clears the URL, resets the title, and removes the snapshot.
    /// - Parameter id: The tab ID to reset.
    func resetTabToHome(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].url = nil
        tabs[index].title = "New Tab"
        tabs[index].faviconURL = nil
        snapshots.removeValue(forKey: id)
    }

    /// Returns the current search engine URL template from user preferences.
    private var searchEngineTemplate: String {
        let savedEngine = UserDefaults.standard.string(forKey: "searchEngine") ?? SearchEngine.google.rawValue
        let engine = SearchEngine(rawValue: savedEngine) ?? .google
        return engine.urlTemplate
    }

    /// Creates a new tab and makes it active.
    ///
    /// - Parameters:
    ///   - url: Optional URL to load in the new tab.
    ///   - isPrivate: Whether this is a private browsing tab.
    /// - Returns: The newly created tab.
    @discardableResult
    func createTab(url: URL? = nil, isPrivate: Bool = false) -> Tab {
        guard tabs.count < Self.maxTabs else {
            // If at max, return the current active tab
            return activeTab ?? tabs[0]
        }

        // Deactivate all current tabs
        for index in tabs.indices {
            tabs[index].isActive = false
        }

        let tab = Tab(
            url: url,
            title: url?.host() ?? "New Tab",
            isPrivate: isPrivate,
            isActive: true,
            createdAt: .now,
            lastAccessedAt: .now
        )

        tabs.append(tab)

        // Create corresponding view model with current search engine
        let vm = BrowserViewModel(
            historyRepository: historyRepository,
            searchEngineTemplate: searchEngineTemplate,
            isPrivate: isPrivate
        )
        if let url {
            vm.loadURL(url)
        }
        viewModels[tab.id] = vm

        return tab
    }

    /// Closes a tab by its ID.
    ///
    /// If the closed tab was active, the adjacent tab becomes active.
    /// If it's the last tab, a new blank tab is created.
    ///
    /// - Parameter id: The tab ID to close.
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let wasActive = tabs[index].isActive
        tabs.remove(at: index)
        viewModels.removeValue(forKey: id)
        snapshots.removeValue(forKey: id)

        if tabs.isEmpty {
            // Always keep at least one tab
            createTab(url: nil, isPrivate: false)
            return
        }

        if wasActive {
            // Activate the closest tab
            let newIndex = min(index, tabs.count - 1)
            tabs[newIndex].isActive = true
            tabs[newIndex].lastAccessedAt = .now
        }
    }

    /// Captures a snapshot of the current tab's web view.
    func captureSnapshot(for tabID: UUID) {
        guard let vm = viewModels[tabID], let webView = vm.webView else { return }
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            Task { @MainActor in
                if let image {
                    self?.snapshots[tabID] = image
                }
            }
        }
    }

    /// Switches to a tab by its ID.
    ///
    /// Captures a snapshot of the current tab before switching.
    ///
    /// - Parameter id: The tab ID to make active.
    func switchToTab(id: UUID) {
        // Capture snapshot of the outgoing tab
        if let currentTab = activeTab, currentTab.id != id {
            captureSnapshot(for: currentTab.id)
        }

        for index in tabs.indices {
            let isTarget = tabs[index].id == id
            tabs[index].isActive = isTarget
            if isTarget {
                tabs[index].lastAccessedAt = .now
            }
        }
    }

    /// Reorders tabs via drag-and-drop.
    ///
    /// - Parameters:
    ///   - source: Source indices to move.
    ///   - destination: Destination index.
    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    /// Closes all tabs, or only private ones.
    ///
    /// - Parameter privateOnly: When `true`, only closes private tabs.
    func closeAllTabs(privateOnly: Bool = false) {
        if privateOnly {
            let privateIDs = tabs.filter(\.isPrivate).map(\.id)
            for id in privateIDs {
                closeTab(id: id)
            }
        } else {
            tabs.removeAll()
            viewModels.removeAll()
            createTab(url: nil, isPrivate: false)
        }
    }
}
