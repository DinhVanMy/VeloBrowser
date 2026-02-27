// NewTabPageView.swift
// VeloBrowser
//
// Start page shown for new/blank tabs with search bar and quick-access sites.

import SwiftUI

/// A built-in quick-access site shown on the new tab page.
private struct QuickAccessSite: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let icon: String
    let color: Color
}

/// Built-in popular sites for instant access from the home screen.
private let builtInSites: [QuickAccessSite] = [
    QuickAccessSite(
        name: "YouTube",
        url: URL(string: "https://m.youtube.com")!,
        icon: "play.rectangle.fill",
        color: .red
    ),
    QuickAccessSite(
        name: "Facebook",
        url: URL(string: "https://m.facebook.com")!,
        icon: "person.2.fill",
        color: .blue
    ),
    QuickAccessSite(
        name: "TikTok",
        url: URL(string: "https://www.tiktok.com")!,
        icon: "music.note",
        color: .pink
    ),
    QuickAccessSite(
        name: "Twitter",
        url: URL(string: "https://x.com")!,
        icon: "at",
        color: .cyan
    ),
    QuickAccessSite(
        name: "Instagram",
        url: URL(string: "https://www.instagram.com")!,
        icon: "camera.fill",
        color: .purple
    ),
    QuickAccessSite(
        name: "Reddit",
        url: URL(string: "https://www.reddit.com")!,
        icon: "bubble.left.and.bubble.right.fill",
        color: .orange
    ),
    QuickAccessSite(
        name: "Wikipedia",
        url: URL(string: "https://en.m.wikipedia.org")!,
        icon: "book.fill",
        color: .gray
    ),
    QuickAccessSite(
        name: "Gmail",
        url: URL(string: "https://mail.google.com")!,
        icon: "envelope.fill",
        color: .red.opacity(0.8)
    ),
]

/// The new tab start page displayed when no URL is loaded.
///
/// Shows a search bar, quick-access site cards (YouTube, Facebook, TikTok, etc.),
/// and user bookmarks. Provides a clean starting point for browsing.
struct NewTabPageView: View {
    let bookmarkRepository: BookmarkRepositoryProtocol
    let onSearch: (String) -> Void
    let onOpenURL: (URL) -> Void

    @State private var searchText = ""
    @State private var bookmarks: [Bookmark] = []
    @FocusState private var isSearchFocused: Bool

    private let quickAccessColumns = [
        GridItem(.adaptive(minimum: 72, maximum: 90), spacing: DesignSystem.Spacing.md)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()
                    .frame(height: 40)

                // App branding
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "globe")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("Velo Browser")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
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

                // Quick Access — built-in popular sites
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Quick Access")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.md)

                    LazyVGrid(columns: quickAccessColumns, spacing: DesignSystem.Spacing.md) {
                        ForEach(builtInSites) { site in
                            Button {
                                onOpenURL(site.url)
                            } label: {
                                quickAccessCard(site: site)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(site.name)")
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }

                // User bookmarks / Favorites
                if !bookmarks.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Favorites")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.md)

                        LazyVGrid(columns: quickAccessColumns, spacing: DesignSystem.Spacing.md) {
                            ForEach(bookmarks.prefix(8)) { bookmark in
                                Button {
                                    onOpenURL(bookmark.url)
                                } label: {
                                    bookmarkCard(bookmark: bookmark)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open \(bookmark.title)")
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                }

                Spacer()
                    .frame(height: 40)
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

    // MARK: - Card Views

    /// A quick-access card for a built-in popular site.
    private func quickAccessCard(site: QuickAccessSite) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .fill(site.color.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: site.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(site.color)
            }

            Text(site.name)
                .font(DesignSystem.Typography.caption2)
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
        }
        .frame(minWidth: DesignSystem.minimumTouchTarget,
               minHeight: DesignSystem.minimumTouchTarget)
    }

    /// A card for a user-saved bookmark.
    private func bookmarkCard(bookmark: Bookmark) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .fill(DesignSystem.Colors.fillTertiary)
                    .frame(width: 56, height: 56)

                if let faviconURL = bookmark.faviconURL {
                    AsyncImage(url: faviconURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } placeholder: {
                        Text(String(bookmark.title.prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                } else {
                    Text(String(bookmark.title.prefix(1)).uppercased())
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }

            Text(bookmark.title)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(minWidth: DesignSystem.minimumTouchTarget,
               minHeight: DesignSystem.minimumTouchTarget)
    }
}
