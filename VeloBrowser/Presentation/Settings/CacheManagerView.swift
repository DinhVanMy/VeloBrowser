// CacheManagerView.swift
// VeloBrowser
//
// Settings view for managing browser cache and website data storage.

import SwiftUI
import WebKit

/// View for managing browser cache, cookies, and website data.
///
/// Shows storage usage by data type, allows selective clearing,
/// and provides per-domain storage breakdown.
struct CacheManagerView: View {
    @State private var dataRecords: [WKWebsiteDataRecord] = []
    @State private var isLoading = true
    @State private var showClearCacheAlert = false
    @State private var showClearAllAlert = false

    var body: some View {
        List {
            // Summary section
            Section {
                HStack {
                    Label("Total Sites", systemImage: "globe")
                    Spacer()
                    Text("\(dataRecords.count)")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            } header: {
                Label("Overview", systemImage: "chart.bar")
            }

            // Actions section
            Section {
                Button {
                    showClearCacheAlert = true
                } label: {
                    Label("Clear Cache", systemImage: "trash")
                        .foregroundStyle(DesignSystem.Colors.accent)
                }

                Button(role: .destructive) {
                    showClearAllAlert = true
                } label: {
                    Label("Clear All Website Data", systemImage: "trash.fill")
                }
            } header: {
                Label("Actions", systemImage: "gear")
            }

            // Per-site breakdown
            Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if dataRecords.isEmpty {
                    Text("No website data stored")
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .font(DesignSystem.Typography.subheadline)
                } else {
                    ForEach(dataRecords, id: \.displayName) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.displayName)
                                    .font(DesignSystem.Typography.body)
                                    .lineLimit(1)
                                Text(dataTypesSummary(record.dataTypes))
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                            Spacer()
                            Text("\(record.dataTypes.count) types")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
            } header: {
                Label("Sites (\(dataRecords.count))", systemImage: "list.bullet")
            }
        }
        .navigationTitle("Storage & Cache")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDataRecords()
        }
        .refreshable {
            await loadDataRecords()
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will clear disk and memory cache. Cookies and local storage will be preserved.")
        }
        .alert("Clear All Website Data", isPresented: $showClearAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will remove all cookies, cache, local storage, and other website data. You may be logged out of websites.")
        }
    }

    // MARK: - Data Loading

    private func loadDataRecords() async {
        isLoading = true
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        dataRecords = records.sorted { $0.displayName < $1.displayName }
        isLoading = false
    }

    // MARK: - Actions

    private func clearCache() {
        let cacheTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache
        ]
        let store = WKWebsiteDataStore.default()
        Task {
            await store.removeData(ofTypes: cacheTypes, modifiedSince: .distantPast)
            await loadDataRecords()
            HapticManager.success()
        }
    }

    private func clearAllData() {
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let store = WKWebsiteDataStore.default()
        Task {
            await store.removeData(ofTypes: allTypes, modifiedSince: .distantPast)
            await loadDataRecords()
            HapticManager.success()
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        let recordsToDelete = offsets.map { dataRecords[$0] }
        let store = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        Task {
            for record in recordsToDelete {
                await store.removeData(ofTypes: allTypes, for: [record])
            }
            await loadDataRecords()
            HapticManager.light()
        }
    }

    // MARK: - Helpers

    private func dataTypesSummary(_ types: Set<String>) -> String {
        var parts: [String] = []
        if types.contains(WKWebsiteDataTypeDiskCache) || types.contains(WKWebsiteDataTypeMemoryCache) {
            parts.append("Cache")
        }
        if types.contains(WKWebsiteDataTypeCookies) {
            parts.append("Cookies")
        }
        if types.contains(WKWebsiteDataTypeLocalStorage) {
            parts.append("Local Storage")
        }
        if types.contains(WKWebsiteDataTypeIndexedDBDatabases) {
            parts.append("IndexedDB")
        }
        return parts.isEmpty ? "Other" : parts.joined(separator: ", ")
    }
}
