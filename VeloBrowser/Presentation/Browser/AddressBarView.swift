// AddressBarView.swift
// VeloBrowser
//
// Collapsible address bar with URL display, loading progress, and security indicator.

import SwiftUI

/// The browser address bar showing the current URL with editing support.
///
/// Features a security lock indicator, loading progress bar,
/// reload/stop button, ad-block shield badge, and private mode label.
/// Collapses when scrolling down (controlled by parent).
struct AddressBarView: View {
    @Bindable var viewModel: BrowserViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Private mode indicator
                if viewModel.isPrivate {
                    Text("Private")
                        .font(DesignSystem.Typography.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .clipShape(Capsule())
                        .accessibilityLabel("Private browsing mode")
                }

                // Security indicator
                securityIcon

                // URL text field — show domain only when unfocused
                if isFocused {
                    TextField("Search or enter URL", text: $viewModel.addressBarText)
                        .font(DesignSystem.Typography.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .focused($isFocused)
                        .onSubmit {
                            viewModel.submitAddressBar()
                        }
                        .accessibilityLabel("Address bar")
                } else {
                    Text(displayText)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.isAddressBarFocused = true
                        }
                        .accessibilityLabel("Address bar, \(displayText)")
                }

                // Reload / Stop button
                reloadStopButton

                // Ad block badge
                adBlockBadge
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                viewModel.isPrivate
                    ? Color.purple.opacity(0.1)
                    : DesignSystem.Colors.fillTertiary
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
            .padding(.horizontal, DesignSystem.Spacing.md)

            // Loading progress bar — thin accent-colored bar
            if viewModel.isLoading {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(DesignSystem.Colors.accent)
                        .frame(
                            width: geometry.size.width * viewModel.loadingProgress,
                            height: 2
                        )
                        .animation(.easeInOut(duration: 0.2), value: viewModel.loadingProgress)
                }
                .frame(height: 2)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: DesignSystem.AnimationDuration.fast), value: viewModel.isLoading)
        .onChange(of: viewModel.isAddressBarFocused) { _, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { _, newValue in
            viewModel.isAddressBarFocused = newValue
        }
    }

    // MARK: - Subviews

    /// Displays domain-only when unfocused, full URL when focused.
    private var displayText: String {
        if let url = viewModel.currentURL {
            return url.host() ?? url.absoluteString
        }
        return viewModel.addressBarText.isEmpty ? "Search or enter URL" : viewModel.addressBarText
    }

    private var securityIcon: some View {
        Image(systemName: viewModel.currentURL?.scheme == "https" ? "lock.fill" : "lock.open")
            .font(.caption)
            .foregroundStyle(
                viewModel.currentURL?.scheme == "https"
                    ? DesignSystem.Colors.success
                    : DesignSystem.Colors.textTertiary
            )
            .frame(minWidth: 20)
            .accessibilityLabel(
                viewModel.currentURL?.scheme == "https" ? "Secure connection" : "Not secure"
            )
    }

    private var reloadStopButton: some View {
        Button {
            if viewModel.isLoading {
                viewModel.stopLoading()
            } else {
                viewModel.reload()
            }
        } label: {
            Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(minWidth: DesignSystem.minimumTouchTarget,
                       minHeight: DesignSystem.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(viewModel.isLoading ? "Stop loading" : "Reload page")
    }

    @ViewBuilder
    private var adBlockBadge: some View {
        if viewModel.adsBlockedCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: "shield.fill")
                    .font(.caption2)
                Text("\(viewModel.adsBlockedCount)")
                    .font(DesignSystem.Typography.caption2)
            }
            .foregroundStyle(DesignSystem.Colors.success)
            .accessibilityLabel("\(viewModel.adsBlockedCount) ads blocked")
        } else {
            Image(systemName: "shield")
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .accessibilityLabel("Ad blocker active")
        }
    }
}
