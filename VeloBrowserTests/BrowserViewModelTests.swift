// BrowserViewModelTests.swift
// VeloBrowserTests
//
// Unit tests for BrowserViewModel URL resolution and navigation.

import Testing
import Foundation
@testable import VeloBrowser

@MainActor
@Suite("BrowserViewModel Tests")
struct BrowserViewModelTests {
    let container = DIContainer(inMemory: true)

    private func makeViewModel() -> BrowserViewModel {
        BrowserViewModel(
            historyRepository: container.historyRepository,
            isPrivate: false
        )
    }

    // MARK: - URL Resolution via submitAddressBar

    @Test("Full URL with https scheme loads directly")
    func testFullHTTPSURL() {
        let vm = makeViewModel()
        vm.addressBarText = "https://www.apple.com"
        vm.submitAddressBar()

        #expect(vm.pendingURL?.absoluteString == "https://www.apple.com")
    }

    @Test("Full URL with http scheme loads directly")
    func testFullHTTPURL() {
        let vm = makeViewModel()
        vm.addressBarText = "http://example.com"
        vm.submitAddressBar()

        #expect(vm.pendingURL?.absoluteString == "http://example.com")
    }

    @Test("Domain without scheme gets https prefix")
    func testDomainWithoutScheme() {
        let vm = makeViewModel()
        vm.addressBarText = "apple.com"
        vm.submitAddressBar()

        #expect(vm.pendingURL?.absoluteString == "https://apple.com")
    }

    @Test("Search query goes to search engine")
    func testSearchQuery() {
        let vm = makeViewModel()
        vm.addressBarText = "swift programming"
        vm.submitAddressBar()

        let urlString = vm.pendingURL?.absoluteString ?? ""
        #expect(urlString.contains("google.com/search"))
        #expect(urlString.contains("swift"))
        #expect(urlString.contains("programming"))
    }

    @Test("Empty input does not set pendingURL")
    func testEmptyInput() {
        let vm = makeViewModel()
        vm.addressBarText = "   "
        vm.submitAddressBar()

        #expect(vm.pendingURL == nil)
    }

    @Test("Submit unfocuses address bar")
    func testSubmitUnfocusesAddressBar() {
        let vm = makeViewModel()
        vm.isAddressBarFocused = true
        vm.addressBarText = "apple.com"
        vm.submitAddressBar()

        #expect(vm.isAddressBarFocused == false)
    }

    // MARK: - Navigation Tokens

    @Test("goBack increments goBackToken")
    func testGoBack() {
        let vm = makeViewModel()
        let before = vm.goBackToken
        vm.goBack()

        #expect(vm.goBackToken == before + 1)
    }

    @Test("goForward increments goForwardToken")
    func testGoForward() {
        let vm = makeViewModel()
        let before = vm.goForwardToken
        vm.goForward()

        #expect(vm.goForwardToken == before + 1)
    }

    @Test("reload increments reloadToken")
    func testReload() {
        let vm = makeViewModel()
        let before = vm.reloadToken
        vm.reload()

        #expect(vm.reloadToken == before + 1)
    }

    @Test("stopLoading increments stopToken")
    func testStop() {
        let vm = makeViewModel()
        let before = vm.stopToken
        vm.stopLoading()

        #expect(vm.stopToken == before + 1)
    }

    // MARK: - loadURL

    @Test("loadURL sets pendingURL and addressBarText")
    func testLoadURL() {
        let vm = makeViewModel()
        let url = URL(string: "https://example.com")!
        vm.loadURL(url)

        #expect(vm.pendingURL == url)
        #expect(vm.addressBarText == "https://example.com")
    }

    // MARK: - Callbacks

    @Test("handleTitleChange updates pageTitle")
    func testTitleChange() {
        let vm = makeViewModel()
        vm.handleTitleChange("Test Page")

        #expect(vm.pageTitle == "Test Page")
    }

    @Test("handleURLChange updates currentURL and addressBarText")
    func testURLChange() {
        let vm = makeViewModel()
        let url = URL(string: "https://example.com/page")
        vm.handleURLChange(url)

        #expect(vm.currentURL == url)
        #expect(vm.addressBarText == "https://example.com/page")
    }

    @Test("handleLoadingChange updates isLoading")
    func testLoadingChange() {
        let vm = makeViewModel()
        vm.handleLoadingChange(true)
        #expect(vm.isLoading == true)

        vm.handleLoadingChange(false)
        #expect(vm.isLoading == false)
    }

    @Test("handleError sets errorMessage for non-cancelled errors")
    func testHandleError() {
        let vm = makeViewModel()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [
            NSLocalizedDescriptionKey: "The request timed out."
        ])
        vm.handleError(error)

        #expect(vm.errorMessage == "The request timed out.")
    }

    @Test("handleError ignores cancelled navigation errors")
    func testIgnoresCancelledErrors() {
        let vm = makeViewModel()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        vm.handleError(error)

        #expect(vm.errorMessage == nil)
    }

    // MARK: - Private Browsing

    @Test("Private browsing view model has isPrivate true")
    func testPrivateBrowsing() {
        let vm = BrowserViewModel(
            historyRepository: container.historyRepository,
            isPrivate: true
        )
        #expect(vm.isPrivate == true)
    }
}
