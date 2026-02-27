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
        // Create initial tab
        createTab(url: nil, isPrivate: false)
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

    /// Switches to a tab by its ID.
    ///
    /// - Parameter id: The tab ID to make active.
    func switchToTab(id: UUID) {
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
