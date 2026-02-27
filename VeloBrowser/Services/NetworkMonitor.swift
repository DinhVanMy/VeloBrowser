// NetworkMonitor.swift
// VeloBrowser
//
// Monitors network connectivity and system power state.

import Network
import Observation
import UIKit

/// Observes network path changes, power state, and memory pressure.
///
/// Uses `NWPathMonitor` to detect online/offline state changes,
/// monitors Low Power Mode for battery optimization, and listens
/// for memory warnings.
@Observable
@MainActor
final class NetworkMonitor {
    /// Whether the device currently has a network connection.
    private(set) var isConnected: Bool = true

    /// Whether the device is in Low Power Mode.
    private(set) var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// Callback invoked on memory warning.
    var onMemoryWarning: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.velobrowser.networkmonitor")

    /// Adaptive animation duration multiplier (reduced in Low Power Mode).
    var animationMultiplier: Double {
        isLowPowerMode ? 0.5 : 1.0
    }

    /// Starts monitoring network connectivity, power state, and memory pressure.
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)

        // Low Power Mode monitoring
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }

        // Memory warning monitoring
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onMemoryWarning?()
            }
        }
    }

    /// Stops monitoring network connectivity.
    func stop() {
        monitor.cancel()
    }

    deinit {
        monitor.cancel()
    }
}
