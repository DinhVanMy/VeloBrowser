// MediaPlayerService.swift
// VeloBrowser
//
// Service for extracting and playing media from web pages with background audio and PiP.

import AVFoundation
import AVKit
import os
import UIKit
import WebKit

/// Protocol for media playback operations.
@MainActor
protocol MediaPlayerServiceProtocol {
    /// Whether media is currently playing.
    var isPlaying: Bool { get }

    /// Title of the currently playing media.
    var currentTitle: String { get }

    /// URL of the currently playing media source.
    var currentMediaURL: URL? { get }

    /// Total duration of the media in seconds.
    var duration: TimeInterval { get }

    /// Current playback position in seconds.
    var currentTime: TimeInterval { get }

    /// The underlying AVPlayer instance.
    var player: AVPlayer? { get }

    /// Whether PiP is currently active.
    var isPiPActive: Bool { get }

    /// Whether PiP is supported on this device.
    var isPiPSupported: Bool { get }

    /// Extracts a media URL from the web view and begins playback.
    /// Returns `true` if media was found (extracted or already playing in-browser).
    @discardableResult
    func extractAndPlay(from webView: WKWebView, pageTitle: String, pageURL: URL?) async -> Bool

    /// Resumes playback.
    func play()

    /// Pauses playback.
    func pause()

    /// Toggles between play and pause.
    func togglePlayPause()

    /// Seeks to a specific time.
    func seek(to time: TimeInterval)

    /// Stops playback and clears the current media.
    func stop()

    /// Toggles PiP mode on or off.
    func togglePiP()
}

/// Manages media extraction from web pages and AVPlayer playback.
///
/// Extracts `<video>` and `<audio>` source URLs from WKWebView via
/// JavaScript injection, creates an AVPlayer for background-capable
/// playback, and coordinates with ``NowPlayingManager`` for lock screen controls.
@Observable
@MainActor
final class MediaPlayerService: MediaPlayerServiceProtocol {
    // MARK: - Published State

    /// Whether media is currently playing.
    private(set) var isPlaying: Bool = false

    /// Title of the currently playing media.
    private(set) var currentTitle: String = ""

    /// URL of the currently playing media source.
    private(set) var currentMediaURL: URL?

    /// URL of the web page the media was extracted from.
    private(set) var pageURL: URL?

    /// Total duration in seconds.
    private(set) var duration: TimeInterval = 0

    /// Current playback position in seconds.
    private(set) var currentTime: TimeInterval = 0

    /// The AVPlayer instance (exposed for PiP host view).
    private(set) var player: AVPlayer?

    /// Whether PiP is currently active.
    private(set) var isPiPActive: Bool = false

    /// Whether PiP is supported on this device.
    var isPiPSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    /// The PiP controller, set by ``PiPPlayerView`` when ready.
    weak var pipController: AVPictureInPictureController? {
        didSet {
            pipController?.delegate = pipDelegate
        }
    }

    // MARK: - Private

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var durationObservation: NSKeyValueObservation?
    private let nowPlayingManager: NowPlayingManagerProtocol
    private let pipDelegate = PiPDelegateHandler()
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "VeloBrowser", category: "MediaPlayer")

    /// Whether playback is in WebView mode (blob URLs that can't be extracted natively).
    private(set) var isWebViewMode: Bool = false

    /// Weak reference to the current WKWebView for controlling blob media.
    private weak var webViewReference: WKWebView?

    /// Silent audio player to keep the audio session alive in WebView mode.
    private var silentPlayer: AVQueuePlayer?

    /// Looper for the silent audio player.
    private var silentLooper: AVPlayerLooper?

    /// Background task identifier for smooth audio transitions.
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    /// Whether the keepalive has been stopped because AVPlayer is producing audio.
    private var keepaliveStoppedForPlayback: Bool = false

    /// Work item for delayed keepalive stop (allows cancellation if rate drops).
    private var keepaliveStopWorkItem: DispatchWorkItem?

    // MARK: - Init

    /// Creates a new MediaPlayerService.
    ///
    /// - Parameter nowPlayingManager: Manager for lock screen now playing info.
    init(nowPlayingManager: NowPlayingManagerProtocol) {
        self.nowPlayingManager = nowPlayingManager
        configureAudioSession()
        configurePiPDelegate()
        setupRemoteCommands()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        setupBackgroundNotification()

        // Clean up on app termination to prevent zombie audio
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }

        log.info("MediaPlayerService initialized")
    }

    // MARK: - Extraction & Playback

    /// Extracts a media URL from the given web view and starts playback.
    ///
    /// Uses a multi-method approach:
    /// 1. Direct `<video>`/`<audio>` source URLs (non-blob)
    /// 2. YouTube stream extraction from `ytInitialPlayerResponse`
    /// 3. Blob fallback with silent keepalive for background audio
    ///
    /// - Parameters:
    ///   - webView: The WKWebView to extract media from.
    ///   - pageTitle: Title to display in Now Playing info.
    ///   - pageURL: The web page URL (used as artist/source info).
    func extractAndPlay(from webView: WKWebView, pageTitle: String, pageURL: URL?) async -> Bool {
        log.info("extractAndPlay: starting for \(pageURL?.host() ?? "unknown", privacy: .public)")
        // Fully clean up any existing playback (fixes two-tab confusion)
        if player != nil || isWebViewMode {
            log.info("extractAndPlay: cleaning up previous playback")
            stop()
        }
        webViewReference = webView

        let js = """
        (function() {
            var videos = document.querySelectorAll('video');
            for (var i = 0; i < videos.length; i++) {
                var v = videos[i];
                var src = v.currentSrc || v.src;
                if (src && src.length > 0 && !src.startsWith('blob:')) {
                    return JSON.stringify({type:'direct', url:src});
                }
                var sources = v.querySelectorAll('source');
                for (var j = 0; j < sources.length; j++) {
                    var s = sources[j].src;
                    if (s && !s.startsWith('blob:')) return JSON.stringify({type:'direct', url:s});
                }
            }
            var audios = document.querySelectorAll('audio');
            for (var i = 0; i < audios.length; i++) {
                var a = audios[i];
                var src = a.currentSrc || a.src;
                if (src && src.length > 0 && !src.startsWith('blob:')) {
                    return JSON.stringify({type:'direct', url:src});
                }
            }
            if (window.location.hostname.indexOf('youtube') !== -1) {
                try {
                    var pr = null;
                    if (typeof ytInitialPlayerResponse !== 'undefined' && ytInitialPlayerResponse) {
                        pr = ytInitialPlayerResponse;
                    }
                    if (!pr) {
                        try {
                            var mp = document.querySelector('#movie_player');
                            if (mp && typeof mp.getPlayerResponse === 'function') {
                                pr = mp.getPlayerResponse();
                            }
                        } catch(e) {}
                    }
                    if (!pr) {
                        var scripts = document.querySelectorAll('script');
                        for (var i = 0; i < scripts.length; i++) {
                            var text = scripts[i].textContent;
                            if (!text || text.length < 100) continue;
                            var idx = text.indexOf('ytInitialPlayerResponse');
                            if (idx === -1) continue;
                            var start = text.indexOf('{', idx);
                            if (start === -1) continue;
                            var depth = 0, end = start;
                            for (var c = start; c < text.length && c < start + 500000; c++) {
                                if (text[c] === '{') depth++;
                                else if (text[c] === '}') { depth--; if (depth === 0) { end = c + 1; break; } }
                            }
                            if (depth === 0) {
                                try { pr = JSON.parse(text.substring(start, end)); } catch(e) {}
                                if (pr && pr.streamingData) break;
                                pr = null;
                            }
                        }
                    }
                    if (pr && pr.videoDetails) {
                        var urlParams = new URLSearchParams(window.location.search);
                        var currentVid = urlParams.get('v') || '';
                        if (currentVid && pr.videoDetails.videoId !== currentVid) {
                            pr = null;
                        }
                    }
                    if (pr && pr.streamingData) {
                        var sd = pr.streamingData;
                        var title = (pr.videoDetails && pr.videoDetails.title) || '';
                        // IMPORTANT: Audio-only adaptive format MUST come first.
                        // HLS manifests contain video tracks — AVPlayer auto-pauses
                        // video tracks on background. Audio-only streams keep playing.
                        if (sd.adaptiveFormats) {
                            var af = sd.adaptiveFormats.filter(function(f) {
                                return f.mimeType && f.mimeType.indexOf('audio/') === 0 && f.url;
                            });
                            if (af.length > 0) {
                                var mp4 = af.filter(function(f) { return f.mimeType.indexOf('audio/mp4') === 0; });
                                var best = mp4.length > 0 ? mp4 : af;
                                best.sort(function(a, b) { return (b.bitrate || 0) - (a.bitrate || 0); });
                                return JSON.stringify({type:'youtube', url:best[0].url, title:title, format:'audio'});
                            }
                        }
                        if (sd.hlsManifestUrl) {
                            return JSON.stringify({type:'youtube', url:sd.hlsManifestUrl, title:title, format:'hls'});
                        }
                        // NOTE: sd.formats (combined video+audio) deliberately skipped.
                        // Combined streams initialize video decoder which crashes with
                        // FigApplicationStateMonitor err=-19431 when app enters background.
                    }
                } catch(e) {}
            }
            for (var i = 0; i < videos.length; i++) {
                if (!videos[i].paused) return JSON.stringify({type:'blob_playing'});
            }
            for (var i = 0; i < audios.length; i++) {
                if (!audios[i].paused) return JSON.stringify({type:'blob_playing'});
            }
            var iframes = document.querySelectorAll('iframe[src*="embed"], iframe[src*="video"]');
            for (var i = 0; i < iframes.length; i++) {
                if (iframes[i].src) return JSON.stringify({type:'direct', url:iframes[i].src});
            }
            return null;
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(js)
            guard let jsonString = result as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = json["type"] as? String else {
                return false
            }

            switch type {
            case "direct", "youtube":
                guard let urlString = json["url"] as? String,
                      let url = URL(string: urlString) else { return false }
                let title = (json["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? pageTitle
                let format = (json["format"] as? String) ?? "direct"
                // Reject combined video+audio — crashes with err=-19431
                guard format != "combined" else {
                    log.warning("extractAndPlay: rejecting combined format (crashes in background)")
                    return false
                }
                log.info("extractAndPlay: found \(type, privacy: .public) [\(format, privacy: .public)] — \(title, privacy: .public)")
                // Pause web video to release video decoder before AVPlayer starts
                _ = try? await webView.evaluateJavaScript(
                    "(function(){var v=document.querySelector('video');if(v){v.pause();v.volume=0;}})()")
                try? await Task.sleep(for: .milliseconds(300))
                startPlayback(url: url, title: title, pageURL: pageURL)
                return true

            case "blob_playing":
                log.info("extractAndPlay: blob media detected, entering WebView mode")
                startWebViewMode(webView: webView, title: pageTitle, pageURL: pageURL)
                return true

            default:
                return false
            }
        } catch {
            return false
        }
    }

    // MARK: - Playback Controls

    /// Resumes playback.
    func play() {
        if isWebViewMode {
            webViewReference?.evaluateJavaScript(
                "(function(){var m=document.querySelector('video')||document.querySelector('audio');if(m){m.play();}})()",
                completionHandler: nil)
            isPlaying = true
            silentPlayer?.play()
        } else {
            player?.play()
        }
    }

    /// Pauses playback.
    func pause() {
        if isWebViewMode {
            webViewReference?.evaluateJavaScript(
                "(function(){var m=document.querySelector('video')||document.querySelector('audio');if(m){m.pause();}})()",
                completionHandler: nil)
            isPlaying = false
        } else {
            player?.pause()
        }
    }

    /// Toggles between play and pause states.
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Seeks to a specific time position.
    ///
    /// - Parameter time: The target time in seconds.
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlaying()
            }
        }
    }

    /// Stops playback and releases the player.
    func stop() {
        log.info("stop: cleaning up all playback")
        endBackgroundTaskIfNeeded()
        keepaliveStopWorkItem?.cancel()
        keepaliveStopWorkItem = nil
        keepaliveStoppedForPlayback = false

        // Resume web video when stopping native playback (we paused it on extraction)
        if player != nil {
            webViewReference?.evaluateJavaScript(
                "(function(){var v=document.querySelector('video');if(v){v.volume=1;v.play();}})()",
                completionHandler: nil)
        }

        removeObservers()
        player?.pause()
        player = nil
        stopWebViewMode()

        isPlaying = false
        currentMediaURL = nil
        currentTitle = ""
        pageURL = nil
        duration = 0
        currentTime = 0

        nowPlayingManager.clearNowPlaying()
    }

    // MARK: - PiP

    /// Toggles Picture-in-Picture mode.
    func togglePiP() {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
    }

    // MARK: - Private

    /// Starts playback of the given media URL.
    private func startPlayback(url: URL, title: String, pageURL: URL?) {
        log.info("startPlayback: \(title, privacy: .public)")
        // Start silent keepalive to protect audio session during AVPlayer buffering
        startSilentKeepAlive()

        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        // Prevent display sleep handling — we only need audio
        newPlayer.preventsDisplaySleepDuringVideoPlayback = false
        // Allow background audio even if item has video tracks (HLS fallback)
        if #available(iOS 16.0, *) {
            newPlayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
        self.player = newPlayer
        self.currentMediaURL = url
        self.currentTitle = title
        self.pageURL = pageURL

        setupObservers(for: newPlayer)
        newPlayer.play()
        // Immediately push Now Playing info so lock screen shows controls right away
        updateNowPlaying()
    }

    /// Configures the audio session for background playback.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Audio session configuration failed — playback may not work in background
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    /// Configures the PiP delegate callbacks.
    private func configurePiPDelegate() {
        pipDelegate.onStart = { [weak self] in
            Task { @MainActor in self?.isPiPActive = true }
        }
        pipDelegate.onStop = { [weak self] in
            Task { @MainActor in self?.isPiPActive = false }
        }
    }

    /// Sets up remote command handlers via the NowPlayingManager.
    private func setupRemoteCommands() {
        nowPlayingManager.setupRemoteCommands(
            onPlay: { [weak self] in
                Task { @MainActor in self?.play() }
            },
            onPause: { [weak self] in
                Task { @MainActor in self?.pause() }
            },
            onToggle: { [weak self] in
                Task { @MainActor in self?.togglePlayPause() }
            },
            onSeek: { [weak self] time in
                Task { @MainActor in self?.seek(to: time) }
            }
        )
    }

    /// Handles audio session interruptions (phone calls, Siri, etc.).
    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            log.info("Audio interruption began")
            player?.pause()
            silentPlayer?.pause()
        case .ended:
            log.info("Audio interruption ended")
            // Re-activate audio session after interruption
            try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            if let optionsValue {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    player?.play()
                    silentPlayer?.play()
                }
            }
        @unknown default:
            break
        }
    }

    /// Sets up KVO and time observers on the player.
    private func setupObservers(for player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                self.updateNowPlaying()
            }
        }

        rateObservation = player.observe(\.rate, options: .new) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                let playing = player.rate > 0
                self.isPlaying = playing

                if playing {
                    // Delay stopping keepalive to ensure AVPlayer audio is stable
                    self.keepaliveStopWorkItem?.cancel()
                    let workItem = DispatchWorkItem { [weak self] in
                        Task { @MainActor in
                            guard let self, self.player?.rate ?? 0 > 0 else { return }
                            self.log.info("AVPlayer stable — stopping silent keepalive")
                            self.stopSilentKeepAlive()
                            self.keepaliveStoppedForPlayback = true
                        }
                    }
                    self.keepaliveStopWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
                } else if self.keepaliveStoppedForPlayback && self.currentMediaURL != nil {
                    // Rate dropped to 0 (buffering/stall) — restart keepalive to prevent iOS kill
                    self.log.info("AVPlayer rate dropped to 0 — restarting keepalive")
                    self.keepaliveStopWorkItem?.cancel()
                    self.keepaliveStoppedForPlayback = false
                    self.startSilentKeepAlive()
                }
            }
        }

        if let item = player.currentItem {
            durationObservation = item.observe(\.duration, options: .new) { [weak self] item, _ in
                Task { @MainActor in
                    let dur = item.duration.seconds
                    self?.duration = dur.isFinite ? dur : 0
                }
            }

            statusObservation = item.observe(\.status, options: .new) { [weak self] item, _ in
                Task { @MainActor in
                    guard let self else { return }
                    switch item.status {
                    case .failed:
                        self.log.error("AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown", privacy: .public)")
                        self.stop()
                    case .readyToPlay:
                        self.log.info("AVPlayerItem ready to play")
                    default:
                        break
                    }
                }
            }
        }
    }

    /// Removes all KVO and time observers.
    private func removeObservers() {
        if let observer = timeObserver {
            // Guard: player may already be nil during stop() cleanup
            player?.removeTimeObserver(observer)
        }
        timeObserver = nil
        statusObservation?.invalidate()
        rateObservation?.invalidate()
        durationObservation?.invalidate()
        statusObservation = nil
        rateObservation = nil
        durationObservation = nil
    }

    /// Updates the now playing info on the lock screen.
    private func updateNowPlaying() {
        nowPlayingManager.update(
            title: currentTitle,
            artist: pageURL?.host() ?? "",
            duration: duration,
            currentTime: currentTime,
            rate: isPlaying ? 1.0 : 0.0
        )
    }

    /// Stores a reference to the active web view for auto-background detection.
    ///
    /// Called by BrowserView when the web view is created. Enables automatic
    /// background extraction when the app enters background while media is playing.
    func setActiveWebView(_ webView: WKWebView) {
        webViewReference = webView
    }

    // MARK: - WebView Mode (Blob Fallback)

    /// Starts WebView mode for blob media that can't be extracted natively.
    ///
    /// Sets up state and Now Playing info. The silent keepalive is NOT started
    /// here — it's deferred to `handleEnterBackground` to avoid conflicting
    /// with WKWebView's active video decoder (FigApplicationStateMonitor err=-19431).
    private func startWebViewMode(webView: WKWebView, title: String, pageURL: URL?) {
        stopWebViewMode()
        isWebViewMode = true
        webViewReference = webView
        currentTitle = title
        currentMediaURL = pageURL
        self.pageURL = pageURL
        isPlaying = true

        nowPlayingManager.update(
            title: title,
            artist: pageURL?.host() ?? "",
            duration: 0,
            currentTime: 0,
            rate: 1.0
        )
    }

    /// Stops WebView mode and cleans up the silent keepalive.
    /// Note: webViewReference is preserved for auto-background detection.
    private func stopWebViewMode() {
        isWebViewMode = false
        stopSilentKeepAlive()
    }

    /// Starts a silent audio player loop to keep the app's audio session alive in background.
    private func startSilentKeepAlive() {
        guard silentPlayer == nil else { return }
        guard let fileURL = createSilentAudioFile() else { return }

        let asset = AVAsset(url: fileURL)
        let templateItem = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.volume = 0.01

        silentLooper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)
        silentPlayer = queuePlayer
        queuePlayer.play()
    }

    /// Stops and releases the silent audio keepalive player.
    private func stopSilentKeepAlive() {
        silentLooper?.disableLooping()
        silentLooper = nil
        silentPlayer?.pause()
        silentPlayer = nil
    }

    /// Creates a short silent WAV audio file for the keepalive player.
    private func createSilentAudioFile() -> URL? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("velo_silence.wav")
        if FileManager.default.fileExists(atPath: fileURL.path) { return fileURL }

        let sampleRate: Double = 44100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100) else { return nil }
        buffer.frameLength = 44100

        do {
            let file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try file.write(from: buffer)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Background Handling

    /// Sets up notification observer for app entering background.
    private func setupBackgroundNotification() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleEnterBackground()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleEnterForeground()
            }
        }
    }

    /// Handles app entering background by maintaining the audio session for existing playback.
    private func handleEnterBackground() {
        log.info("handleEnterBackground: isPlaying=\(self.isPlaying), player=\(self.player != nil), webViewMode=\(self.isWebViewMode)")
        guard isPlaying || player != nil || isWebViewMode else { return }

        beginBackgroundTaskForTransition()
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        // Ensure keepalive is running for both AVPlayer buffering and WebView blob mode
        if silentPlayer == nil && (player != nil || isWebViewMode) {
            log.info("handleEnterBackground: starting keepalive")
            keepaliveStoppedForPlayback = false
            startSilentKeepAlive()
        }
    }

    /// Handles app returning to foreground — re-activate audio session and clean up keepalive.
    private func handleEnterForeground() {
        log.info("handleEnterForeground: isPlaying=\(self.isPlaying)")
        endBackgroundTaskIfNeeded()
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        // Stop keepalive in foreground for WebView mode — avoids conflict with WKWebView video
        if isWebViewMode && silentPlayer != nil {
            log.info("handleEnterForeground: stopping keepalive (WebView mode, no longer needed)")
            stopSilentKeepAlive()
        }
    }

    /// Begins a background task for smooth audio transitions.
    private func beginBackgroundTaskForTransition() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTaskIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.endBackgroundTaskIfNeeded()
        }
    }

    /// Ends the background task if one is active.
    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

// MARK: - PiP Delegate Handler

/// Delegate handler for AVPictureInPictureController events.
final class PiPDelegateHandler: NSObject, AVPictureInPictureControllerDelegate, @unchecked Sendable {
    /// Called when PiP starts.
    var onStart: (() -> Void)?

    /// Called when PiP stops.
    var onStop: (() -> Void)?

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        onStart?()
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        onStop?()
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
