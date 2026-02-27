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
    @Environment(\.dismiss) private var dismiss

    @AppStorage("searchEngine") private var searchEngine: String = SearchEngine.google.rawValue
    @AppStorage("javaScriptEnabled") private var javaScriptEnabled: Bool = true

    @State private var showClearDataAlert = false
    @State private var isClearing = false

    var body: some View {
        Form {
            generalSection
            adBlockerSection
            privacySection
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

        } header: {
            Label("General", systemImage: "gearshape")
        }
    }

    // MARK: - Ad Blocker Section

    private var adBlockerSection: some View {
        Section {
            Toggle("Ad Blocker", isOn: $adBlockService.isEnabled)
                .accessibilityLabel("Enable ad blocking")

            if adBlockService.isEnabled {
                NavigationLink {
                    whitelistView
                } label: {
                    HStack {
                        Text("Whitelisted Sites")
                        Spacer()
                        Text("\(adBlockService.whitelist.count)")
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
            Label("Privacy", systemImage: "hand.raised.fill")
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

    // MARK: - Whitelist Subview

    private var whitelistView: some View {
        List {
            if adBlockService.whitelist.isEmpty {
                Text("No whitelisted sites")
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .font(DesignSystem.Typography.subheadline)
            } else {
                ForEach(Array(adBlockService.whitelist.sorted()), id: \.self) { domain in
                    Text(domain)
                }
                .onDelete { indexSet in
                    let sorted = adBlockService.whitelist.sorted()
                    for index in indexSet {
                        adBlockService.removeFromWhitelist(sorted[index])
                    }
                }
            }
        }
        .navigationTitle("Whitelisted Sites")
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
