// SettingsView.swift
// VeloBrowser
//
// Application settings screen with ad blocker, privacy, and general options.

import SwiftUI
import WebKit

/// Search engines available for the address bar.
enum SearchEngine: String, CaseIterable, Identifiable {
    case google = "Google"
    case duckDuckGo = "DuckDuckGo"
    case bing = "Bing"

    var id: String { rawValue }

    /// The URL template for this search engine.
    /// Use `%@` as placeholder for the search query.
    var urlTemplate: String {
        switch self {
        case .google:
            return "https://www.google.com/search?q=%@"
        case .duckDuckGo:
            return "https://duckduckgo.com/?q=%@"
        case .bing:
            return "https://www.bing.com/search?q=%@"
        }
    }
}

/// The application settings view with sections for general, ad blocker, privacy, and about.
struct SettingsView: View {
    @Bindable var adBlockService: AdBlockService
    let historyRepository: HistoryRepositoryProtocol
    let httpsUpgradeService: HTTPSUpgradeServiceProtocol
    let appLockService: AppLockServiceProtocol
    let trackingProtectionService: TrackingProtectionServiceProtocol
    let fingerprintProtectionService: FingerprintProtectionServiceProtocol
    @Environment(\.dismiss) private var dismiss

    @AppStorage("searchEngine") private var searchEngine: String = SearchEngine.google.rawValue
    @AppStorage("javaScriptEnabled") private var javaScriptEnabled: Bool = true
    @AppStorage("blockThirdPartyCookies") private var blockThirdPartyCookies: Bool = false

    @State private var showClearDataAlert = false
    @State private var isClearing = false

    var body: some View {
        Form {
            generalSection
            performanceSection
            adBlockerSection
            privacySection
            if DeviceHelper.isIPad {
                iPadSection
            }
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear Browsing Data", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearBrowsingData()
            }
        } message: {
            Text("This will remove all history, cookies, and cached data. This action cannot be undone.")
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            // Search engine picker
            Picker("Search Engine", selection: $searchEngine) {
                ForEach(SearchEngine.allCases) { engine in
                    Text(engine.rawValue).tag(engine.rawValue)
                }
            }
            .accessibilityLabel("Default search engine")

            // JavaScript toggle
            Toggle("JavaScript", isOn: $javaScriptEnabled)
                .accessibilityLabel("Enable JavaScript")

            // Storage & Cache
            NavigationLink {
                CacheManagerView()
            } label: {
                Label("Storage & Cache", systemImage: "internaldrive")
            }
        } header: {
            Label("General", systemImage: "gearshape")
        }
    }

    // MARK: - Performance Section

    @AppStorage("tabSuspensionEnabled") private var tabSuspensionEnabled: Bool = true
    @AppStorage("tabSuspensionTimeout") private var tabSuspensionTimeout: Int = SuspensionTimeout.fiveMinutes.rawValue

    private var performanceSection: some View {
        Section {
            Toggle("Suspend Inactive Tabs", isOn: $tabSuspensionEnabled)
                .accessibilityHint("Automatically free memory from tabs you haven't used recently")

            if tabSuspensionEnabled {
                Picker("Suspend After", selection: $tabSuspensionTimeout) {
                    ForEach(SuspensionTimeout.allCases.filter { $0 != .never }, id: \.rawValue) { timeout in
                        Text(timeout.label).tag(timeout.rawValue)
                    }
                }
            }
        } header: {
            Label("Performance", systemImage: "gauge.with.dots.needle.33percent")
        }
    }

    // MARK: - Ad Blocker Section

    private var adBlockerSection: some View {
        Section {
            Toggle("Ad Blocker", isOn: $adBlockService.isEnabled)
                .accessibilityLabel("Enable ad blocking")

            if adBlockService.isEnabled {
                NavigationLink {
                    allowlistView
                } label: {
                    HStack {
                        Text("Allowlisted Sites")
                        Spacer()
                        Text("\(adBlockService.allowlist.count)")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        } header: {
            Label("Ad Blocker", systemImage: "shield.fill")
        } footer: {
            Text("Blocks ads and trackers for faster, cleaner browsing.")
                .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            // Privacy Dashboard link
            NavigationLink {
                PrivacyDashboardView(
                    adBlockService: adBlockService,
                    trackingProtection: trackingProtectionService,
                    httpsUpgrade: httpsUpgradeService,
                    fingerprintProtection: fingerprintProtectionService
                )
            } label: {
                Label("Privacy Dashboard", systemImage: "chart.bar.fill")
            }

            // HTTPS-Only Mode
            Toggle(isOn: Binding(
                get: { httpsUpgradeService.isEnabled },
                set: { (httpsUpgradeService as? HTTPSUpgradeService)?.isEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HTTPS-Only Mode")
                    Text("Auto-upgrade HTTP to HTTPS")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .accessibilityLabel("HTTPS-Only Mode")

            // Tracking Protection
            Toggle(isOn: Binding(
                get: { trackingProtectionService.isEnabled },
                set: { (trackingProtectionService as? TrackingProtectionService)?.isEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove Tracking Parameters")
                    if trackingProtectionService.strippedCount > 0 {
                        Text("\(trackingProtectionService.strippedCount) parameters removed")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .accessibilityLabel("Remove tracking parameters from URLs")

            // Fingerprint Protection
            Toggle(isOn: Binding(
                get: { fingerprintProtectionService.isEnabled },
                set: { (fingerprintProtectionService as? FingerprintProtectionService)?.isEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fingerprint Protection")
                    Text("Some sites may not work correctly")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .accessibilityLabel("Enable fingerprint protection")

            // Block Third-Party Cookies
            Toggle(isOn: $blockThirdPartyCookies) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block Third-Party Cookies")
                    Text("Restart tabs for changes to take effect")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .accessibilityLabel("Block third-party cookies")

            // App Lock
            if appLockService.isBiometricAvailable {
                Toggle(isOn: Binding(
                    get: { appLockService.isLockEnabled },
                    set: { (appLockService as? AppLockService)?.isLockEnabled = $0 }
                )) {
                    let label = appLockService.biometryType == .faceID ? "Face ID Lock" : "Touch ID Lock"
                    Text(label)
                }
                .accessibilityLabel("Biometric app lock")

                if appLockService.isLockEnabled {
                    Picker("Lock After", selection: Binding(
                        get: { appLockService.lockTimeout.rawValue },
                        set: {
                            if let timeout = LockTimeout(rawValue: $0) {
                                (appLockService as? AppLockService)?.lockTimeout = timeout
                            }
                        }
                    )) {
                        ForEach(LockTimeout.allCases) { timeout in
                            Text(timeout.rawValue).tag(timeout.rawValue)
                        }
                    }
                }
            }

            // Cookie Management
            NavigationLink {
                CookieManagerView()
            } label: {
                Label("Manage Cookies", systemImage: "list.bullet.rectangle")
            }

            // Clear Browsing Data
            Button(role: .destructive) {
                showClearDataAlert = true
            } label: {
                if isClearing {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Clearing…")
                    }
                } else {
                    Label("Clear Browsing Data", systemImage: "trash")
                }
            }
            .disabled(isClearing)
        } header: {
            Label("Privacy & Security", systemImage: "hand.raised.fill")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    // MARK: - iPad Section

    @AppStorage("iPadShowTabBar") private var iPadShowTabBar: Bool = true
    @AppStorage("iPadShowSidebar") private var iPadShowSidebar: Bool = false
    @AppStorage("iPadDesktopByDefault") private var iPadDesktopByDefault: Bool = true

    private var iPadSection: some View {
        Section {
            Toggle("Show Tab Bar", isOn: $iPadShowTabBar)
                .accessibilityHint("Show horizontal tab bar at the top of the screen")

            Toggle("Show Sidebar", isOn: $iPadShowSidebar)
                .accessibilityHint("Show sidebar with bookmarks, history, and downloads")

            Toggle("Desktop Mode by Default", isOn: $iPadDesktopByDefault)
                .accessibilityHint("Automatically request desktop versions of websites")
        } header: {
            Label("iPad Display", systemImage: "ipad.landscape")
        }
    }

    // MARK: - Allowlist Subview

    private var allowlistView: some View {
        List {
            if adBlockService.allowlist.isEmpty {
                Text("No allowlisted sites")
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .font(DesignSystem.Typography.subheadline)
            } else {
                ForEach(Array(adBlockService.allowlist.sorted()), id: \.self) { domain in
                    Text(domain)
                }
                .onDelete { indexSet in
                    let sorted = adBlockService.allowlist.sorted()
                    for index in indexSet {
                        adBlockService.removeFromAllowlist(sorted[index])
                    }
                }
            }
        }
        .navigationTitle("Allowlisted Sites")
    }

    // MARK: - Private

    private func clearBrowsingData() {
        isClearing = true
        Task {
            let dataStore = WKWebsiteDataStore.default()
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            await dataStore.removeData(ofTypes: types, modifiedSince: .distantPast)
            try? await historyRepository.clearAll()
            isClearing = false
            HapticManager.success()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
