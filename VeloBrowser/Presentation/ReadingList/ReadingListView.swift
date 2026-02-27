// ReadingListView.swift
// VeloBrowser
//
// View displaying saved reading list items with search and management.

import SwiftUI

/// Displays the user's reading list with search, mark read/unread, and delete.
struct ReadingListView: View {
    let repository: ReadingListRepositoryProtocol
    let onOpenURL: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var items: [ReadingListItem] = []
    @State private var searchText = ""
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Reading List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                Task { await clearAll() }
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search reading list")
            .task { await loadItems() }
        }
    }

    // MARK: - Filtered Items

    private var filteredItems: [ReadingListItem] {
        if searchText.isEmpty {
            return items
        }
        let query = searchText.lowercased()
        return items.filter {
            $0.title.lowercased().contains(query) ||
            $0.url.absoluteString.lowercased().contains(query)
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            // Unread section
            let unread = filteredItems.filter { !$0.isRead }
            if !unread.isEmpty {
                Section("Unread") {
                    ForEach(unread) { item in
                        readingListRow(item)
                    }
                    .onDelete { offsets in
                        Task { await deleteItems(unread, at: offsets) }
                    }
                }
            }

            // Read section
            let read = filteredItems.filter { $0.isRead }
            if !read.isEmpty {
                Section("Read") {
                    ForEach(read) { item in
                        readingListRow(item)
                    }
                    .onDelete { offsets in
                        Task { await deleteItems(read, at: offsets) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await loadItems() }
    }

    // MARK: - Row

    private func readingListRow(_ item: ReadingListItem) -> some View {
        Button {
            onOpenURL(item.url)
            dismiss()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Read indicator
                Circle()
                    .fill(item.isRead ? Color.clear : Color.accentColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)

                    Text(item.url.host ?? item.url.absoluteString)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)

                    if !item.excerpt.isEmpty {
                        Text(item.excerpt)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text(item.dateAdded, style: .date)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await toggleRead(item) }
            } label: {
                Label(
                    item.isRead ? "Mark Unread" : "Mark Read",
                    systemImage: item.isRead ? "circle" : "checkmark.circle"
                )
            }
            .tint(.accentColor)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await deleteItem(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Reading List Items", systemImage: "eyeglasses")
        } description: {
            Text("Save articles to read later from the browser menu.")
        }
    }

    // MARK: - Actions

    private func loadItems() async {
        do {
            items = try await repository.fetchAll()
        } catch {
            items = []
        }
        isLoading = false
    }

    private func deleteItem(_ item: ReadingListItem) async {
        do {
            try await repository.delete(id: item.id)
            await loadItems()
        } catch { /* ignore */ }
    }

    private func deleteItems(_ source: [ReadingListItem], at offsets: IndexSet) async {
        for offset in offsets {
            let item = source[offset]
            try? await repository.delete(id: item.id)
        }
        await loadItems()
    }

    private func toggleRead(_ item: ReadingListItem) async {
        do {
            try await repository.toggleRead(id: item.id)
            await loadItems()
        } catch { /* ignore */ }
    }

    private func clearAll() async {
        do {
            try await repository.deleteAll()
            await loadItems()
        } catch { /* ignore */ }
    }
}
