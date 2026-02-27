// HapticManager.swift
// VeloBrowser
//
// Centralized haptic feedback utility.

import UIKit

/// Provides centralized haptic feedback generation.
///
/// Uses `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`,
/// and `UISelectionFeedbackGenerator` for consistent tactile responses.
@MainActor
enum HapticManager {
    /// Light impact for subtle interactions (e.g., toolbar toggle).
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium impact for standard interactions (e.g., tab switch).
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy impact for significant interactions (e.g., bookmark saved).
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Success notification (e.g., download completed).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Error notification (e.g., action failed).
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Warning notification (e.g., tab limit approaching).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Selection feedback for picker/toggle changes.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
