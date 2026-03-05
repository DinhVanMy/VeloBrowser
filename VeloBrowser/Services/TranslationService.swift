// TranslationService.swift
// VeloBrowser
//
// Page translation using Apple's Translation framework (iOS 17.4+).

import Foundation
import WebKit
import os.log

/// Service for translating web page content.
@Observable
@MainActor
final class TranslationService {
    /// Whether translation is in progress.
    private(set) var isTranslating: Bool = false

    /// Whether the current page has been translated.
    private(set) var isTranslated: Bool = false

    /// JavaScript to extract and replace visible text for translation.
    private static let extractTextJS = """
    (function() {
        var walker = document.createTreeWalker(
            document.body, NodeFilter.SHOW_TEXT, null, false
        );
        var texts = [];
        var nodes = [];
        while (walker.nextNode()) {
            var text = walker.currentNode.textContent.trim();
            if (text.length > 0 && text.length < 5000) {
                texts.push(text);
            }
        }
        return texts.slice(0, 200);
    })();
    """

    /// Translates visible text on the page using simple JS text replacement.
    /// Falls back to Google Translate integration for broad language support.
    func translatePage(webView: WKWebView, targetLanguage: String = "en") {
        guard !isTranslating else { return }
        isTranslating = true

        // Use Google Translate's inline translation as a reliable approach
        let js = """
        (function() {
            if (document.getElementById('velgo-translate-bar')) return;
            var bar = document.createElement('div');
            bar.id = 'velgo-translate-bar';
            bar.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:999999;background:#4285f4;color:white;text-align:center;padding:8px;font-size:14px;font-family:-apple-system,sans-serif;';
            bar.textContent = 'Translating page…';
            document.body.prepend(bar);
            
            var s = document.createElement('script');
            s.src = 'https://translate.google.com/translate_a/element.js?cb=velgoTranslateInit';
            document.head.appendChild(s);
            
            window.velgoTranslateInit = function() {
                new google.translate.TranslateElement({
                    pageLanguage: 'auto',
                    includedLanguages: '\(targetLanguage)',
                    autoDisplay: true
                }, 'velgo-translate-bar');
                bar.textContent = 'Translated to \(targetLanguage.uppercased())';
                setTimeout(function() { bar.style.display = 'none'; }, 3000);
            };
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] _, error in
            Task { @MainActor in
                self?.isTranslating = false
                if error == nil {
                    self?.isTranslated = true
                } else {
                    os_log(.error, "Translation failed: %@", error?.localizedDescription ?? "unknown")
                }
            }
        }
    }

    /// Removes translation overlay and restores original page.
    func restoreOriginal(webView: WKWebView) {
        let js = """
        (function() {
            var bar = document.getElementById('velgo-translate-bar');
            if (bar) bar.remove();
            var frame = document.querySelector('.goog-te-banner-frame');
            if (frame) frame.remove();
            document.body.style.top = '0px';
            var cookies = document.cookie.split(';');
            for (var i = 0; i < cookies.length; i++) {
                if (cookies[i].includes('googtrans')) {
                    document.cookie = cookies[i].split('=')[0] + '=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/';
                }
            }
            location.reload();
        })();
        """
        webView.evaluateJavaScript(js) { _, _ in }
        isTranslated = false
    }

    /// Resets state when navigating to a new page.
    func reset() {
        isTranslated = false
        isTranslating = false
    }
}
