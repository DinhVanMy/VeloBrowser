// TabManagerTests.swift
// VeloBrowserTests
//
// Unit tests for TabManager tab lifecycle operations.

import Testing
import Foundation
@testable import VeloBrowser

@MainActor
@Suite("TabManager Tests")
struct TabManagerTests {
    let container: DIContainer

    init() {
        // Clear persisted tabs to avoid cross-test contamination
        UserDefaults.standard.removeObject(forKey: "persistedTabs")
        container = DIContainer(inMemory: true)
    }

    private var tabManager: TabManager { container.tabManager }

    // MARK: - Initial State

    @Test("TabManager starts with one tab")
    func testInitialTab() {
        #expect(tabManager.tabCount == 1)
        #expect(tabManager.activeTab != nil)
        #expect(tabManager.activeViewModel != nil)
    }

    // MARK: - Create Tab

    @Test("Creating a tab increases count and makes new tab active")
    func testCreateTab() {
        let initialCount = tabManager.tabCount
        let newTab = tabManager.createTab(url: nil, isPrivate: false)

        #expect(tabManager.tabCount == initialCount + 1)
        #expect(tabManager.activeTab?.id == newTab.id)
    }

    @Test("Creating a tab with URL loads that URL")
    func testCreateTabWithURL() {
        let url = URL(string: "https://example.com")!
        let tab = tabManager.createTab(url: url, isPrivate: false)
        let vm = tabManager.viewModels[tab.id]

        #expect(vm?.pendingURL == url)
    }

    @Test("Creating a private tab marks it private")
    func testCreatePrivateTab() {
        let tab = tabManager.createTab(url: nil, isPrivate: true)

        #expect(tab.isPrivate == true)
        #expect(tabManager.viewModels[tab.id]?.isPrivate == true)
    }

    @Test("Max 100 tabs enforced")
    func testMaxTabs() {
        // Already has 1 tab from init
        for _ in 1..<100 {
            tabManager.createTab(url: nil, isPrivate: false)
        }
        #expect(tabManager.tabCount == 100)

        // 101st should not increase count
        let overflow = tabManager.createTab(url: nil, isPrivate: false)
        #expect(tabManager.tabCount == 100)
        // Should return existing active tab
        #expect(overflow.id == tabManager.activeTab?.id)
    }

    // MARK: - Close Tab

    @Test("Closing a tab reduces count")
    func testCloseTab() {
        let tab = tabManager.createTab(url: nil, isPrivate: false)
        let countBefore = tabManager.tabCount
        tabManager.closeTab(id: tab.id)

        #expect(tabManager.tabCount == countBefore - 1)
    }

    @Test("Closing last tab creates a new one")
    func testCloseLastTab() {
        // Close all but one
        while tabManager.tabCount > 1 {
            if let first = tabManager.tabs.first {
                tabManager.closeTab(id: first.id)
            }
        }

        let lastID = tabManager.tabs[0].id
        tabManager.closeTab(id: lastID)

        // Should still have one tab (auto-created)
        #expect(tabManager.tabCount == 1)
        #expect(tabManager.tabs[0].id != lastID)
    }

    @Test("Closing active tab activates adjacent tab")
    func testCloseActiveTabActivatesAdjacent() {
        tabManager.createTab(url: nil, isPrivate: false)
        let middleTab = tabManager.createTab(url: nil, isPrivate: false)
        tabManager.createTab(url: nil, isPrivate: false)

        // Switch to middle tab then close it
        tabManager.switchToTab(id: middleTab.id)
        tabManager.closeTab(id: middleTab.id)

        #expect(tabManager.activeTab != nil)
        #expect(tabManager.activeTab?.id != middleTab.id)
    }

    // MARK: - Switch Tab

    @Test("switchToTab activates the correct tab")
    func testSwitchToTab() {
        let firstTabID = tabManager.tabs[0].id
        let secondTab = tabManager.createTab(url: nil, isPrivate: false)

        // Second tab is now active; switch back to first
        tabManager.switchToTab(id: firstTabID)

        #expect(tabManager.activeTab?.id == firstTabID)
        #expect(tabManager.tabs.first(where: { $0.id == secondTab.id })?.isActive == false)
    }

    // MARK: - Close All

    @Test("closeAllTabs privateOnly closes only private tabs")
    func testCloseAllPrivateOnly() {
        tabManager.createTab(url: nil, isPrivate: true)
        tabManager.createTab(url: nil, isPrivate: true)
        let normalCount = tabManager.tabs.filter { !$0.isPrivate }.count
        let privateCount = tabManager.tabs.filter(\.isPrivate).count

        #expect(privateCount == 2)

        tabManager.closeAllTabs(privateOnly: true)

        #expect(tabManager.tabs.filter(\.isPrivate).count == 0)
        #expect(tabManager.tabs.filter { !$0.isPrivate }.count >= normalCount)
    }

    @Test("closeAllTabs replaces everything with a new blank tab")
    func testCloseAllTabs() {
        tabManager.createTab(url: nil, isPrivate: false)
        tabManager.createTab(url: nil, isPrivate: true)

        tabManager.closeAllTabs(privateOnly: false)

        #expect(tabManager.tabCount == 1)
        #expect(tabManager.activeTab != nil)
    }

    // MARK: - Reorder

    @Test("moveTab reorders tabs")
    func testMoveTab() {
        let tab1 = tabManager.tabs[0]
        let tab2 = tabManager.createTab(url: nil, isPrivate: false)
        let tab3 = tabManager.createTab(url: nil, isPrivate: false)

        tabManager.moveTab(from: IndexSet(integer: 0), to: 3)

        #expect(tabManager.tabs[0].id == tab2.id)
        #expect(tabManager.tabs[1].id == tab3.id)
        #expect(tabManager.tabs[2].id == tab1.id)
    }
}
