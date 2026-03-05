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
    @Environment(DIContainer.self) private var container
    @FocusState private var isFocused: Bool
    @AppStorage("searchEngine") private var searchEngine: String = SearchEngine.google.rawValue

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
                    HStack(spacing: 4) {
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

                        // Clear button
                        if !viewModel.addressBarText.isEmpty {
                            Button {
                                viewModel.addressBarText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                            .accessibilityLabel("Clear address bar")
                        }
                    }
                } else {
                    VStack(spacing: 0) {
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

                        // Paste & Go hint
                        if clipboardHasURL, let clip = clipboardString,
                           clip != viewModel.addressBarText {
                            Button {
                                viewModel.addressBarText = clip
                                viewModel.submitAddressBar()
                                HapticManager.light()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.caption2)
                                    Text("Paste & Go")
                                        .font(DesignSystem.Typography.caption2)
                                }
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .padding(.top, 2)
                            }
                            .accessibilityLabel("Paste and navigate to clipboard URL")
                        }
                    }
                }

                // Reload / Stop button
                reloadStopButton

                // Reader mode button
                readerModeButton

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

            // Search suggestions dropdown
            if isFocused && !container.searchSuggestionService.suggestions.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(container.searchSuggestionService.suggestions, id: \.self) { suggestion in
                            Button {
                                viewModel.addressBarText = suggestion
                                viewModel.submitAddressBar()
                                container.searchSuggestionService.clear()
                            } label: {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    Text(suggestion)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    // Fill-in button (appends to address bar without submitting)
                                    Button {
                                        viewModel.addressBarText = suggestion
                                    } label: {
                                        Image(systemName: "arrow.up.left")
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                            }
                            .buttonStyle(.plain)

                            if suggestion != container.searchSuggestionService.suggestions.last {
                                Divider().padding(.leading, DesignSystem.Spacing.xl)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
                .background(DesignSystem.Colors.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: DesignSystem.AnimationDuration.fast), value: viewModel.isLoading)
        .animation(.easeOut(duration: DesignSystem.AnimationDuration.fast), value: container.searchSuggestionService.suggestions)
        .draggable(viewModel.currentURL?.absoluteString ?? "") {
            // Drag preview: show domain
            Label(viewModel.displayDomain, systemImage: "link")
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let dropped = items.first, !dropped.isEmpty else { return false }
            viewModel.addressBarText = dropped
            viewModel.submitAddressBar()
            return true
        }
        .onChange(of: viewModel.isAddressBarFocused) { _, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { _, newValue in
            viewModel.isAddressBarFocused = newValue
            if !newValue {
                container.searchSuggestionService.clear()
            }
        }
        .onChange(of: viewModel.addressBarText) { _, newText in
            if isFocused {
                container.searchSuggestionService.fetchSuggestions(for: newText, engine: searchEngine)
            }
        }
    }

    // MARK: - Subviews

    /// Displays domain-only when unfocused, full URL when focused.
    private var displayText: String {
        if let url = viewModel.currentURL {
            return viewModel.displayDomain.isEmpty ? url.absoluteString : viewModel.displayDomain
        }
        return viewModel.addressBarText.isEmpty ? "Search or enter URL" : viewModel.addressBarText
    }

    /// Whether the clipboard contains a URL that can be pasted.
    private var clipboardHasURL: Bool {
        guard let string = UIPasteboard.general.string else { return false }
        return string.contains(".") || string.hasPrefix("http")
    }

    /// The URL string from clipboard for Paste & Go.
    private var clipboardString: String? {
        UIPasteboard.general.string
    }

    private var securityIcon: some View {
        let isHTTPS = viewModel.currentURL?.scheme == "https"
        let isHTTP = viewModel.currentURL?.scheme == "http"
        return HStack(spacing: 2) {
            Image(systemName: isHTTPS ? "lock.fill" : (isHTTP ? "lock.open.fill" : "lock.open"))
                .font(.caption)
                .foregroundStyle(
                    isHTTPS
                        ? DesignSystem.Colors.success
                        : (isHTTP ? DesignSystem.Colors.destructive : DesignSystem.Colors.textTertiary)
                )
            if isHTTP {
                Text("Not Secure")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.destructive)
            }
        }
        .frame(minWidth: 20)
        .accessibilityLabel(
            isHTTPS ? "Secure connection" : "Not secure"
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
        .hoverEffect(.highlight)
    }

    @ViewBuilder
    private var readerModeButton: some View {
        if viewModel.isPageReadable && viewModel.currentURL != nil {
            Button {
                viewModel.showReaderMode = true
            } label: {
                Image(systemName: viewModel.showReaderMode ? "book.fill" : "book")
                    .font(.caption)
                    .foregroundStyle(
                        viewModel.showReaderMode
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary
                    )
                    .frame(minWidth: 28, minHeight: DesignSystem.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Reader mode")
            .transition(.scale.combined(with: .opacity))
        }
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
