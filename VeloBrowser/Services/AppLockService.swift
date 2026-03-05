// AppLockService.swift
// VeloBrowser
//
// Service for biometric app lock using Face ID or Touch ID.

import Foundation
import LocalAuthentication

/// Lock timeout options for biometric app lock.
enum LockTimeout: String, CaseIterable, Identifiable, Sendable {
    case immediately = "Immediately"
    case oneMinute = "1 Minute"
    case fiveMinutes = "5 Minutes"
    case fifteenMinutes = "15 Minutes"
    case thirtyMinutes = "30 Minutes"

    var id: String { rawValue }

    /// The timeout interval in seconds.
    var interval: TimeInterval {
        switch self {
        case .immediately: return 0
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        }
    }
}

/// Defines the contract for biometric app lock operations.
@MainActor
protocol AppLockServiceProtocol: Sendable {
    /// Whether app lock is enabled by the user.
    var isLockEnabled: Bool { get set }

    /// Whether the app is currently locked.
    var isLocked: Bool { get set }

    /// The biometry type available on this device.
    var biometryType: LABiometryType { get }

    /// Whether the device supports biometric authentication.
    var isBiometricAvailable: Bool { get }

    /// The configured lock timeout.
    var lockTimeout: LockTimeout { get set }

    /// Attempts to unlock the app using biometrics.
    func authenticate() async -> Bool

    /// Called when the app enters background — records timestamp.
    func appDidEnterBackground()

    /// Called when the app becomes active — determines if lock is needed.
    func appDidBecomeActive()
}

/// Manages biometric app lock with Face ID / Touch ID.
@Observable
@MainActor
final class AppLockService: AppLockServiceProtocol {
    /// Whether the user has enabled app lock.
    var isLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "appLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "appLockEnabled") }
    }

    /// Whether the app is currently locked and requires authentication.
    var isLocked: Bool = false

    /// The configured lock timeout option.
    var lockTimeout: LockTimeout {
        get {
            let raw = UserDefaults.standard.string(forKey: "lockTimeout") ?? LockTimeout.immediately.rawValue
            return LockTimeout(rawValue: raw) ?? .immediately
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "lockTimeout")
        }
    }

    /// The biometry type supported by this device.
    private(set) var biometryType: LABiometryType = .none

    /// Whether biometric auth is available.
    var isBiometricAvailable: Bool {
        biometryType != .none
    }

    /// Timestamp when the app last entered background.
    private var lastBackgroundTimestamp: Date?

    init() {
        checkBiometricAvailability()
    }

    /// Attempts biometric authentication.
    ///
    /// - Returns: `true` if authentication succeeded.
    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        let reason = biometryType == .faceID
            ? "Unlock VelGo with Face ID"
            : "Unlock VelGo with Touch ID"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                isLocked = false
            }
            return success
        } catch {
            return false
        }
    }

    /// Records the background timestamp for timeout calculation.
    func appDidEnterBackground() {
        if isLockEnabled {
            lastBackgroundTimestamp = Date()
        }
    }

    /// Checks if the app should be locked based on timeout.
    func appDidBecomeActive() {
        guard isLockEnabled else {
            isLocked = false
            return
        }

        guard let lastBackground = lastBackgroundTimestamp else {
            // First launch with lock enabled
            isLocked = true
            return
        }

        let elapsed = Date().timeIntervalSince(lastBackground)
        if elapsed >= lockTimeout.interval {
            isLocked = true
        }
    }

    // MARK: - Private

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometryType = context.biometryType
        } else {
            biometryType = .none
        }
    }
}
