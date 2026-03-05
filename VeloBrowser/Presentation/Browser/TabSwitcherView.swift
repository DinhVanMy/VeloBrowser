// TabSwitcherView.swift
// VeloBrowser
//
// Grid view for switching between tabs, similar to Safari's tab overview.

import SwiftUI

/// A grid-based tab switcher for viewing and managing open tabs.
///
/// Displays tab thumbnails in a 2-column grid. Supports swipe-to-close,
/// creating new tabs, and switching between normal/private browsing modes.
struct TabSwitcherView: View {
    @Bindable var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(DIContainer.self) private var container

    /// Whether showing private tabs.
    @State private var showingPrivateTabs = false

    /// Adaptive column count: 3 on iPad/landscape, 2 on iPhone portrait.
    private var columns: [GridItem] {
        let count = (horizontalSizeClass == .regular || DeviceHelper.isIPad) ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab mode picker
                Picker("Tab Mode", selection: $showingPrivateTabs) {
                    Text("\(normalTabCount) Tabs").tag(false)
                    Text("\(privateTabCount) Private").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)

                // Tab grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.sm) {
                        ForEach(filteredTabs) { tab in
                            TabThumbnailView(
                                tab: tab,
                                isActive: tab.isActive,
                                snapshot: tabManager.snapshots[tab.id],
                                groupColor: container.tabGroupManager.group(for: tab.id)?.color,
                                onSelect: {
                                    tabManager.switchToTab(id: tab.id)
                                    dismiss()
                                },
                                onClose: {
                                    withAnimation(.easeOut(duration: DesignSystem.AnimationDuration.fast)) {
                                        tabManager.closeTab(id: tab.id)
                                        HapticManager.light()
                                    }
                                }
                            )
                        }
                    }
                    .padding(DesignSystem.Spacing.sm)
                }
            }
            .background(DesignSystem.Colors.backgroundGrouped)
            .navigationTitle(showingPrivateTabs ? "Private Tabs" : "Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if showingPrivateTabs && privateTabCount > 0 {
                        Button("Close All Private Tabs", role: .destructive) {
                            tabManager.closeAllTabs(privateOnly: true)
                            HapticManager.medium()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if tabManager.tabCount >= TabManager.maxTabs {
                            HapticManager.warning()
                        } else {
                            tabManager.createTab(url: nil, isPrivate: showingPrivateTabs)
                            HapticManager.light()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New tab")
                    .disabled(tabManager.tabCount >= TabManager.maxTabs)
                }
            }
        }
    }

    // MARK: - Computed

    private var filteredTabs: [Tab] {
        tabManager.tabs.filter { $0.isPrivate == showingPrivateTabs }
    }

    private var normalTabCount: Int {
        tabManager.tabs.filter { !$0.isPrivate }.count
    }

    private var privateTabCount: Int {
        tabManager.tabs.filter(\.isPrivate).count
    }
}

// MARK: - Tab Thumbnail

/// A single tab thumbnail card in the grid.
struct TabThumbnailView: View {
    let tab: Tab
    let isActive: Bool
    let snapshot: UIImage?
    var groupColor: Color?
    let onSelect: () -> Void
    let onClose: () -> Void

    /// Vertical drag offset for swipe-up-to-close gesture.
    @State private var dragOffset: CGSize = .zero
    /// Whether the card is being dismissed by swipe gesture.
    @State private var isDismissing: Bool = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Header bar
                HStack {
                    // Favicon
                    if let faviconURL = tab.faviconURL {
                        AsyncImage(url: faviconURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        } placeholder: {
                            Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    } else {
                        Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    // Tab group color dot
                    if let groupColor {
                        Circle()
                            .fill(groupColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(tab.title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close tab")
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.backgroundSecondary)

                // Preview area
                ZStack {
                    DesignSystem.Colors.backgroundPrimary

                    if let snapshot {
                        Image(uiImage: snapshot)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                            .transition(.opacity)
                    } else if let url = tab.url {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            // Favicon or loading indicator
                            if let faviconURL = tab.faviconURL {
                                AsyncImage(url: faviconURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } placeholder: {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            } else {
                                Image(systemName: "globe")
                                    .font(.title)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                            Text(url.host() ?? url.absoluteString)
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    } else {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus.square")
                                .font(.title)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                            Text("New Tab")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                .frame(height: 160)
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .strokeBorder(
                        isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.separator,
                        lineWidth: isActive ? 2 : 0.5
                    )
            )
            .shadow(
                color: .black.opacity(isActive ? 0.15 : 0.05),
                radius: isActive ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .offset(y: dragOffset.height)
        .opacity(isDismissing ? 0 : max(0, 1.0 - abs(dragOffset.height) / CGFloat(200)))
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow upward swipe
                    if value.translation.height < 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height < -80 {
                        // Threshold met — dismiss
                        isDismissing = true
                        HapticManager.light()
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = CGSize(width: 0, height: -300)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onClose()
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(duration: 0.3)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .accessibilityLabel("\(tab.title), \(isActive ? "active" : "inactive") tab")
        .accessibilityHint("Swipe up to close")
    }
}
