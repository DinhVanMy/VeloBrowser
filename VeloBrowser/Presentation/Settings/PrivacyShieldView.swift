// PrivacyShieldView.swift
// VeloBrowser
//
// Per-site privacy shield showing blocked ads, trackers, HTTPS status.

import SwiftUI

/// Per-site privacy information sheet.
struct PrivacyShieldView: View {
    let domain: String
    let adsBlocked: Int
    let trackersStripped: Int
    let isHTTPS: Bool
    let fingerprintProtected: Bool
    @Environment(DIContainer.self) private var container

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: gradeIcon)
                                .font(.system(size: 48))
                                .foregroundStyle(gradeColor)
                            Text(gradeLabel)
                                .font(DesignSystem.Typography.headline)
                            Text(domain)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Protection") {
                    shieldRow(icon: "shield.checkered", title: "Ads Blocked", value: "\(adsBlocked)", color: .red)
                    shieldRow(icon: "eye.slash", title: "Trackers Stripped", value: "\(trackersStripped)", color: .orange)
                    shieldRow(icon: "lock.fill", title: "Connection", value: isHTTPS ? "Secure (HTTPS)" : "Not Secure", color: isHTTPS ? .green : .red)
                    shieldRow(icon: "person.badge.shield.checkmark", title: "Fingerprint Protection", value: fingerprintProtected ? "Active" : "Off", color: fingerprintProtected ? .green : .gray)
                }

                Section("Site Controls") {
                    Toggle("Ad Blocking", isOn: Binding(
                        get: { !container.adBlockService.isAllowlisted(domain) },
                        set: { newValue in
                            if newValue {
                                container.adBlockService.removeFromAllowlist(domain)
                            } else {
                                container.adBlockService.addToAllowlist(domain)
                            }
                        }
                    ))
                }
            }
            .navigationTitle("Privacy Shield")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var gradeIcon: String {
        let score = (isHTTPS ? 30 : 0) + (fingerprintProtected ? 30 : 0) + (adsBlocked > 0 ? 20 : 0) + 20
        if score >= 70 { return "checkmark.shield.fill" }
        if score >= 40 { return "shield.fill" }
        return "exclamationmark.shield.fill"
    }

    private var gradeColor: Color {
        let score = (isHTTPS ? 30 : 0) + (fingerprintProtected ? 30 : 0) + (adsBlocked > 0 ? 20 : 0) + 20
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }

    private var gradeLabel: String {
        let score = (isHTTPS ? 30 : 0) + (fingerprintProtected ? 30 : 0) + (adsBlocked > 0 ? 20 : 0) + 20
        if score >= 70 { return "Well Protected" }
        if score >= 40 { return "Partially Protected" }
        return "At Risk"
    }

    private func shieldRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .font(DesignSystem.Typography.caption)
        }
    }
}

/// Weekly privacy report showing cumulative protection stats.
struct PrivacyReportView: View {
    @AppStorage("weeklyAdsBlocked") private var weeklyAds: Int = 0
    @AppStorage("weeklyTrackersStripped") private var weeklyTrackers: Int = 0
    @AppStorage("weeklyHTTPSUpgrades") private var weeklyHTTPS: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("\(weeklyAds + weeklyTrackers + weeklyHTTPS)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Text("Threats Blocked This Week")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                        statCard(icon: "shield.checkered", title: "Ads Blocked", value: weeklyAds, color: .red)
                        statCard(icon: "eye.slash", title: "Trackers", value: weeklyTrackers, color: .orange)
                        statCard(icon: "lock.fill", title: "HTTPS Upgrades", value: weeklyHTTPS, color: .green)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Privacy Report")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func statCard(icon: String, title: String, value: Int, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }
}
