// BookmarksView.swift
// VeloBrowser
//
// View displaying saved bookmarks with search, add, and delete capabilities.

import SwiftUI

/// Displays the user's saved bookmarks with search and management capabilities.
///
/// Supports adding the current page, swipe-to-delete, and opening
/// bookmarks in the browser. Shows an empty state when no bookmarks exist.
struct BookmarksView: View {
    let bookmarkRepository: BookmarkRepositoryProtocol

    /// The URL of the current page (for "Add Bookmark" functionality).
    var currentPageURL: URL?

    /// The title of the current page.
    var currentPageTitle: String?

    /// Callback when a bookmark is tapped to open it.
    var onOpenBookmark: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var bookmarks: [Bookmark] = []
    @State private var searchText = ""
    @State private var showAddAlert = false
    @State private var addBookmarkTitle = ""

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    bookmarkList
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search bookmarks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if currentPageURL != nil {
                        Button {
                            addBookmarkTitle = currentPageTitle ?? ""
                            showAddAlert = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add bookmark for current page")
                    }
                }
            }
            .alert("Add Bookmark", isPresented: $showAddAlert) {
                TextField("Title", text: $addBookmarkTitle)
                Button("Cancel", role: .cancel) {}
                Button("Save") { addBookmark() }
            } message: {
                Text(currentPageURL?.absoluteString ?? "")
            }
            .task { await loadBookmarks() }
            .onChange(of: searchText) { _, query in
                Task { await searchBookmarks(query: query) }
            }
            .refreshable { await loadBookmarks() }
        }
    }

    // MARK: - Bookmark List

    private var bookmarkList: some View {
        List {
            ForEach(bookmarks) { bookmark in
                Button {
                    onOpenBookmark?(bookmark.url)
                    dismiss()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if let faviconURL = bookmark.faviconURL {
                            AsyncImage(url: faviconURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } placeholder: {
                                Image(systemName: "globe")
                                    .font(.body)
                                    .foregroundStyle(DesignSystem.Colors.accent)
                                    .frame(width: 28, height: 28)
                            }
                        } else {
                            Image(systemName: "globe")
                                .font(.body)
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .frame(width: 28, height: 28)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(bookmark.title)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)

                            Text(bookmark.url.host() ?? bookmark.url.absoluteString)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(minHeight: DesignSystem.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(bookmark.title), \(bookmark.url.host() ?? "")")
            }
            .onDelete(perform: deleteBookmarks)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "book")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No Bookmarks")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Tap + to save the current page.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Operations

    private func loadBookmarks() async {
        do {
            if searchText.isEmpty {
                bookmarks = try await bookmarkRepository.fetchAll(folder: nil)
            } else {
                bookmarks = try await bookmarkRepository.search(query: searchText)
            }
        } catch {
            bookmarks = []
        }
    }

    private func searchBookmarks(query: String) async {
        do {
            if query.isEmpty {
                bookmarks = try await bookmarkRepository.fetchAll(folder: nil)
            } else {
                bookmarks = try await bookmarkRepository.search(query: query)
            }
        } catch {
            bookmarks = []
        }
    }

    private func addBookmark() {
        guard let url = currentPageURL else { return }
        let title = addBookmarkTitle.isEmpty ? (url.host() ?? url.absoluteString) : addBookmarkTitle
        let bookmark = Bookmark(url: url, title: title)
        Task {
            try? await bookmarkRepository.save(bookmark)
            await loadBookmarks()
        }
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        let toDelete = offsets.map { bookmarks[$0] }
        for bookmark in toDelete {
            Task {
                try? await bookmarkRepository.delete(id: bookmark.id)
            }
        }
        bookmarks.remove(atOffsets: offsets)
    }
}
