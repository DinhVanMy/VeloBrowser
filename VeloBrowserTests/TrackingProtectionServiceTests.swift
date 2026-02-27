// TrackingProtectionServiceTests.swift
// VeloBrowserTests
//
// Unit tests for TrackingProtectionService URL cleaning.

import Testing
import Foundation
@testable import VeloBrowser

@MainActor
@Suite("TrackingProtection Tests")
struct TrackingProtectionServiceTests {

    private func makeService(enabled: Bool = true) -> TrackingProtectionService {
        let service = TrackingProtectionService()
        service.isEnabled = enabled
        return service
    }

    @Test("Strips Facebook tracking parameters")
    func stripsFacebookParams() {
        let service = makeService()
        let url = URL(string: "https://example.com/page?article=1&fbclid=abc123&fb_ref=xyz")!
        let result = service.cleanURL(url)
        #expect(result != nil)
        #expect(result?.url.absoluteString == "https://example.com/page?article=1")
        #expect(result?.removedCount == 2)
    }

    @Test("Strips Google tracking parameters")
    func stripsGoogleParams() {
        let service = makeService()
        let url = URL(string: "https://example.com/?q=test&gclid=abc&gclsrc=def")!
        let result = service.cleanURL(url)
        #expect(result != nil)
        #expect(result?.removedCount == 2)
        #expect(result?.url.query?.contains("gclid") == false)
    }

    @Test("Strips UTM tracking parameters")
    func stripsUTMParams() {
        let service = makeService()
        let url = URL(string: "https://blog.com/post?utm_source=twitter&utm_medium=social&utm_campaign=launch&id=42")!
        let result = service.cleanURL(url)
        #expect(result != nil)
        #expect(result?.removedCount == 3)
        #expect(result?.url.query == "id=42")
    }

    @Test("Strips Microsoft and Twitter parameters")
    func stripsMSAndTwitterParams() {
        let service = makeService()
        let url = URL(string: "https://example.com/sale?item=shoes&msclkid=abc&twclid=def")!
        let result = service.cleanURL(url)
        #expect(result != nil)
        #expect(result?.removedCount == 2)
    }

    @Test("Strips misc trackers (_ga, _gl, igshid)")
    func stripsMiscTrackers() {
        let service = makeService()
        let url = URL(string: "https://instagram.com/p/123?igshid=abc&_ga=xyz&page=1")!
        let result = service.cleanURL(url)
        #expect(result != nil)
        #expect(result?.removedCount == 2)
        #expect(result?.url.query == "page=1")
    }

    @Test("Returns nil when no tracking params present")
    func noTrackingParams() {
        let service = makeService()
        let url = URL(string: "https://example.com/page?id=1&name=test")!
        let result = service.cleanURL(url)
        #expect(result == nil)
    }

    @Test("Returns nil when disabled")
    func disabledReturnsNil() {
        let service = makeService(enabled: false)
        let url = URL(string: "https://example.com/?fbclid=abc")!
        let result = service.cleanURL(url)
        #expect(result == nil)
    }

    @Test("Returns nil for URLs without query parameters")
    func noQueryParams() {
        let service = makeService()
        let url = URL(string: "https://example.com/page")!
        let result = service.cleanURL(url)
        #expect(result == nil)
    }

    @Test("Removes all query params if all are tracking")
    func allParamsRemoved() {
        let service = makeService()
        let url = URL(string: "https://example.com/?fbclid=a&utm_source=b&gclid=c")!
        let result = service.cleanURL(url)
        #expect(result != nil)
        #expect(result?.removedCount == 3)
        #expect(result?.url.query == nil)
    }

    @Test("Increments stripped count")
    func incrementsCounter() {
        let service = makeService()
        let before = service.strippedCount
        let url = URL(string: "https://example.com/?fbclid=a&utm_source=b")!
        _ = service.cleanURL(url)
        #expect(service.strippedCount == before + 2)
    }
}
