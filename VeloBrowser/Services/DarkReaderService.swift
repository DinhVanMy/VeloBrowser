// DarkReaderService.swift
// VeloBrowser
//
// Injects CSS to darken any web page, preserving images and media.

import Foundation
import WebKit

/// Service that applies dark mode CSS to any web page.
@Observable
@MainActor
final class DarkReaderService {
    /// Whether dark reader is currently active.
    var isEnabled: Bool = false

    /// JavaScript to inject/remove dark mode CSS.
    static let darkReaderCSS = """
    html {
        filter: invert(1) hue-rotate(180deg) !important;
        background: #111 !important;
    }
    img, video, picture, canvas, svg, [style*="background-image"],
    .emoji, figure, iframe {
        filter: invert(1) hue-rotate(180deg) !important;
    }
    html { transition: filter 0.3s ease; }
    """

    /// Injects dark reader CSS into the web view.
    func apply(to webView: WKWebView) {
        let js = """
        (function() {
            var existing = document.getElementById('velgo-dark-reader');
            if (existing) return;
            var style = document.createElement('style');
            style.id = 'velgo-dark-reader';
            style.textContent = `\(Self.darkReaderCSS)`;
            document.head.appendChild(style);
        })();
        """
        webView.evaluateJavaScript(js) { _, _ in }
        isEnabled = true
    }

    /// Removes dark reader CSS from the web view.
    func remove(from webView: WKWebView) {
        let js = """
        (function() {
            var el = document.getElementById('velgo-dark-reader');
            if (el) el.remove();
        })();
        """
        webView.evaluateJavaScript(js) { _, _ in }
        isEnabled = false
    }

    /// Toggles dark reader on/off.
    func toggle(in webView: WKWebView) {
        if isEnabled {
            remove(from: webView)
        } else {
            apply(to: webView)
        }
    }
}
