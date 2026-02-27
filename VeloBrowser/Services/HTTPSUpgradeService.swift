// HTTPSUpgradeService.swift
// VeloBrowser
//
// Service for upgrading HTTP requests to HTTPS and managing per-site exceptions.

import Foundation

/// Defines the contract for HTTPS upgrade operations.
///
/// When enabled, intercepts HTTP requests and upgrades them to HTTPS.
/// Maintains a per-site exception list for sites that don't support HTTPS.
@MainActor
protocol HTTPSUpgradeServiceProtocol: Sendable {
    /// Whether HTTPS-only mode is currently enabled.
    var isEnabled: Bool { get }

    /// Total number of HTTPS upgrades performed.
    var upgradeCount: Int { get }

    /// Attempts to upgrade an HTTP URL to HTTPS.
    ///
    /// - Parameter url: The URL to potentially upgrade.
    /// - Returns: The upgraded HTTPS URL, or `nil` if no upgrade is needed/possible.
    func upgradeURL(_ url: URL) -> URL?

    /// Checks whether a domain has an HTTP exception.
    ///
    /// - Parameter domain: The domain to check.
    /// - Returns: `true` if the domain is allowed to use HTTP.
    func hasException(for domain: String) -> Bool

    /// Adds an HTTP exception for a domain.
    ///
    /// - Parameter domain: The domain to exempt from HTTPS upgrade.
    func addException(for domain: String)

    /// Removes an HTTP exception for a domain.
    ///
    /// - Parameter domain: The domain to remove from exceptions.
    func removeException(for domain: String)

    /// All domains with HTTP exceptions.
    var exceptions: Set<String> { get }

    /// Increments the upgrade counter.
    func recordUpgrade()
}

/// Upgrades HTTP requests to HTTPS with per-site exception management.
@Observable
@MainActor
final class HTTPSUpgradeService: HTTPSUpgradeServiceProtocol {
    /// Whether HTTPS-only mode is active.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "httpsOnlyMode") }
        set { UserDefaults.standard.set(newValue, forKey: "httpsOnlyMode") }
    }

    /// Total HTTPS upgrades performed.
    var upgradeCount: Int {
        get { UserDefaults.standard.integer(forKey: "httpsUpgradeCount") }
        set { UserDefaults.standard.set(newValue, forKey: "httpsUpgradeCount") }
    }

    /// Domains exempt from HTTPS upgrade.
    var exceptions: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: "httpsExceptions") ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "httpsExceptions")
        }
    }

    func upgradeURL(_ url: URL) -> URL? {
        guard isEnabled,
              url.scheme?.lowercased() == "http",
              let host = url.host()?.lowercased(),
              !hasException(for: host) else {
            return nil
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url
    }

    func hasException(for domain: String) -> Bool {
        exceptions.contains(domain.lowercased())
    }

    func addException(for domain: String) {
        var current = exceptions
        current.insert(domain.lowercased())
        exceptions = current
    }

    func removeException(for domain: String) {
        var current = exceptions
        current.remove(domain.lowercased())
        exceptions = current
    }

    func recordUpgrade() {
        upgradeCount += 1
    }
}
