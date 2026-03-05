// VideoDetectorService.swift
// VeloBrowser
//
// Detects video/audio elements on web pages and provides download capabilities.

import Foundation
import WebKit
import os.log

/// Detected media item on a web page.
struct DetectedMedia: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let type: MediaType
    let title: String?
    let duration: TimeInterval?
    let quality: String?

    enum MediaType: String {
        case video
        case audio
        case hls
    }

    static func == (lhs: DetectedMedia, rhs: DetectedMedia) -> Bool {
        lhs.url == rhs.url
    }
}

/// Service that detects downloadable media on web pages.
@Observable
@MainActor
final class VideoDetectorService {
    /// Currently detected media on the active page.
    private(set) var detectedMedia: [DetectedMedia] = []

    /// Whether a scan is in progress.
    private(set) var isScanning: Bool = false

    /// JavaScript to extract video/audio sources from the page.
    static let mediaDetectionJS = """
    (function() {
        var media = [];
        
        // Direct <video> and <audio> elements
        document.querySelectorAll('video, audio').forEach(function(el) {
            // Element src
            if (el.src && el.src.startsWith('http')) {
                media.push({
                    url: el.src,
                    type: el.tagName.toLowerCase(),
                    duration: isNaN(el.duration) ? null : el.duration
                });
            }
            // <source> children
            el.querySelectorAll('source').forEach(function(src) {
                if (src.src && src.src.startsWith('http')) {
                    var t = el.tagName.toLowerCase();
                    if (src.type && src.type.includes('mpegurl')) t = 'hls';
                    media.push({
                        url: src.src,
                        type: t,
                        duration: isNaN(el.duration) ? null : el.duration
                    });
                }
            });
        });

        // <video> with blob: src — skip (can't download blobs directly)
        
        // HLS playlists in page source (m3u8 links)
        var pageHTML = document.documentElement.outerHTML;
        var m3u8Regex = /https?:\\/\\/[^"'\\s]+\\.m3u8[^"'\\s]*/g;
        var m3u8Matches = pageHTML.match(m3u8Regex) || [];
        m3u8Matches.forEach(function(url) {
            if (!media.some(function(m) { return m.url === url; })) {
                media.push({ url: url, type: 'hls', duration: null });
            }
        });

        // Direct video file links (mp4, webm, mov)
        var videoRegex = /https?:\\/\\/[^"'\\s]+\\.(mp4|webm|mov|avi|mkv)(\\?[^"'\\s]*)?/gi;
        var videoMatches = pageHTML.match(videoRegex) || [];
        videoMatches.forEach(function(url) {
            if (!media.some(function(m) { return m.url === url; })) {
                media.push({ url: url, type: 'video', duration: null });
            }
        });

        // Direct audio file links (mp3, m4a, aac, ogg, wav)
        var audioRegex = /https?:\\/\\/[^"'\\s]+\\.(mp3|m4a|aac|ogg|wav|flac)(\\?[^"'\\s]*)?/gi;
        var audioMatches = pageHTML.match(audioRegex) || [];
        audioMatches.forEach(function(url) {
            if (!media.some(function(m) { return m.url === url; })) {
                media.push({ url: url, type: 'audio', duration: null });
            }
        });

        // Deduplicate by URL
        var seen = {};
        return media.filter(function(m) {
            if (seen[m.url]) return false;
            seen[m.url] = true;
            return true;
        });
    })();
    """

    /// Scans the given WKWebView for downloadable media.
    func scanForMedia(in webView: WKWebView) {
        isScanning = true
        webView.evaluateJavaScript(Self.mediaDetectionJS) { [weak self] result, error in
            Task { @MainActor in
                defer { self?.isScanning = false }
                guard let self, let items = result as? [[String: Any]] else { return }

                self.detectedMedia = items.compactMap { item in
                    guard let urlString = item["url"] as? String,
                          let url = URL(string: urlString),
                          let typeString = item["type"] as? String,
                          let type = DetectedMedia.MediaType(rawValue: typeString) else {
                        return nil
                    }
                    let duration = item["duration"] as? TimeInterval
                    let quality = self.inferQuality(from: urlString)
                    let title = webView.title
                    return DetectedMedia(url: url, type: type, title: title, duration: duration, quality: quality)
                }
            }
        }
    }

    /// Clears detected media.
    func clear() {
        detectedMedia.removeAll()
    }

    /// Infers video quality from URL patterns.
    private func inferQuality(from urlString: String) -> String? {
        let lowered = urlString.lowercased()
        if lowered.contains("1080") { return "1080p" }
        if lowered.contains("720") { return "720p" }
        if lowered.contains("480") { return "480p" }
        if lowered.contains("360") { return "360p" }
        if lowered.contains("hd") { return "HD" }
        if lowered.contains("sd") { return "SD" }
        return nil
    }
}
