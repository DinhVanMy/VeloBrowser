// ReadingListRepositoryTests.swift
// VeloBrowserTests
//
// Unit tests for ReadingListRepository CRUD operations.

import Testing
import Foundation
@testable import VeloBrowser

@MainActor
@Suite("ReadingListRepository Tests")
struct ReadingListRepositoryTests {
    let container = DIContainer(inMemory: true)

    private var repository: ReadingListRepositoryProtocol {
        container.readingListRepository
    }

    @Test("Save and fetch reading list item")
    func saveAndFetch() async throws {
        let item = ReadingListItem(
            url: URL(string: "https://example.com/article")!,
            title: "Test Article",
            excerpt: "A test excerpt"
        )
        try await repository.save(item)

        let items = try await repository.fetchAll()
        #expect(items.count == 1)
        #expect(items.first?.title == "Test Article")
        #expect(items.first?.excerpt == "A test excerpt")
        #expect(items.first?.isRead == false)
    }

    @Test("Delete reading list item")
    func deleteItem() async throws {
        let item = ReadingListItem(
            url: URL(string: "https://example.com/delete-me")!,
            title: "Delete Me"
        )
        try await repository.save(item)

        var items = try await repository.fetchAll()
        #expect(items.count == 1)

        try await repository.delete(id: item.id)
        items = try await repository.fetchAll()
        #expect(items.isEmpty)
    }

    @Test("Toggle read status")
    func toggleRead() async throws {
        let item = ReadingListItem(
            url: URL(string: "https://example.com/toggle")!,
            title: "Toggle Read"
        )
        try await repository.save(item)

        try await repository.toggleRead(id: item.id)
        var items = try await repository.fetchAll()
        #expect(items.first?.isRead == true)

        try await repository.toggleRead(id: item.id)
        items = try await repository.fetchAll()
        #expect(items.first?.isRead == false)
    }

    @Test("Search reading list items")
    func searchItems() async throws {
        let item1 = ReadingListItem(
            url: URL(string: "https://swift.org/docs")!,
            title: "Swift Documentation"
        )
        let item2 = ReadingListItem(
            url: URL(string: "https://example.com/other")!,
            title: "Other Article"
        )
        try await repository.save(item1)
        try await repository.save(item2)

        let results = try await repository.search(query: "swift")
        #expect(results.count == 1)
        #expect(results.first?.title == "Swift Documentation")
    }

    @Test("Delete all reading list items")
    func deleteAll() async throws {
        for i in 0..<3 {
            try await repository.save(ReadingListItem(
                url: URL(string: "https://example.com/\(i)")!,
                title: "Article \(i)"
            ))
        }

        var items = try await repository.fetchAll()
        #expect(items.count == 3)

        try await repository.deleteAll()
        items = try await repository.fetchAll()
        #expect(items.isEmpty)
    }

    @Test("Items sorted by date descending")
    func sortedByDate() async throws {
        let older = ReadingListItem(
            url: URL(string: "https://example.com/old")!,
            title: "Old",
            dateAdded: Date(timeIntervalSinceNow: -3600)
        )
        let newer = ReadingListItem(
            url: URL(string: "https://example.com/new")!,
            title: "New",
            dateAdded: Date()
        )
        try await repository.save(older)
        try await repository.save(newer)

        let items = try await repository.fetchAll()
        #expect(items.first?.title == "New")
        #expect(items.last?.title == "Old")
    }
}
