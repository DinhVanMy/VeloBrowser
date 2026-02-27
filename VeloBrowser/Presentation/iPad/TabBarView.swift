// TabBarView.swift
// VeloBrowser
//
// iPad horizontal tab bar showing open tabs at the top of the browser.

import SwiftUI

/// iPad-style horizontal tab bar displayed at the top of the screen.
///
/// Shows open tabs as horizontal segments with title, favicon, and close button.
/// Supports tap-to-switch, close, and new tab creation.
struct TabBarView: View {
    @Bindable var tabManager: TabManager

    /// Callback when the tab switcher grid should be shown.
    var onShowTabSwitcher: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Scrollable tab strip
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(tabManager.tabs) { tab in
                            TabBarItemView(
                                tab: tab,
                                isActive: tab.isActive,
                                onSelect: {
                                    tabManager.switchToTab(id: tab.id)
                                    HapticManager.light()
                                },
                                onClose: {
                                    withAnimation(.easeOut(duration: DesignSystem.AnimationDuration.fast)) {
                                        tabManager.closeTab(id: tab.id)
                                        HapticManager.light()
                                    }
                                }
                            )
                            .id(tab.id)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                }
                .onChange(of: tabManager.activeTab?.id) { _, newID in
                    if let id = newID {
                        withAnimation(.easeOut(duration: DesignSystem.AnimationDuration.fast)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }

            Divider()
                .frame(height: 20)

            // New tab button
            Button {
                if tabManager.tabCount < TabManager.maxTabs {
                    tabManager.createTab(url: nil, isPrivate: false)
                    HapticManager.light()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .hoverEffect(.highlight)
            .accessibilityLabel("New tab")
            .padding(.horizontal, DesignSystem.Spacing.xs)

            // Tab overview button
            Button(action: onShowTabSwitcher) {
                Image(systemName: "square.on.square")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .hoverEffect(.highlight)
            .accessibilityLabel("Show all tabs")
            .padding(.trailing, DesignSystem.Spacing.sm)
        }
        .frame(height: 38)
        .background(DesignSystem.Colors.backgroundSecondary)
    }
}

/// A single tab item in the horizontal tab bar.
struct TabBarItemView: View {
    let tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Favicon
                if let faviconURL = tab.faviconURL {
                    AsyncImage(url: faviconURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    } placeholder: {
                        tabIcon
                    }
                } else {
                    tabIcon
                }

                // Title
                Text(tab.title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(
                        isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary
                    )
                    .lineLimit(1)

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.fillTertiary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close tab")
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .frame(minWidth: 120, maxWidth: 200)
            .background(
                isActive
                    ? DesignSystem.Colors.backgroundPrimary
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isActive ? DesignSystem.Colors.separator : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel("\(tab.title)\(isActive ? ", active" : "")")
    }

    @ViewBuilder
    private var tabIcon: some View {
        Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
            .font(.system(size: 11))
            .foregroundStyle(
                tab.isPrivate ? Color.purple : DesignSystem.Colors.textTertiary
            )
            .frame(width: 14, height: 14)
    }
}
