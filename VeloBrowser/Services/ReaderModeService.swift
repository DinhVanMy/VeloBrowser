// ReaderModeService.swift
// VeloBrowser
//
// Service that extracts readable content from web pages using JavaScript.

import WebKit

// MARK: - Reader Content Model

/// Extracted readable content from a web page.
struct ReaderContent: Sendable {
    /// The article title.
    let title: String
    /// The author name, if detected.
    let author: String?
    /// The publication date, if detected.
    let publishedDate: String?
    /// The cleaned HTML content body.
    let htmlContent: String
    /// Estimated reading time in minutes.
    let estimatedReadingTime: Int
    /// Total word count of the content.
    let wordCount: Int
}

// MARK: - Protocol

/// Protocol for extracting readable content from web pages.
@MainActor
protocol ReaderModeServiceProtocol: AnyObject {
    /// Checks whether the current page has enough readable content.
    func isReadable(from webView: WKWebView) async -> Bool

    /// Extracts the main readable content from the page.
    func extractContent(from webView: WKWebView) async -> ReaderContent?
}

// MARK: - Implementation

/// Extracts article content from web pages via JavaScript injection.
///
/// Uses heuristics to find the main content area (`<article>`, `<main>`,
/// or the largest text block) and strips navigation, ads, and chrome.
@MainActor
final class ReaderModeService: ReaderModeServiceProtocol {

    /// Minimum word count to consider a page "readable".
    private let readabilityThreshold = 200

    // MARK: - Public API

    func isReadable(from webView: WKWebView) async -> Bool {
        do {
            let result = try await webView.evaluateJavaScript(Self.readabilityCheckJS)
            if let wordCount = result as? Int {
                return wordCount >= readabilityThreshold
            }
            return false
        } catch {
            return false
        }
    }

    func extractContent(from webView: WKWebView) async -> ReaderContent? {
        do {
            let result = try await webView.evaluateJavaScript(Self.extractionJS)
            guard let dict = result as? [String: Any],
                  let html = dict["html"] as? String,
                  !html.isEmpty else { return nil }

            let title = dict["title"] as? String ?? ""
            let author = dict["author"] as? String
            let date = dict["date"] as? String
            let wordCount = dict["wordCount"] as? Int ?? 0

            let readingTime = max(1, wordCount / 238) // avg 238 wpm

            return ReaderContent(
                title: title,
                author: author,
                publishedDate: date,
                htmlContent: html,
                estimatedReadingTime: readingTime,
                wordCount: wordCount
            )
        } catch {
            return nil
        }
    }

    // MARK: - JavaScript

    /// Quick check: counts words in the main content area.
    private static let readabilityCheckJS = """
    (function() {
        var el = document.querySelector('article') ||
                 document.querySelector('[role="main"]') ||
                 document.querySelector('main') ||
                 document.querySelector('.post-content, .article-body, .entry-content, .story-body');
        if (!el) {
            // Fallback: find the element with the most text
            var best = null, bestLen = 0;
            var candidates = document.querySelectorAll('div, section');
            for (var i = 0; i < candidates.length; i++) {
                var text = candidates[i].innerText || '';
                if (text.length > bestLen) { bestLen = text.length; best = candidates[i]; }
            }
            el = best;
        }
        if (!el) return 0;
        var words = (el.innerText || '').split(/\\s+/).filter(function(w) { return w.length > 0; });
        return words.length;
    })();
    """

    /// Full extraction: returns title, author, date, cleaned HTML, and word count.
    private static let extractionJS = """
    (function() {
        // --- Title ---
        var title = '';
        var ogTitle = document.querySelector('meta[property="og:title"]');
        if (ogTitle) title = ogTitle.getAttribute('content') || '';
        if (!title) {
            var h1 = document.querySelector('h1');
            if (h1) title = h1.innerText || '';
        }
        if (!title) title = document.title || '';

        // --- Author ---
        var author = null;
        var authorMeta = document.querySelector('meta[name="author"]') ||
                         document.querySelector('meta[property="article:author"]');
        if (authorMeta) author = authorMeta.getAttribute('content') || null;
        if (!author) {
            var authorEl = document.querySelector('.author, [rel="author"], .byline, .post-author');
            if (authorEl) author = (authorEl.innerText || '').trim() || null;
        }

        // --- Date ---
        var date = null;
        var dateMeta = document.querySelector('meta[property="article:published_time"]') ||
                       document.querySelector('meta[name="date"]') ||
                       document.querySelector('time[datetime]');
        if (dateMeta) {
            date = dateMeta.getAttribute('content') || dateMeta.getAttribute('datetime') || null;
        }

        // --- Main content ---
        var el = document.querySelector('article') ||
                 document.querySelector('[role="main"]') ||
                 document.querySelector('main') ||
                 document.querySelector('.post-content, .article-body, .entry-content, .story-body');

        if (!el) {
            var best = null, bestLen = 0;
            var candidates = document.querySelectorAll('div, section');
            for (var i = 0; i < candidates.length; i++) {
                var text = candidates[i].innerText || '';
                if (text.length > bestLen) { bestLen = text.length; best = candidates[i]; }
            }
            el = best;
        }
        if (!el) return { title: title, author: author, date: date, html: '', wordCount: 0 };

        // Clone to avoid modifying the page
        var clone = el.cloneNode(true);

        // Remove unwanted elements
        var remove = ['script', 'style', 'iframe', 'nav', 'footer', 'header',
                       'aside', 'form', 'button', '.ad', '.ads', '.social-share',
                       '.share-buttons', '.related-posts', '.comments', '.sidebar',
                       '[role="navigation"]', '[role="complementary"]', '.newsletter',
                       '.popup', '.modal', '.cookie-banner', 'svg'];
        remove.forEach(function(sel) {
            var els = clone.querySelectorAll(sel);
            els.forEach(function(e) { e.remove(); });
        });

        // Strip inline styles and class attributes
        var all = clone.querySelectorAll('*');
        for (var i = 0; i < all.length; i++) {
            all[i].removeAttribute('style');
            all[i].removeAttribute('class');
            all[i].removeAttribute('id');
            all[i].removeAttribute('onclick');
            all[i].removeAttribute('onload');
        }

        // Remove empty elements (but keep img, br, hr)
        var allAgain = clone.querySelectorAll('*');
        for (var i = allAgain.length - 1; i >= 0; i--) {
            var e = allAgain[i];
            var tag = e.tagName.toLowerCase();
            if (tag === 'img' || tag === 'br' || tag === 'hr' || tag === 'video') continue;
            if (e.children.length === 0 && (e.innerText || '').trim() === '') {
                e.remove();
            }
        }

        var html = clone.innerHTML || '';
        var text = clone.innerText || '';
        var words = text.split(/\\s+/).filter(function(w) { return w.length > 0; });

        return {
            title: title.trim(),
            author: author ? author.trim() : null,
            date: date,
            html: html,
            wordCount: words.length
        };
    })();
    """
}
