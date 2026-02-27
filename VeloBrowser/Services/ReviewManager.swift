// ReviewManager.swift
// VeloBrowser
//
// Manages App Store review prompts at strategic moments
// following Apple's guidelines for review request frequency.

import StoreKit
import SwiftUI

/// Manages when to prompt users for an App Store review.
///
/// Tracks usage metrics and only requests reviews at appropriate moments:
/// - After the user has created 20+ tabs lifetime
/// - After 7+ days since first launch
/// - Maximum once per session, respecting Apple's 3-per-year limit
@MainActor
final class ReviewManager {
    /// Key for total tabs created lifetime.
    private static let totalTabsKey = "totalTabsCreated"
    /// Key for first launch date.
    private static let firstLaunchKey = "firstLaunchDate"
    /// Key for last review prompt date.
    private static let lastPromptKey = "lastReviewPromptDate"
    /// Key for prompt count this year.
    private static let promptCountKey = "reviewPromptCount"

    /// Minimum tabs before first review prompt.
    private static let minTabsForReview = 20
    /// Minimum days since first launch before prompting.
    private static let minDaysForReview = 7
    /// Maximum review prompts per 365 days.
    private static let maxPromptsPerYear = 3
    /// Minimum days between prompts.
    private static let minDaysBetweenPrompts = 90

    /// Records that the app has launched (sets first launch date if needed).
    func recordLaunch() {
        if UserDefaults.standard.object(forKey: Self.firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: Self.firstLaunchKey)
        }
    }

    /// Records a tab creation and checks if a review should be requested.
    func recordTabCreated() {
        let current = UserDefaults.standard.integer(forKey: Self.totalTabsKey)
        UserDefaults.standard.set(current + 1, forKey: Self.totalTabsKey)
    }

    /// Checks conditions and requests a review if appropriate.
    ///
    /// Call this at natural pause points (e.g., after navigating, after bookmark save).
    func requestReviewIfAppropriate() {
        guard shouldRequestReview() else { return }

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            UserDefaults.standard.set(Date(), forKey: Self.lastPromptKey)
            let count = UserDefaults.standard.integer(forKey: Self.promptCountKey)
            UserDefaults.standard.set(count + 1, forKey: Self.promptCountKey)
        }
    }

    // MARK: - Private

    private func shouldRequestReview() -> Bool {
        let totalTabs = UserDefaults.standard.integer(forKey: Self.totalTabsKey)
        guard totalTabs >= Self.minTabsForReview else { return false }

        guard let firstLaunch = UserDefaults.standard.object(forKey: Self.firstLaunchKey) as? Date else {
            return false
        }
        let daysSinceFirstLaunch = Calendar.current.dateComponents(
            [.day], from: firstLaunch, to: Date()
        ).day ?? 0
        guard daysSinceFirstLaunch >= Self.minDaysForReview else { return false }

        // Check prompt frequency
        if let lastPrompt = UserDefaults.standard.object(forKey: Self.lastPromptKey) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents(
                [.day], from: lastPrompt, to: Date()
            ).day ?? 0
            guard daysSinceLastPrompt >= Self.minDaysBetweenPrompts else { return false }
        }

        let promptCount = UserDefaults.standard.integer(forKey: Self.promptCountKey)
        guard promptCount < Self.maxPromptsPerYear else { return false }

        return true
    }
}
