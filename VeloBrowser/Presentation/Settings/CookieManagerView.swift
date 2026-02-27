// CookieManagerView.swift
// VeloBrowser
//
// View for managing browser cookies grouped by domain.

import SwiftUI
import WebKit

/// Displays and manages cookies stored by the browser, grouped by domain.
///
/// Users can view cookie details per domain, delete cookies per domain,
/// or clear all cookies at once.
struct CookieManagerView: View {
    @State private var cookieGroups: [String: [HTTPCookie]] = [:]
    @State private var isLoading = true
    @State private var showDeleteAllAlert = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cookieGroups.isEmpty {
                ContentUnavailableView {
                    Label("No Cookies", systemImage: "tray")
                } description: {
                    Text("No cookies are stored in the browser.")
                }
            } else {
                cookieList
            }
        }
        .navigationTitle("Cookies")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !cookieGroups.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All", role: .destructive) {
                        showDeleteAllAlert = true
                    }
                }
            }
        }
        .alert("Delete All Cookies", isPresented: $showDeleteAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                Task { await deleteAllCookies() }
            }
        } message: {
            Text("This will remove all cookies from all websites.")
        }
        .task { await loadCookies() }
    }

    // MARK: - Cookie List

    private var cookieList: some View {
        List {
            ForEach(sortedDomains, id: \.self) { domain in
                NavigationLink {
                    cookieDetailView(for: domain)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(domain)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                            Text("\(cookieGroups[domain]?.count ?? 0) cookies")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await deleteCookies(for: domain) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await loadCookies() }
    }

    // MARK: - Cookie Detail

    private func cookieDetailView(for domain: String) -> some View {
        let cookies = cookieGroups[domain] ?? []
        return List {
            ForEach(cookies, id: \.name) { cookie in
                VStack(alignment: .leading, spacing: 4) {
                    Text(cookie.name)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(cookie.value.prefix(100) + (cookie.value.count > 100 ? "…" : ""))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: DesignSystem.Spacing.md) {
                        if cookie.isSecure {
                            Label("Secure", systemImage: "lock.fill")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.success)
                        }

                        if cookie.isHTTPOnly {
                            Label("HTTP Only", systemImage: "server.rack")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }

                        if let expiry = cookie.expiresDate {
                            Text("Expires: \(expiry, style: .date)")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle(domain)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed

    private var sortedDomains: [String] {
        cookieGroups.keys.sorted()
    }

    // MARK: - Actions

    private func loadCookies() async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let allCookies = await store.allCookies()
        var groups: [String: [HTTPCookie]] = [:]
        for cookie in allCookies {
            let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
            groups[domain, default: []].append(cookie)
        }
        cookieGroups = groups
        isLoading = false
    }

    private func deleteCookies(for domain: String) async {
        guard let cookies = cookieGroups[domain] else { return }
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in cookies {
            await store.deleteCookie(cookie)
        }
        await loadCookies()
        HapticManager.success()
    }

    private func deleteAllCookies() async {
        let store = WKWebsiteDataStore.default()
        let types: Set<String> = ["WKWebsiteDataTypeCookies"]
        await store.removeData(ofTypes: types, modifiedSince: .distantPast)
        await loadCookies()
        HapticManager.success()
    }
}
