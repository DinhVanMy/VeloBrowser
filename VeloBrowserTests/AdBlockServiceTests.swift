// AdBlockServiceTests.swift
// VeloBrowserTests
//
// Unit tests for AdBlockService allowlist and toggle logic.

import Testing
import Foundation
@testable import VeloBrowser

@MainActor
@Suite("AdBlockService Tests")
struct AdBlockServiceTests {

    private func makeService() -> AdBlockService {
        // Clean up UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "adBlockEnabled")
        UserDefaults.standard.removeObject(forKey: "adBlockAllowlist")
        return AdBlockService()
    }

    // MARK: - Default State

    @Test("Ad blocker is enabled by default")
    func testDefaultEnabled() {
        let service = makeService()
        #expect(service.isEnabled == true)
    }

    @Test("Allowlist is empty by default")
    func testDefaultEmptyAllowlist() {
        let service = makeService()
        #expect(service.allowlist.isEmpty)
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

    // MARK: - Allowlist

    @Test("Add domain to allowlist")
    func testAddToAllowlist() {
        let service = makeService()
        service.addToAllowlist("example.com")

        #expect(service.isAllowlisted("example.com") == true)
        #expect(service.allowlist.count == 1)
    }

    @Test("Allowlist is case-insensitive")
    func testAllowlistCaseInsensitive() {
        let service = makeService()
        service.addToAllowlist("Example.COM")

        #expect(service.isAllowlisted("example.com") == true)
        #expect(service.isAllowlisted("EXAMPLE.COM") == true)
    }

    @Test("Remove domain from allowlist")
    func testRemoveFromAllowlist() {
        let service = makeService()
        service.addToAllowlist("example.com")
        service.removeFromAllowlist("example.com")

        #expect(service.isAllowlisted("example.com") == false)
        #expect(service.allowlist.isEmpty)
    }

    @Test("Non-allowlisted domain returns false")
    func testNonAllowlistedDomain() {
        let service = makeService()
        #expect(service.isAllowlisted("unknown.com") == false)
    }

    @Test("Allowlist persists to UserDefaults")
    func testAllowlistPersistence() {
        let service = makeService()
        service.addToAllowlist("example.com")
        service.addToAllowlist("test.org")

        let saved = UserDefaults.standard.stringArray(forKey: "adBlockAllowlist") ?? []
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

    @Test("Cleanup removes all allowlist entries")
    func testMultipleAddRemove() {
        let service = makeService()
        service.addToAllowlist("a.com")
        service.addToAllowlist("b.com")
        service.addToAllowlist("c.com")

        #expect(service.allowlist.count == 3)

        service.removeFromAllowlist("b.com")
        #expect(service.allowlist.count == 2)
        #expect(service.isAllowlisted("a.com") == true)
        #expect(service.isAllowlisted("b.com") == false)
        #expect(service.isAllowlisted("c.com") == true)
    }
}
