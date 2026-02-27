// TabSuspensionManagerTests.swift
// VeloBrowserTests
//
// Tests for TabSuspensionManager: suspend/resume lifecycle,
// memory warning handling, and timeout behavior.

import Testing
import Foundation
@testable import VeloBrowser

@MainActor
@Suite("TabSuspensionManager Tests")
struct TabSuspensionManagerTests {

    // MARK: - Initial State

    @Test("Initial state has no tab states")
    func initialState() {
        let manager = TabSuspensionManager()
        #expect(manager.tabStates.isEmpty)
        #expect(manager.suspendedCount == 0)
    }

    // MARK: - Mark Active

    @Test("markActive sets tab to active state")
    func markActive() {
        let manager = TabSuspensionManager()
        let tabID = UUID()
        manager.markActive(tabID)
        #expect(manager.tabStates[tabID] == .active)
        #expect(!manager.isSuspended(tabID))
    }

    // MARK: - Suspend

    @Test("suspend changes tab state to suspended")
    func suspendTab() {
        let manager = TabSuspensionManager()
        let tabID = UUID()
        manager.markActive(tabID)
        manager.suspend(tabID)
        #expect(manager.tabStates[tabID] == .suspended)
        #expect(manager.isSuspended(tabID))
        #expect(manager.suspendedCount == 1)
    }

    @Test("suspending already suspended tab is no-op")
    func doubleSuspend() {
        let manager = TabSuspensionManager()
        let tabID = UUID()
        manager.markActive(tabID)
        manager.suspend(tabID)
        manager.suspend(tabID) // Should not crash or change
        #expect(manager.isSuspended(tabID))
        #expect(manager.suspendedCount == 1)
    }

    // MARK: - Resume (Mark Active after Suspend)

    @Test("markActive resumes a suspended tab")
    func resumeSuspended() {
        let manager = TabSuspensionManager()
        let tabID = UUID()
        manager.suspend(tabID)
        #expect(manager.isSuspended(tabID))
        manager.markActive(tabID)
        #expect(!manager.isSuspended(tabID))
        #expect(manager.tabStates[tabID] == .active)
    }

    // MARK: - Remove Tab

    @Test("removeTab clears all tracking for the tab")
    func removeTab() {
        let manager = TabSuspensionManager()
        let tabID = UUID()
        manager.markActive(tabID)
        manager.removeTab(tabID)
        #expect(manager.tabStates[tabID] == nil)
        #expect(!manager.isSuspended(tabID))
    }

    // MARK: - Memory Warning

    @Test("handleMemoryWarning suspends all non-active tabs")
    func memoryWarning() {
        let container = DIContainer(inMemory: true)
        let tabManager = container.tabManager
        let manager = TabSuspensionManager(tabManager: tabManager)

        // TabManager starts with 1 tab; create 2 more for total of 3
        tabManager.createTab()
        tabManager.createTab()

        let tabs = tabManager.tabs
        #expect(tabs.count == 3)

        // Mark all as active
        for tab in tabs {
            manager.markActive(tab.id)
        }

        // Active tab is the last one (most recently created)
        let activeID = tabManager.activeTab?.id

        manager.handleMemoryWarning()

        // Active tab stays active, others suspended
        for tab in tabs {
            if tab.id == activeID {
                #expect(!manager.isSuspended(tab.id))
            } else {
                #expect(manager.isSuspended(tab.id))
            }
        }
    }

    // MARK: - Suspended Count

    @Test("suspendedCount reflects correct number")
    func suspendedCount() {
        let manager = TabSuspensionManager()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        manager.markActive(id1)
        manager.markActive(id2)
        manager.markActive(id3)
        #expect(manager.suspendedCount == 0)

        manager.suspend(id1)
        #expect(manager.suspendedCount == 1)

        manager.suspend(id2)
        #expect(manager.suspendedCount == 2)

        manager.markActive(id1) // Resume
        #expect(manager.suspendedCount == 1)
    }

    // MARK: - Start/Stop

    @Test("start and stop do not crash")
    func startStop() {
        let manager = TabSuspensionManager()
        manager.start()
        manager.stop()
        // No assertion needed — just verify no crash
    }

    @Test("isSuspended returns false for unknown tab")
    func unknownTab() {
        let manager = TabSuspensionManager()
        #expect(!manager.isSuspended(UUID()))
    }
}
