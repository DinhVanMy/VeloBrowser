// HTTPSUpgradeServiceTests.swift
// VeloBrowserTests
//
// Unit tests for HTTPSUpgradeService URL upgrading and exception handling.

import Testing
import Foundation
@testable import VeloBrowser

@MainActor
@Suite("HTTPSUpgrade Tests")
struct HTTPSUpgradeServiceTests {

    private func makeService(enabled: Bool = true) -> HTTPSUpgradeService {
        let service = HTTPSUpgradeService()
        service.isEnabled = enabled
        // Clear exceptions for clean test state
        service.exceptions = []
        return service
    }

    @Test("Upgrades HTTP to HTTPS")
    func upgradesHTTP() {
        let service = makeService()
        let url = URL(string: "http://example.com/page")!
        let result = service.upgradeURL(url)
        #expect(result?.scheme == "https")
        #expect(result?.host() == "example.com")
        #expect(result?.path() == "/page")
    }

    @Test("Does not change HTTPS URLs")
    func doesNotChangeHTTPS() {
        let service = makeService()
        let url = URL(string: "https://example.com/page")!
        let result = service.upgradeURL(url)
        #expect(result == nil)
    }

    @Test("Returns nil when disabled")
    func disabledReturnsNil() {
        let service = makeService(enabled: false)
        let url = URL(string: "http://example.com")!
        let result = service.upgradeURL(url)
        #expect(result == nil)
    }

    @Test("Respects domain exceptions")
    func respectsExceptions() {
        let service = makeService()
        service.addException(for: "legacy.example.com")
        let url = URL(string: "http://legacy.example.com/old-page")!
        let result = service.upgradeURL(url)
        #expect(result == nil)
    }

    @Test("Add and remove exceptions")
    func addRemoveExceptions() {
        let service = makeService()
        service.addException(for: "test.com")
        #expect(service.hasException(for: "test.com") == true)

        service.removeException(for: "test.com")
        #expect(service.hasException(for: "test.com") == false)
    }

    @Test("Exception matching is case-insensitive")
    func caseInsensitiveExceptions() {
        let service = makeService()
        service.addException(for: "Example.COM")
        #expect(service.hasException(for: "example.com") == true)
    }

    @Test("Preserves query parameters during upgrade")
    func preservesQueryParams() {
        let service = makeService()
        let url = URL(string: "http://example.com/search?q=test&page=2")!
        let result = service.upgradeURL(url)
        #expect(result?.absoluteString == "https://example.com/search?q=test&page=2")
    }

    @Test("Does not upgrade non-HTTP schemes")
    func nonHTTPSchemes() {
        let service = makeService()
        let url = URL(string: "ftp://example.com/file")!
        let result = service.upgradeURL(url)
        #expect(result == nil)
    }

    @Test("Records upgrade count")
    func recordsUpgradeCount() {
        let service = makeService()
        let before = service.upgradeCount
        service.recordUpgrade()
        #expect(service.upgradeCount == before + 1)
    }
}
