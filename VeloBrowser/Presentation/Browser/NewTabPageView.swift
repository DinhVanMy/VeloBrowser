// NewTabPageView.swift
// VeloBrowser
//
// Start page shown for new/blank tabs with search bar and quick bookmarks.

import SwiftUI

/// The new tab start page displayed when no URL is loaded.
///
/// Shows a search bar, quick-access bookmarks grid, and branding.
/// Provides a clean starting point for browsing similar to Safari's start page.
struct NewTabPageView: View {
    let bookmarkRepository: BookmarkRepositoryProtocol
    let onSearch: (String) -> Void
    let onOpenURL: (URL) -> Void

    @State private var searchText = ""
    @State private var bookmarks: [Bookmark] = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()
                    .frame(height: 60)

                // App branding
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "globe")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("Velo Browser")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                // Search bar
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    TextField("Search or enter URL", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .focused($isSearchFocused)
                        .onSubmit {
                            guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            onSearch(searchText)
                        }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.fillTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
                .padding(.horizontal, DesignSystem.Spacing.lg)

                // Quick bookmarks
                if !bookmarks.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Favorites")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.md)

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 70, maximum: 90), spacing: DesignSystem.Spacing.md)
                            ],
                            spacing: DesignSystem.Spacing.md
                        ) {
                            ForEach(bookmarks.prefix(8)) { bookmark in
                                Button {
                                    onOpenURL(bookmark.url)
                                } label: {
                                    VStack(spacing: DesignSystem.Spacing.xs) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: DesignSystem.Radius.button)
                                                .fill(DesignSystem.Colors.fillTertiary)
                                                .frame(width: 56, height: 56)

                                            Text(String(bookmark.title.prefix(1)).uppercased())
                                                .font(.system(size: 24, weight: .medium, design: .rounded))
                                                .foregroundStyle(DesignSystem.Colors.accent)
                                        }

                                        Text(bookmark.title)
                                            .font(DesignSystem.Typography.caption2)
                                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    .frame(minWidth: DesignSystem.minimumTouchTarget,
                                           minHeight: DesignSystem.minimumTouchTarget)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open \(bookmark.title)")
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                }

                Spacer()
            }
        }
        .background(DesignSystem.Colors.backgroundPrimary)
        .task {
            do {
                bookmarks = try await bookmarkRepository.fetchAll(folder: nil)
            } catch {
                bookmarks = []
            }
        }
    }
}
