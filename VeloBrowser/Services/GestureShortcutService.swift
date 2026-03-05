// GestureShortcutService.swift
// VeloBrowser
//
// Custom gesture shortcuts for power users.

import UIKit
import os.log

/// Actions triggered by gestures.
enum GestureAction: String, CaseIterable, Identifiable {
    case newTab = "New Tab"
    case closeTab = "Close Tab"
    case togglePrivate = "Toggle Private Mode"
    case clearData = "Clear Browsing Data"
    case reloadPage = "Reload Page"
    case goHome = "Go Home"
    case showTabs = "Show Tabs"
    case showBookmarks = "Show Bookmarks"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .newTab: return "plus.square"
        case .closeTab: return "xmark.square"
        case .togglePrivate: return "eye.slash"
        case .clearData: return "trash"
        case .reloadPage: return "arrow.clockwise"
        case .goHome: return "house"
        case .showTabs: return "square.on.square"
        case .showBookmarks: return "book"
        }
    }
}

/// Service managing gesture-to-action mappings.
@Observable
@MainActor
final class GestureShortcutService {
    /// Whether shake-to-clear is enabled.
    var shakeToClean: Bool {
        get { UserDefaults.standard.bool(forKey: "shakeToClean") }
        set { UserDefaults.standard.set(newValue, forKey: "shakeToClean") }
    }

    /// Whether long-press back shows history stack.
    var longPressBackForHistory: Bool {
        get { UserDefaults.standard.object(forKey: "longPressBack") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "longPressBack") }
    }

    /// Whether pull-down on new tab page triggers search focus.
    var pullDownToSearch: Bool {
        get { UserDefaults.standard.object(forKey: "pullDownSearch") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "pullDownSearch") }
    }

    /// Whether double-tap address bar selects all text.
    var doubleTapSelectAll: Bool {
        get { UserDefaults.standard.object(forKey: "doubleTapSelect") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "doubleTapSelect") }
    }
}
