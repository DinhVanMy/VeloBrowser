// iPadLayoutView.swift
// VeloBrowser
//
// Adaptive layout for iPad using NavigationSplitView with sidebar
// and horizontal tab bar.

import SwiftUI

/// iPad-optimized layout with optional sidebar, horizontal tab bar,
/// and browser content.
///
/// Uses NavigationSplitView when sidebar is enabled, falls back to
/// a simple VStack with tab bar otherwise. Adapts gracefully to
/// Split View and Slide Over multitasking modes.
struct iPadLayoutView: View {
    @Environment(DIContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedSection: SidebarSection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @AppStorage("iPadShowSidebar") private var showSidebar: Bool = false
    @AppStorage("iPadShowTabBar") private var showTabBar: Bool = true

    var body: some View {
        if showSidebar && horizontalSizeClass == .regular {
            sidebarLayout
        } else {
            tabBarLayout
        }
    }

    // MARK: - Sidebar Layout

    @ViewBuilder
    private var sidebarLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedSection: $selectedSection)
        } detail: {
            VStack(spacing: 0) {
                if showTabBar {
                    TabBarView(
                        tabManager: container.tabManager,
                        onShowTabSwitcher: showTabSwitcher
                    )
                }

                detailContent
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Tab Bar Layout (no sidebar)

    @ViewBuilder
    private var tabBarLayout: some View {
        VStack(spacing: 0) {
            if showTabBar && horizontalSizeClass == .regular {
                TabBarView(
                    tabManager: container.tabManager,
                    onShowTabSwitcher: showTabSwitcher
                )
            }

            browserContent
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if let section = selectedSection {
            SidebarDetailView(section: section)
        } else {
            browserContent
        }
    }

    @ViewBuilder
    private var browserContent: some View {
        if let vm = container.tabManager.activeViewModel {
            BrowserView(
                viewModel: vm,
                onShowTabSwitcher: showTabSwitcher,
                tabCount: container.tabManager.tabCount
            )
        } else {
            ProgressView()
        }
    }

    // MARK: - Actions

    private func showTabSwitcher() {
        HapticManager.light()
        if let activeTab = container.tabManager.activeTab {
            container.tabManager.captureSnapshot(for: activeTab.id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            coordinator.showTabSwitcher = true
        }
    }
}
