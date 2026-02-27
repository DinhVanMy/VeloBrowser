// SidebarView.swift
// VeloBrowser
//
// iPad sidebar for bookmarks, reading list, history, and downloads.

import SwiftUI

/// Sidebar section for iPad navigation.
enum SidebarSection: String, CaseIterable, Identifiable {
    case bookmarks = "Bookmarks"
    case readingList = "Reading List"
    case history = "History"
    case downloads = "Downloads"

    var id: String { rawValue }

    /// SF Symbol icon for this section.
    var icon: String {
        switch self {
        case .bookmarks: return "book"
        case .readingList: return "eyeglasses"
        case .history: return "clock"
        case .downloads: return "arrow.down.circle"
        }
    }
}

/// iPad sidebar providing quick access to bookmarks, history, reading list,
/// and downloads alongside the main browser content.
struct SidebarView: View {
    @Environment(DIContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    /// The currently selected sidebar section.
    @Binding var selectedSection: SidebarSection?

    var body: some View {
        List(selection: $selectedSection) {
            Section("Browser") {
                ForEach(SidebarSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section("Quick Actions") {
                Button {
                    if container.tabManager.tabCount < TabManager.maxTabs {
                        container.tabManager.createTab(url: nil, isPrivate: false)
                        HapticManager.light()
                    }
                } label: {
                    Label("New Tab", systemImage: "plus.square")
                }

                Button {
                    if container.tabManager.tabCount < TabManager.maxTabs {
                        container.tabManager.createTab(url: nil, isPrivate: true)
                        HapticManager.light()
                    }
                } label: {
                    Label("New Private Tab", systemImage: "eye.slash")
                }

                Button {
                    coordinator.navigate(to: .settings)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Velo Browser")
    }
}

/// Detail view content for a selected sidebar section.
struct SidebarDetailView: View {
    let section: SidebarSection
    @Environment(DIContainer.self) private var container

    var body: some View {
        switch section {
        case .bookmarks:
            BookmarksView(
                bookmarkRepository: container.bookmarkRepository,
                currentPageURL: container.tabManager.activeViewModel?.currentURL,
                currentPageTitle: container.tabManager.activeViewModel?.pageTitle,
                onOpenBookmark: { url in
                    container.tabManager.activeViewModel?.loadURL(url)
                }
            )
        case .readingList:
            ReadingListView(
                repository: container.readingListRepository,
                onOpenURL: { url in
                    container.tabManager.activeViewModel?.loadURL(url)
                }
            )
        case .history:
            HistoryView(
                historyRepository: container.historyRepository,
                onOpenURL: { url in
                    container.tabManager.activeViewModel?.loadURL(url)
                }
            )
        case .downloads:
            DownloadsView(downloadManager: container.downloadManager)
        }
    }
}
