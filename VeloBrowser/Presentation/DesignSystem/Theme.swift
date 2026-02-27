// Theme.swift
// VeloBrowser
//
// Central design system namespace for consistent UI throughout the app.

import SwiftUI

/// Central namespace for the VeloBrowser design system.
///
/// Provides access to colors, typography, spacing, and radii
/// that conform to Apple Human Interface Guidelines.
/// All values use semantic system tokens for automatic
/// Light/Dark mode and accessibility support.
enum DesignSystem {
    /// Semantic color palette following Apple HIG.
    typealias Colors = ColorPalette

    /// Typography styles using SF Pro with Dynamic Type.
    typealias Typography = TypographyStyles

    /// Standard spacing values for consistent layout.
    enum Spacing {
        /// 4pt — tight inline spacing.
        static let xs: CGFloat = 4

        /// 8pt — between related elements.
        static let sm: CGFloat = 8

        /// 16pt — standard padding.
        static let md: CGFloat = 16

        /// 24pt — section separators.
        static let lg: CGFloat = 24

        /// 32pt — major sections.
        static let xl: CGFloat = 32
    }

    /// Standard corner radii for UI elements.
    enum Radius {
        /// 8pt — buttons and small elements.
        static let button: CGFloat = 8

        /// 12pt — cards and panels.
        static let card: CGFloat = 12

        /// 16pt — large containers.
        static let container: CGFloat = 16
    }

    /// Minimum touch target size per Apple HIG (44x44pt).
    static let minimumTouchTarget: CGFloat = 44

    /// Standard animation durations.
    enum AnimationDuration {
        /// 200ms — quick transitions.
        static let fast: Double = 0.2

        /// 300ms — standard transitions.
        static let standard: Double = 0.3

        /// 500ms — elaborate transitions.
        static let slow: Double = 0.5
    }
}
