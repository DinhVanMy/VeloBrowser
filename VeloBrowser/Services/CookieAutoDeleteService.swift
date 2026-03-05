// CookieAutoDeleteService.swift
// VeloBrowser
//
// Automatically deletes cookies after leaving a site, with whitelist support.

import Foundation
import WebKit
import os.log

/// Service that auto-deletes cookies when navigating away from a site.
@Observable
@MainActor
final class CookieAutoDeleteService {
    /// Whether auto-delete is enabled.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cookieAutoDelete") }
        set { UserDefaults.standard.set(newValue, forKey: "cookieAutoDelete") }
    }

    /// Delay in seconds before deleting cookies after leaving a site.
    var deleteDelay: TimeInterval {
        get { UserDefaults.standard.double(forKey: "cookieDeleteDelay").clamped(to: 30...3600) }
        set { UserDefaults.standard.set(newValue, forKey: "cookieDeleteDelay") }
    }

    /// Whitelisted domains whose cookies are preserved.
    var whitelist: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: "cookieWhitelist") ?? []
            return Set(array)
        }
        set { UserDefaults.standard.set(Array(newValue), forKey: "cookieWhitelist") }
    }

    /// The domain the user is currently browsing.
    private var currentDomain: String?

    /// Pending cleanup tasks keyed by domain.
    private var pendingCleanup: [String: Task<Void, Never>] = [:]

    init() {
        // Default delay: 60 seconds
        if UserDefaults.standard.object(forKey: "cookieDeleteDelay") == nil {
            UserDefaults.standard.set(60.0, forKey: "cookieDeleteDelay")
        }
    }

    /// Called when user navigates to a new URL.
    func didNavigate(to url: URL?) {
        guard isEnabled else { return }
        let newDomain = url?.host()?.replacingOccurrences(of: "www.", with: "")

        if let old = currentDomain, old != newDomain, !whitelist.contains(old) {
            scheduleCleanup(for: old)
        }

        // Cancel cleanup if user returns to the domain
        if let newDomain, let task = pendingCleanup[newDomain] {
            task.cancel()
            pendingCleanup.removeValue(forKey: newDomain)
        }

        currentDomain = newDomain
    }

    /// Adds a domain to the whitelist.
    func addToWhitelist(_ domain: String) {
        let cleaned = domain.replacingOccurrences(of: "www.", with: "")
        whitelist.insert(cleaned)
    }

    /// Removes a domain from the whitelist.
    func removeFromWhitelist(_ domain: String) {
        whitelist.remove(domain)
    }

    /// Whether the current site is whitelisted.
    func isCurrentSiteWhitelisted() -> Bool {
        guard let domain = currentDomain else { return false }
        return whitelist.contains(domain)
    }

    /// Toggles whitelist status for the current site.
    func toggleCurrentSiteWhitelist() {
        guard let domain = currentDomain else { return }
        if whitelist.contains(domain) {
            removeFromWhitelist(domain)
        } else {
            addToWhitelist(domain)
        }
    }

    private func scheduleCleanup(for domain: String) {
        pendingCleanup[domain]?.cancel()
        let delay = deleteDelay
        pendingCleanup[domain] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.deleteCookies(for: domain)
        }
    }

    private func deleteCookies(for domain: String) async {
        let store = WKWebsiteDataStore.default()
        let records = await store.dataRecords(ofTypes: [WKWebsiteDataTypeCookies])
        let matching = records.filter { record in
            record.displayName.contains(domain)
        }
        guard !matching.isEmpty else { return }
        await store.removeData(ofTypes: [WKWebsiteDataTypeCookies], for: matching)
        os_log(.info, "Auto-deleted cookies for %@", domain)
        pendingCleanup.removeValue(forKey: domain)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
