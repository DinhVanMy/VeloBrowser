// Logger.swift
// VeloBrowser
//
// Centralized logging utility using os.log with predefined subsystem and categories.

import os.log

/// Centralized logger with categories for different app services.
enum AppLogger {
    /// Logger for browser navigation, page loads, and rendering.
    static let browser = Logger(subsystem: "com.velobrowser.app", category: "browser")
    
    /// Logger for media playback and video/audio handling.
    static let media = Logger(subsystem: "com.velobrowser.app", category: "media")
    
    /// Logger for tab management and lifecycle.
    static let tabs = Logger(subsystem: "com.velobrowser.app", category: "tabs")
    
    /// Logger for ad blocking operations and rule compilation.
    static let adblock = Logger(subsystem: "com.velobrowser.app", category: "adblock")
    
    /// Logger for download management and file operations.
    static let downloads = Logger(subsystem: "com.velobrowser.app", category: "downloads")
    
    /// Logger for network requests, responses, and connectivity.
    static let network = Logger(subsystem: "com.velobrowser.app", category: "network")
    
    /// Logger for privacy features, tracking protection, and fingerprint protection.
    static let privacy = Logger(subsystem: "com.velobrowser.app", category: "privacy")
}
