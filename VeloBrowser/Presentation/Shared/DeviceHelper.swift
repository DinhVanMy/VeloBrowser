// DeviceHelper.swift
// VeloBrowser
//
// Utility for detecting device type and adapting layout.

import SwiftUI

/// Utility enum providing device detection and adaptive layout values.
///
/// Uses `UIDevice.current.userInterfaceIdiom` for hardware detection
/// and environment size classes for adaptive behavior.
enum DeviceHelper {
    /// Whether the current device is an iPad.
    @MainActor
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Whether the current device is an iPhone.
    @MainActor
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    /// Adaptive spacing that increases on iPad.
    enum AdaptiveSpacing {
        /// Toolbar horizontal padding: 16pt iPhone, 24pt iPad.
        @MainActor
        static var toolbarHorizontal: CGFloat {
            isIPad ? DesignSystem.Spacing.lg : DesignSystem.Spacing.md
        }

        /// Toolbar vertical padding: 8pt iPhone, 12pt iPad.
        @MainActor
        static var toolbarVertical: CGFloat {
            isIPad ? 12 : DesignSystem.Spacing.sm
        }

        /// Address bar horizontal padding: 16pt iPhone, 24pt iPad.
        @MainActor
        static var addressBarHorizontal: CGFloat {
            isIPad ? DesignSystem.Spacing.lg : DesignSystem.Spacing.md
        }
    }

    /// Adaptive touch target sizes.
    enum AdaptiveTouchTarget {
        /// Minimum touch target: 44pt iPhone, 48pt iPad.
        @MainActor
        static var minimum: CGFloat {
            isIPad ? 48 : DesignSystem.minimumTouchTarget
        }
    }
}

/// View modifier that provides the current horizontal size class.
///
/// Use to determine whether layout should be compact (iPhone/narrow)
/// or regular (iPad/wide).
struct AdaptiveLayoutModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Whether the current layout is regular width (iPad full screen or wide split).
    var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    func body(content: Content) -> some View {
        content
    }
}
