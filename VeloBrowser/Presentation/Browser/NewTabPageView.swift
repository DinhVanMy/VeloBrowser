// NewTabPageView.swift
// VeloBrowser
//
// Start page shown for new/blank tabs with search bar and quick-access sites.

import SwiftUI

/// Platform identifier for quick-access sites.
private enum Platform: String, CaseIterable, Sendable {
    case youtube, facebook, tiktok, twitter, instagram, reddit, wikipedia, gmail

    var name: String {
        switch self {
        case .youtube: "YouTube"
        case .facebook: "Facebook"
        case .tiktok: "TikTok"
        case .twitter: "Twitter"
        case .instagram: "Instagram"
        case .reddit: "Reddit"
        case .wikipedia: "Wikipedia"
        case .gmail: "Gmail"
        }
    }

    var url: URL {
        switch self {
        case .youtube: URL(string: "https://m.youtube.com") ?? URL(string: "about:blank")!
        case .facebook: URL(string: "https://m.facebook.com") ?? URL(string: "about:blank")!
        case .tiktok: URL(string: "https://www.tiktok.com") ?? URL(string: "about:blank")!
        case .twitter: URL(string: "https://x.com") ?? URL(string: "about:blank")!
        case .instagram: URL(string: "https://www.instagram.com") ?? URL(string: "about:blank")!
        case .reddit: URL(string: "https://www.reddit.com") ?? URL(string: "about:blank")!
        case .wikipedia: URL(string: "https://en.m.wikipedia.org") ?? URL(string: "about:blank")!
        case .gmail: URL(string: "https://mail.google.com") ?? URL(string: "about:blank")!
        }
    }

    @ViewBuilder
    func logoView(size: CGFloat) -> some View {
        switch self {
        case .youtube: YouTubeLogo(size: size)
        case .facebook: FacebookLogo(size: size)
        case .tiktok: TikTokLogo(size: size)
        case .twitter: TwitterXLogo(size: size)
        case .instagram: InstagramLogo(size: size)
        case .reddit: RedditLogo(size: size)
        case .wikipedia: WikipediaLogo(size: size)
        case .gmail: GmailLogo(size: size)
        }
    }
}

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
                    VeloLogoView(size: 56)

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
                        ForEach(Platform.allCases, id: \.self) { platform in
                            Button {
                                onOpenURL(platform.url)
                            } label: {
                                quickAccessCard(platform: platform)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(platform.name)")
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
    private func quickAccessCard(platform: Platform) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            platform.logoView(size: 52)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                .frame(width: 56, height: 56)

            Text(platform.name)
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
