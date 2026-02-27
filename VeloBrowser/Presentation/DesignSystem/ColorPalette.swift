// ColorPalette.swift
// VeloBrowser
//
// Semantic color definitions following Apple HIG.

import SwiftUI

/// Semantic color palette for VeloBrowser.
///
/// All colors use Apple's semantic color system to automatically
/// support Light Mode, Dark Mode, and Increased Contrast.
/// Never use hardcoded hex values for standard UI elements.
enum ColorPalette {
    // MARK: - Backgrounds

    /// Primary background color (adapts to light/dark mode).
    static let backgroundPrimary = Color(uiColor: .systemBackground)

    /// Secondary background color for cards and panels.
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)

    /// Tertiary background for nested grouping.
    static let backgroundTertiary = Color(uiColor: .tertiarySystemBackground)

    /// Grouped background for table/list views.
    static let backgroundGrouped = Color(uiColor: .systemGroupedBackground)

    // MARK: - Text

    /// Primary text color for headings and body.
    static let textPrimary = Color(uiColor: .label)

    /// Secondary text color for subtitles and hints.
    static let textSecondary = Color(uiColor: .secondaryLabel)

    /// Tertiary text color for disabled or placeholder text.
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    /// Quaternary text for the lowest emphasis.
    static let textQuaternary = Color(uiColor: .quaternaryLabel)

    // MARK: - Semantic

    /// Brand accent color for interactive elements.
    static let accent = Color.accentColor

    /// Destructive action color (delete, errors).
    static let destructive = Color(uiColor: .systemRed)

    /// Success confirmation color.
    static let success = Color(uiColor: .systemGreen)

    /// Warning/attention color.
    static let warning = Color(uiColor: .systemOrange)

    // MARK: - Separators

    /// Standard separator color.
    static let separator = Color(uiColor: .separator)

    /// Opaque separator for non-transparent backgrounds.
    static let separatorOpaque = Color(uiColor: .opaqueSeparator)

    // MARK: - Fill

    /// Primary fill color for thin and small shapes.
    static let fillPrimary = Color(uiColor: .systemFill)

    /// Secondary fill color.
    static let fillSecondary = Color(uiColor: .secondarySystemFill)

    /// Tertiary fill for the lowest-emphasis fills.
    static let fillTertiary = Color(uiColor: .tertiarySystemFill)
}
