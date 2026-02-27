// FingerprintProtectionService.swift
// VeloBrowser
//
// Service for injecting anti-fingerprinting JavaScript into web pages.

import Foundation
import WebKit

/// Defines the contract for browser fingerprint protection.
///
/// Injects JavaScript that randomizes common fingerprinting vectors
/// (canvas, WebGL, navigator properties, screen dimensions, audio context).
@MainActor
protocol FingerprintProtectionServiceProtocol: Sendable {
    /// Whether fingerprint protection is enabled.
    var isEnabled: Bool { get set }

    /// Returns a `WKUserScript` for fingerprint protection injection.
    ///
    /// The script overrides common fingerprinting APIs with randomized/generic values.
    /// Should be injected at document start across all frames.
    func makeUserScript() -> WKUserScript?
}

/// Injects anti-fingerprinting JavaScript into WKWebView pages.
@Observable
@MainActor
final class FingerprintProtectionService: FingerprintProtectionServiceProtocol {
    /// Whether fingerprint protection is active.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "fingerprintProtection") }
        set { UserDefaults.standard.set(newValue, forKey: "fingerprintProtection") }
    }

    func makeUserScript() -> WKUserScript? {
        guard isEnabled else { return nil }
        return WKUserScript(
            source: Self.protectionJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    // MARK: - JavaScript

    /// JavaScript that overrides common fingerprinting APIs.
    private static let protectionJS: String = """
    (function() {
        'use strict';

        // Canvas fingerprint protection
        // Add subtle random noise to canvas data exports
        const origToDataURL = HTMLCanvasElement.prototype.toDataURL;
        HTMLCanvasElement.prototype.toDataURL = function(type, quality) {
            const ctx = this.getContext('2d');
            if (ctx) {
                const imageData = ctx.getImageData(0, 0, this.width, this.height);
                const data = imageData.data;
                // Add subtle noise to a few random pixels
                for (let i = 0; i < Math.min(10, data.length / 4); i++) {
                    const idx = Math.floor(Math.random() * (data.length / 4)) * 4;
                    data[idx] = data[idx] ^ 1;     // Red channel +/- 1
                }
                ctx.putImageData(imageData, 0, 0);
            }
            return origToDataURL.call(this, type, quality);
        };

        const origToBlob = HTMLCanvasElement.prototype.toBlob;
        HTMLCanvasElement.prototype.toBlob = function(callback, type, quality) {
            const ctx = this.getContext('2d');
            if (ctx) {
                const imageData = ctx.getImageData(0, 0, this.width, this.height);
                const data = imageData.data;
                for (let i = 0; i < Math.min(10, data.length / 4); i++) {
                    const idx = Math.floor(Math.random() * (data.length / 4)) * 4;
                    data[idx] = data[idx] ^ 1;
                }
                ctx.putImageData(imageData, 0, 0);
            }
            return origToBlob.call(this, callback, type, quality);
        };

        // WebGL fingerprint protection
        // Return generic renderer/vendor strings
        const origGetParameter = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(param) {
            // UNMASKED_VENDOR_WEBGL
            if (param === 0x9245) return 'Apple Inc.';
            // UNMASKED_RENDERER_WEBGL
            if (param === 0x9246) return 'Apple GPU';
            return origGetParameter.call(this, param);
        };

        if (typeof WebGL2RenderingContext !== 'undefined') {
            const origGetParam2 = WebGL2RenderingContext.prototype.getParameter;
            WebGL2RenderingContext.prototype.getParameter = function(param) {
                if (param === 0x9245) return 'Apple Inc.';
                if (param === 0x9246) return 'Apple GPU';
                return origGetParam2.call(this, param);
            };
        }

        // Navigator overrides
        // Return empty plugins
        Object.defineProperty(navigator, 'plugins', {
            get: function() { return []; },
            configurable: true
        });

        // Normalize hardware concurrency
        Object.defineProperty(navigator, 'hardwareConcurrency', {
            get: function() { return 4; },
            configurable: true
        });

        // Normalize device memory (if available)
        if ('deviceMemory' in navigator) {
            Object.defineProperty(navigator, 'deviceMemory', {
                get: function() { return 8; },
                configurable: true
            });
        }

        // Screen dimension normalization
        // Round to common resolutions to reduce uniqueness
        const commonWidth = Math.round(screen.width / 100) * 100;
        const commonHeight = Math.round(screen.height / 100) * 100;
        Object.defineProperty(screen, 'width', {
            get: function() { return commonWidth; },
            configurable: true
        });
        Object.defineProperty(screen, 'height', {
            get: function() { return commonHeight; },
            configurable: true
        });
        Object.defineProperty(screen, 'availWidth', {
            get: function() { return commonWidth; },
            configurable: true
        });
        Object.defineProperty(screen, 'availHeight', {
            get: function() { return commonHeight; },
            configurable: true
        });

        // Audio context fingerprint protection
        if (typeof AudioContext !== 'undefined') {
            const origGetChannelData = AudioBuffer.prototype.getChannelData;
            AudioBuffer.prototype.getChannelData = function(channel) {
                const data = origGetChannelData.call(this, channel);
                // Add imperceptible noise
                for (let i = 0; i < Math.min(5, data.length); i++) {
                    data[i] = data[i] + (Math.random() * 0.0000001);
                }
                return data;
            };
        }
    })();
    """
}
