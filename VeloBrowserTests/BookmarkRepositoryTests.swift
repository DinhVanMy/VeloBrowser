// BookmarkRepositoryTests.swift
// VeloBrowserTests
//
// Unit tests for SwiftDataBookmarkRepository CRUD operations.

import Testing
import Foundation
import SwiftData
@testable import VeloBrowser

@MainActor
@Suite("BookmarkRepository Tests")
struct BookmarkRepositoryTests {
    let container = DIContainer(inMemory: true)

    private var repository: BookmarkRepositoryProtocol {
        container.bookmarkRepository
    }

    // MARK: - Save & Fetch

    @Test("Save and fetch bookmark")
    func testSaveAndFetch() async throws {
        let bookmark = Bookmark(
            url: URL(string: "https://apple.com")!,
            title: "Apple"
        )

        try await repository.save(bookmark)
        let results = try await repository.fetchAll(folder: nil)

        #expect(results.contains(where: { $0.id == bookmark.id }))
        let fetched = results.first(where: { $0.id == bookmark.id })
        #expect(fetched?.title == "Apple")
        #expect(fetched?.url.absoluteString == "https://apple.com")
    }

    @Test("Fetch returns empty array when no bookmarks")
    func testFetchEmpty() async throws {
        let emptyContainer = DIContainer(inMemory: true)
        let results = try await emptyContainer.bookmarkRepository.fetchAll(folder: nil)
        #expect(results.isEmpty)
    }

    // MARK: - Delete

    @Test("Delete bookmark removes it from storage")
    func testDelete() async throws {
        let bookmark = Bookmark(
            url: URL(string: "https://example.com")!,
            title: "Example"
        )

        try await repository.save(bookmark)
        try await repository.delete(id: bookmark.id)

        let results = try await repository.fetchAll(folder: nil)
        #expect(!results.contains(where: { $0.id == bookmark.id }))
    }

    // MARK: - Update

    @Test("Update bookmark changes its properties")
    func testUpdate() async throws {
        var bookmark = Bookmark(
            url: URL(string: "https://example.com")!,
            title: "Original"
        )

        try await repository.save(bookmark)

        bookmark.title = "Updated Title"
        bookmark.url = URL(string: "https://updated.com")!
        try await repository.update(bookmark)

        let results = try await repository.fetchAll(folder: nil)
        let updated = results.first(where: { $0.id == bookmark.id })
        #expect(updated?.title == "Updated Title")
        #expect(updated?.url.absoluteString == "https://updated.com")
    }

    // MARK: - Search

    @Test("Search finds bookmarks by title")
    func testSearchByTitle() async throws {
        let b1 = Bookmark(url: URL(string: "https://a.com")!, title: "Swift Language")
        let b2 = Bookmark(url: URL(string: "https://b.com")!, title: "Python Docs")

        try await repository.save(b1)
        try await repository.save(b2)

        let results = try await repository.search(query: "Swift")
        #expect(results.count == 1)
        #expect(results.first?.title == "Swift Language")
    }

    @Test("Search finds bookmarks by URL")
    func testSearchByURL() async throws {
        let bookmark = Bookmark(
            url: URL(string: "https://developer.apple.com")!,
            title: "Dev"
        )
        try await repository.save(bookmark)

        let results = try await repository.search(query: "apple")
        #expect(results.count >= 1)
        #expect(results.contains(where: { $0.url.absoluteString.contains("apple") }))
    }

    // MARK: - Folder Filtering

    @Test("Fetch by folder filters correctly")
    func testFolderFilter() async throws {
        let b1 = Bookmark(url: URL(string: "https://a.com")!, title: "A", folder: "Work")
        let b2 = Bookmark(url: URL(string: "https://b.com")!, title: "B", folder: "Personal")

        try await repository.save(b1)
        try await repository.save(b2)

        let workResults = try await repository.fetchAll(folder: "Work")
        #expect(workResults.count == 1)
        #expect(workResults.first?.folder == "Work")
    }

    // MARK: - Multiple Operations

    @Test("Multiple saves and deletes maintain consistency")
    func testMultipleOps() async throws {
        var bookmarks: [Bookmark] = []
        for i in 0..<5 {
            let b = Bookmark(url: URL(string: "https://site\(i).com")!, title: "Site \(i)")
            try await repository.save(b)
            bookmarks.append(b)
        }

        let all = try await repository.fetchAll(folder: nil)
        #expect(all.count >= 5)

        // Delete first two
        try await repository.delete(id: bookmarks[0].id)
        try await repository.delete(id: bookmarks[1].id)

        let remaining = try await repository.fetchAll(folder: nil)
        #expect(!remaining.contains(where: { $0.id == bookmarks[0].id }))
        #expect(!remaining.contains(where: { $0.id == bookmarks[1].id }))
        #expect(remaining.contains(where: { $0.id == bookmarks[2].id }))
    }
}
