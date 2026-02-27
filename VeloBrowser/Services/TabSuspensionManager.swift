// TabSuspensionManager.swift
// VeloBrowser
//
// Manages automatic suspension and resumption of inactive browser tabs
// to reduce memory usage.

import SwiftUI
import os

/// Tab lifecycle states.
enum TabLifecycleState: Sendable {
    /// Tab is actively loaded and visible or recently used.
    case active
    /// Tab content has been released to free memory.
    case suspended
}

/// Timeout options for tab suspension.
enum SuspensionTimeout: Int, CaseIterable, Sendable {
    case never = 0
    case threeMinutes = 180
    case fiveMinutes = 300
    case tenMinutes = 600

    /// Human-readable label.
    var label: String {
        switch self {
        case .never: return "Never"
        case .threeMinutes: return "3 Minutes"
        case .fiveMinutes: return "5 Minutes"
        case .tenMinutes: return "10 Minutes"
        }
    }
}

/// Protocol defining tab suspension operations.
@MainActor
protocol TabSuspensionManagerProtocol {
    /// Current lifecycle state for each tab.
    var tabStates: [UUID: TabLifecycleState] { get }

    /// Whether a tab is currently suspended.
    func isSuspended(_ tabID: UUID) -> Bool

    /// Marks a tab as active (e.g., when switched to).
    func markActive(_ tabID: UUID)

    /// Suspends a specific tab to free memory.
    func suspend(_ tabID: UUID)

    /// Handles a system memory warning by suspending inactive tabs.
    func handleMemoryWarning()

    /// Starts the periodic suspension timer.
    func start()

    /// Stops the periodic suspension timer.
    func stop()
}

/// Manages automatic suspension of inactive tabs based on configurable timeouts
/// and system memory pressure.
///
/// When a tab is suspended, its WKWebView content is released. When the user
/// switches back, the tab reloads from its last URL.
@Observable
@MainActor
final class TabSuspensionManager: TabSuspensionManagerProtocol {
    /// Current lifecycle state for each tab.
    private(set) var tabStates: [UUID: TabLifecycleState] = [:]

    /// Timestamps of last activity per tab.
    private var lastActivity: [UUID: Date] = [:]

    /// Timer for periodic suspension checks.
    private var timer: Timer?

    /// Reference to the tab manager for accessing tabs.
    private weak var tabManager: TabManager?

    private let signposter = OSSignposter(subsystem: "com.velobrowser.app", category: "TabSuspension")

    /// Whether tab suspension is enabled (read from UserDefaults).
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "tabSuspensionEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "tabSuspensionEnabled") }
    }

    /// Timeout in seconds before inactive tabs are suspended.
    var timeoutSeconds: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "tabSuspensionTimeout")
            return val > 0 ? val : SuspensionTimeout.fiveMinutes.rawValue
        }
        set { UserDefaults.standard.set(newValue, forKey: "tabSuspensionTimeout") }
    }

    /// The configured suspension timeout.
    var timeout: SuspensionTimeout {
        SuspensionTimeout(rawValue: timeoutSeconds) ?? .fiveMinutes
    }

    /// Number of currently suspended tabs.
    var suspendedCount: Int {
        tabStates.values.filter { $0 == .suspended }.count
    }

    /// Creates a new TabSuspensionManager.
    ///
    /// - Parameter tabManager: The tab manager to monitor.
    init(tabManager: TabManager? = nil) {
        self.tabManager = tabManager
        // Register default values
        UserDefaults.standard.register(defaults: [
            "tabSuspensionEnabled": true,
            "tabSuspensionTimeout": SuspensionTimeout.fiveMinutes.rawValue
        ])
    }

    /// Connects to a tab manager for monitoring.
    func configure(tabManager: TabManager) {
        self.tabManager = tabManager
    }

    /// Starts the periodic suspension check timer.
    func start() {
        stop()
        guard isEnabled, timeout != .never else { return }

        let interval: TimeInterval = 30
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForSuspension()
            }
        }
    }

    /// Stops the suspension timer.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Whether a tab is currently suspended.
    func isSuspended(_ tabID: UUID) -> Bool {
        tabStates[tabID] == .suspended
    }

    /// Marks a tab as active, recording the current timestamp.
    func markActive(_ tabID: UUID) {
        tabStates[tabID] = .active
        lastActivity[tabID] = Date()
    }

    /// Suspends a tab, releasing its WKWebView content.
    func suspend(_ tabID: UUID) {
        guard tabStates[tabID] != .suspended else { return }
        let state = signposter.beginInterval("suspend", id: signposter.makeSignpostID())
        tabStates[tabID] = .suspended
        // The actual WKWebView cleanup is handled by TabManager when it detects suspension
        signposter.endInterval("suspend", state)
    }

    /// Handles a system memory warning by immediately suspending all inactive tabs.
    func handleMemoryWarning() {
        guard let tabManager else { return }
        let activeID = tabManager.activeTab?.id

        for tab in tabManager.tabs where tab.id != activeID {
            if tabStates[tab.id] != .suspended {
                suspend(tab.id)
            }
        }
    }

    /// Removes tracking for a closed tab.
    func removeTab(_ tabID: UUID) {
        tabStates.removeValue(forKey: tabID)
        lastActivity.removeValue(forKey: tabID)
    }

    // MARK: - Private

    /// Checks all tabs and suspends those that have been inactive longer than the timeout.
    private func checkForSuspension() {
        guard isEnabled, timeout != .never, let tabManager else { return }
        let now = Date()
        let threshold = TimeInterval(timeoutSeconds)
        let activeID = tabManager.activeTab?.id

        for tab in tabManager.tabs where tab.id != activeID {
            let lastActive = lastActivity[tab.id] ?? tab.lastAccessedAt
            if now.timeIntervalSince(lastActive) > threshold {
                if tabStates[tab.id] != .suspended {
                    suspend(tab.id)
                }
            }
        }
    }

    nonisolated deinit {
        // Timer cleanup — already invalidated by stop() in normal flow
    }
}
