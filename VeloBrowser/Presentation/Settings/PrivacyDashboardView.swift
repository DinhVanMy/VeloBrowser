// PrivacyDashboardView.swift
// VeloBrowser
//
// Summary dashboard showing all privacy protection statistics.

import SwiftUI

/// Displays a summary of all privacy protection stats in card format.
///
/// Shows counts for ads blocked, tracking parameters stripped,
/// HTTPS upgrades, and status of fingerprint protection.
struct PrivacyDashboardView: View {
    let adBlockService: AdBlockService
    let trackingProtection: TrackingProtectionServiceProtocol
    let httpsUpgrade: HTTPSUpgradeServiceProtocol
    let fingerprintProtection: FingerprintProtectionServiceProtocol

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Header
                Text("Your Privacy Protection")
                    .font(.title3.bold())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.md)

                // Stats cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                    GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
                ], spacing: DesignSystem.Spacing.md) {
                    statCard(
                        icon: "shield.fill",
                        title: "Ads Blocked",
                        value: "\(adBlockService.totalAdsBlocked)",
                        color: DesignSystem.Colors.success,
                        isActive: adBlockService.isEnabled
                    )

                    statCard(
                        icon: "link.badge.plus",
                        title: "Trackers Stripped",
                        value: "\(trackingProtection.strippedCount)",
                        color: .orange,
                        isActive: trackingProtection.isEnabled
                    )

                    statCard(
                        icon: "lock.shield.fill",
                        title: "HTTPS Upgrades",
                        value: "\(httpsUpgrade.upgradeCount)",
                        color: DesignSystem.Colors.accent,
                        isActive: httpsUpgrade.isEnabled
                    )

                    statCard(
                        icon: "hand.raised.fill",
                        title: "Fingerprint Shield",
                        value: fingerprintProtection.isEnabled ? "Active" : "Off",
                        color: .purple,
                        isActive: fingerprintProtection.isEnabled
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.md)

                // Protection status
                protectionStatus
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .navigationTitle("Privacy Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .background(DesignSystem.Colors.backgroundPrimary)
    }

    // MARK: - Stat Card

    private func statCard(
        icon: String,
        title: String,
        value: String,
        color: Color,
        isActive: Bool
    ) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isActive ? color : DesignSystem.Colors.textTertiary)

            Text(value)
                .font(.title.bold())
                .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Protection Status

    private var protectionStatus: some View {
        let activeCount = [
            adBlockService.isEnabled,
            trackingProtection.isEnabled,
            httpsUpgrade.isEnabled,
            fingerprintProtection.isEnabled
        ].filter { $0 }.count

        return VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: activeCount == 4 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(activeCount == 4 ? DesignSystem.Colors.success : DesignSystem.Colors.warning)
                Text(statusMessage(activeCount: activeCount))
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
            }

            Text("Enable all protections for maximum privacy.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private func statusMessage(activeCount: Int) -> String {
        switch activeCount {
        case 4: return "All protections active"
        case 3: return "3 of 4 protections active"
        case 2: return "2 of 4 protections active"
        case 1: return "1 of 4 protections active"
        default: return "No protections active"
        }
    }
}
