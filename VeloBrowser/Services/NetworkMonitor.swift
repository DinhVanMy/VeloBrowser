// NetworkMonitor.swift
// VeloBrowser
//
// Monitors network connectivity status.

import Network
import Observation

/// Observes network path changes and publishes connectivity status.
///
/// Uses `NWPathMonitor` to detect online/offline state changes.
/// The browser can use this to show appropriate offline error pages.
@Observable
@MainActor
final class NetworkMonitor {
    /// Whether the device currently has a network connection.
    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.velobrowser.networkmonitor")

    /// Starts monitoring network connectivity.
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    /// Stops monitoring network connectivity.
    func stop() {
        monitor.cancel()
    }

    deinit {
        monitor.cancel()
    }
}
