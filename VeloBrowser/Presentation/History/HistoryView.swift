// HistoryView.swift
// VeloBrowser
//
// View displaying browsing history grouped by date.

import SwiftUI

/// Displays browsing history grouped by date with search and clear capabilities.
///
/// Groups entries into Today, Yesterday, and Earlier sections.
/// Supports search, swipe-to-delete, and clearing all history.
struct HistoryView: View {
    let historyRepository: HistoryRepositoryProtocol

    /// Callback when a history entry is tapped to open it.
    var onOpenURL: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var entries: [HistoryEntry] = []
    @State private var searchText = ""
    @State private var showClearAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty && searchText.isEmpty {
                    emptyState
                } else if entries.isEmpty {
                    noResultsView
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search history")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !entries.isEmpty {
                        Button("Clear", role: .destructive) {
                            showClearAlert = true
                        }
                    }
                }
            }
            .alert("Clear History", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) { clearAll() }
            } message: {
                Text("This will remove all browsing history. This action cannot be undone.")
            }
            .task { await loadHistory() }
            .onChange(of: searchText) { _, query in
                Task { await searchHistory(query: query) }
            }
            .refreshable { await loadHistory() }
        }
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(groupedEntries, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.entries) { entry in
                        Button {
                            onOpenURL?(entry.url)
                            dismiss()
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(entry.url.host() ?? "")&sz=64")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } placeholder: {
                                    Image(systemName: "clock")
                                        .font(.body)
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        .frame(width: 28, height: 28)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)

                                    HStack(spacing: DesignSystem.Spacing.xs) {
                                        Text(entry.url.host() ?? "")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                                            .lineLimit(1)

                                        Spacer()

                                        Text(entry.visitedAt, style: .time)
                                            .font(DesignSystem.Typography.caption2)
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    }
                                }
                            }
                            .frame(minHeight: DesignSystem.minimumTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.title), visited at \(entry.visitedAt.formatted(date: .omitted, time: .shortened))")
                    }
                    .onDelete { offsets in
                        deleteEntries(offsets, in: group)
                    }
                }
            }
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No History")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Pages you visit will appear here.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No Results")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Date Grouping

    private struct HistoryGroup {
        let title: String
        let entries: [HistoryEntry]
    }

    private var groupedEntries: [HistoryGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var todayEntries: [HistoryEntry] = []
        var yesterdayEntries: [HistoryEntry] = []
        var earlierEntries: [HistoryEntry] = []

        for entry in entries {
            let entryDay = calendar.startOfDay(for: entry.visitedAt)
            if entryDay == today {
                todayEntries.append(entry)
            } else if entryDay == yesterday {
                yesterdayEntries.append(entry)
            } else {
                earlierEntries.append(entry)
            }
        }

        var groups: [HistoryGroup] = []
        if !todayEntries.isEmpty {
            groups.append(HistoryGroup(title: "Today", entries: todayEntries))
        }
        if !yesterdayEntries.isEmpty {
            groups.append(HistoryGroup(title: "Yesterday", entries: yesterdayEntries))
        }
        if !earlierEntries.isEmpty {
            groups.append(HistoryGroup(title: "Earlier", entries: earlierEntries))
        }
        return groups
    }

    // MARK: - Data Operations

    private func loadHistory() async {
        do {
            entries = try await historyRepository.fetch(from: nil, to: nil, limit: 500)
        } catch {
            entries = []
        }
    }

    private func searchHistory(query: String) async {
        do {
            if query.isEmpty {
                entries = try await historyRepository.fetch(from: nil, to: nil, limit: 500)
            } else {
                entries = try await historyRepository.search(query: query)
            }
        } catch {
            entries = []
        }
    }

    private func deleteEntries(_ offsets: IndexSet, in group: HistoryGroup) {
        let toDelete = offsets.map { group.entries[$0] }
        for entry in toDelete {
            Task { try? await historyRepository.delete(id: entry.id) }
        }
        entries.removeAll { entry in toDelete.contains(where: { $0.id == entry.id }) }
    }

    private func clearAll() {
        Task {
            try? await historyRepository.clearAll()
            entries = []
        }
    }
}
