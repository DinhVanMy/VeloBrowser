// AdBlockServiceTests.swift
// VeloBrowserTests
//
// Unit tests for AdBlockService whitelist and toggle logic.

import Testing
import Foundation
@testable import VeloBrowser

@MainActor
@Suite("AdBlockService Tests")
struct AdBlockServiceTests {

    private func makeService() -> AdBlockService {
        // Clean up UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "adBlockEnabled")
        UserDefaults.standard.removeObject(forKey: "adBlockWhitelist")
        return AdBlockService()
    }

    // MARK: - Default State

    @Test("Ad blocker is enabled by default")
    func testDefaultEnabled() {
        let service = makeService()
        #expect(service.isEnabled == true)
    }

    @Test("Whitelist is empty by default")
    func testDefaultEmptyWhitelist() {
        let service = makeService()
        #expect(service.whitelist.isEmpty)
    }

    // MARK: - Toggle

    @Test("Disabling ad blocker persists to UserDefaults")
    func testDisable() {
        let service = makeService()
        service.isEnabled = false

        #expect(service.isEnabled == false)
        #expect(UserDefaults.standard.bool(forKey: "adBlockEnabled") == false)
    }

    @Test("Re-enabling ad blocker persists to UserDefaults")
    func testReEnable() {
        let service = makeService()
        service.isEnabled = false
        service.isEnabled = true

        #expect(service.isEnabled == true)
        #expect(UserDefaults.standard.bool(forKey: "adBlockEnabled") == true)
    }

    // MARK: - Whitelist

    @Test("Add domain to whitelist")
    func testAddToWhitelist() {
        let service = makeService()
        service.addToWhitelist("example.com")

        #expect(service.isWhitelisted("example.com") == true)
        #expect(service.whitelist.count == 1)
    }

    @Test("Whitelist is case-insensitive")
    func testWhitelistCaseInsensitive() {
        let service = makeService()
        service.addToWhitelist("Example.COM")

        #expect(service.isWhitelisted("example.com") == true)
        #expect(service.isWhitelisted("EXAMPLE.COM") == true)
    }

    @Test("Remove domain from whitelist")
    func testRemoveFromWhitelist() {
        let service = makeService()
        service.addToWhitelist("example.com")
        service.removeFromWhitelist("example.com")

        #expect(service.isWhitelisted("example.com") == false)
        #expect(service.whitelist.isEmpty)
    }

    @Test("Non-whitelisted domain returns false")
    func testNonWhitelistedDomain() {
        let service = makeService()
        #expect(service.isWhitelisted("unknown.com") == false)
    }

    @Test("Whitelist persists to UserDefaults")
    func testWhitelistPersistence() {
        let service = makeService()
        service.addToWhitelist("example.com")
        service.addToWhitelist("test.org")

        let saved = UserDefaults.standard.stringArray(forKey: "adBlockWhitelist") ?? []
        #expect(saved.count == 2)
        #expect(saved.contains("example.com"))
        #expect(saved.contains("test.org"))
    }

    // MARK: - Content Rule List

    @Test("Content rule list is nil when disabled")
    func testRuleListNilWhenDisabled() {
        let service = makeService()
        service.isEnabled = false

        #expect(service.contentRuleList() == nil)
    }

    // MARK: - Cosmetic Filter Script

    @Test("Cosmetic filter script is a valid WKUserScript")
    func testCosmeticFilterScript() {
        let service = makeService()
        let script = service.cosmeticFilterScript()

        #expect(script.injectionTime == .atDocumentEnd)
        #expect(script.isForMainFrameOnly == false)
    }

    // MARK: - Cleanup

    @Test("Cleanup removes all whitelist entries")
    func testMultipleAddRemove() {
        let service = makeService()
        service.addToWhitelist("a.com")
        service.addToWhitelist("b.com")
        service.addToWhitelist("c.com")

        #expect(service.whitelist.count == 3)

        service.removeFromWhitelist("b.com")
        #expect(service.whitelist.count == 2)
        #expect(service.isWhitelisted("a.com") == true)
        #expect(service.isWhitelisted("b.com") == false)
        #expect(service.isWhitelisted("c.com") == true)
    }
}
