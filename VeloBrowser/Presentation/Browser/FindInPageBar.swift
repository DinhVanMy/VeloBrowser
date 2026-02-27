// FindInPageBar.swift
// VeloBrowser
//
// A search bar for finding text within the current web page.

import SwiftUI
import WebKit

/// A compact search bar for finding text within the current web page.
///
/// Provides search text input, result count display, and navigation
/// between matches using WKWebView's built-in find API.
struct FindInPageBar: View {
    @Binding var isVisible: Bool
    weak var webView: WKWebView?

    @State private var searchText = ""
    @State private var resultCount = 0
    @State private var currentResult = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Search field
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .font(.caption)

                TextField("Find on page", text: $searchText)
                    .font(DesignSystem.Typography.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit { findNext() }
                    .onChange(of: searchText) { _, newValue in
                        performSearch(newValue)
                    }

                if !searchText.isEmpty {
                    Text("\(currentResult)/\(resultCount)")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 6)
            .background(DesignSystem.Colors.fillTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))

            // Navigation buttons
            Button { findPrevious() } label: {
                Image(systemName: "chevron.up")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .disabled(resultCount == 0)
            .accessibilityLabel("Previous match")

            Button { findNext() } label: {
                Image(systemName: "chevron.down")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .disabled(resultCount == 0)
            .accessibilityLabel("Next match")

            // Done button
            Button("Done") {
                clearSearch()
                isVisible = false
            }
            .font(DesignSystem.Typography.body)
            .foregroundStyle(DesignSystem.Colors.accent)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            DesignSystem.Colors.backgroundPrimary
                .shadow(.drop(color: .black.opacity(0.1), radius: 2, y: 2))
        )
        .onAppear {
            isFocused = true
        }
        .onDisappear {
            clearSearch()
        }
    }

    // MARK: - Private

    private func performSearch(_ query: String) {
        guard let webView, !query.isEmpty else {
            resultCount = 0
            currentResult = 0
            return
        }

        let js = """
        (function() {
            // Remove previous highlights
            document.querySelectorAll('.velo-find-highlight').forEach(function(el) {
                el.outerHTML = el.textContent;
            });

            var query = '\(query.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\\", with: "\\\\"))';
            if (!query) return JSON.stringify({count: 0, current: 0});

            var body = document.body;
            var walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, null, false);
            var matches = [];
            var node;
            while (node = walker.nextNode()) {
                var idx = node.textContent.toLowerCase().indexOf(query.toLowerCase());
                if (idx >= 0) {
                    matches.push({node: node, index: idx});
                }
            }

            return JSON.stringify({count: matches.length, current: matches.length > 0 ? 1 : 0});
        })();
        """

        webView.evaluateJavaScript(js) { result, _ in
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                Task { @MainActor in
                    resultCount = info["count"] as? Int ?? 0
                    currentResult = info["current"] as? Int ?? 0
                }
            }
        }

        // Use WKWebView's native find-in-page highlight
        let findJS = "window.find('\(query.replacingOccurrences(of: "'", with: "\\'"))', false, false, true)"
        webView.evaluateJavaScript(findJS, completionHandler: nil)
    }

    private func findNext() {
        guard let webView, !searchText.isEmpty else { return }
        let js = "window.find('\(searchText.replacingOccurrences(of: "'", with: "\\'"))', false, false, true)"
        webView.evaluateJavaScript(js) { _, _ in
            Task { @MainActor in
                if currentResult < resultCount {
                    currentResult += 1
                } else {
                    currentResult = 1
                }
            }
        }
    }

    private func findPrevious() {
        guard let webView, !searchText.isEmpty else { return }
        let js = "window.find('\(searchText.replacingOccurrences(of: "'", with: "\\'"))', false, true, true)"
        webView.evaluateJavaScript(js) { _, _ in
            Task { @MainActor in
                if currentResult > 1 {
                    currentResult -= 1
                } else {
                    currentResult = resultCount
                }
            }
        }
    }

    private func clearSearch() {
        searchText = ""
        resultCount = 0
        currentResult = 0
        // Clear selection
        webView?.evaluateJavaScript("window.getSelection().removeAllRanges()", completionHandler: nil)
    }
}
