// MediaPlayerService.swift
// VeloBrowser
//
// Service for extracting and playing media from web pages with background audio and PiP.

import AVFoundation
import AVKit
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

    // MARK: - Init

    /// Creates a new MediaPlayerService.
    ///
    /// - Parameter nowPlayingManager: Manager for lock screen now playing info.
    init(nowPlayingManager: NowPlayingManagerProtocol) {
        self.nowPlayingManager = nowPlayingManager
        configureAudioSession()
        configurePiPDelegate()
        setupRemoteCommands()
    }

    // MARK: - Extraction & Playback

    /// Extracts a media URL from the given web view and starts playback.
    ///
    /// Evaluates JavaScript to find `<video>`, `<audio>`, or `<source>` elements
    /// and extracts their `currentSrc` or `src` attribute.
    ///
    /// - Parameters:
    ///   - webView: The WKWebView to extract media from.
    ///   - pageTitle: Title to display in Now Playing info.
    ///   - pageURL: The web page URL (used as artist/source info).
    func extractAndPlay(from webView: WKWebView, pageTitle: String, pageURL: URL?) async -> Bool {
        let js = """
        (function() {
            // Search all video elements
            var videos = document.querySelectorAll('video');
            for (var i = 0; i < videos.length; i++) {
                var v = videos[i];
                var src = v.currentSrc || v.src;
                if (src && src.length > 0 && !src.startsWith('blob:')) return src;
                var sources = v.querySelectorAll('source');
                for (var j = 0; j < sources.length; j++) {
                    var s = sources[j].src;
                    if (s && !s.startsWith('blob:')) return s;
                }
            }
            // Search all audio elements
            var audios = document.querySelectorAll('audio');
            for (var i = 0; i < audios.length; i++) {
                var a = audios[i];
                var src = a.currentSrc || a.src;
                if (src && src.length > 0 && !src.startsWith('blob:')) return src;
                var sources = a.querySelectorAll('source');
                for (var j = 0; j < sources.length; j++) {
                    var s = sources[j].src;
                    if (s && !s.startsWith('blob:')) return s;
                }
            }
            // Check if any media is currently playing (blob or otherwise)
            for (var i = 0; i < videos.length; i++) {
                if (!videos[i].paused) return '__BLOB_PLAYING__';
            }
            for (var i = 0; i < audios.length; i++) {
                if (!audios[i].paused) return '__BLOB_PLAYING__';
            }
            // Fallback: look for embedded iframes with video sources
            var iframes = document.querySelectorAll('iframe[src*="embed"], iframe[src*="video"]');
            for (var i = 0; i < iframes.length; i++) {
                if (iframes[i].src) return iframes[i].src;
            }
            return null;
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(js)
            guard let urlString = result as? String else { return false }

            // If media is playing via blob URLs (e.g. YouTube), background audio
            // works directly through WKWebView — no extraction needed
            if urlString == "__BLOB_PLAYING__" {
                return true
            }

            guard let url = URL(string: urlString) else { return false }
            startPlayback(url: url, title: pageTitle, pageURL: pageURL)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Playback Controls

    /// Resumes playback.
    func play() {
        player?.play()
    }

    /// Pauses playback.
    func pause() {
        player?.pause()
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
        removeObservers()
        player?.pause()
        player = nil

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
        if player != nil {
            stop()
        }

        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer
        self.currentMediaURL = url
        self.currentTitle = title
        self.pageURL = pageURL

        setupObservers(for: newPlayer)
        newPlayer.play()
    }

    /// Configures the audio session for background playback.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
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
            // Pause playback when interrupted (phone call, Siri, etc.)
            player?.pause()
        case .ended:
            if let optionsValue {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    player?.play()
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
                self?.isPlaying = player.rate > 0
            }
        }

        if let item = player.currentItem {
            durationObservation = item.observe(\.duration, options: .new) { [weak self] item, _ in
                Task { @MainActor in
                    let dur = item.duration.seconds
                    self?.duration = dur.isFinite ? dur : 0
                }
            }
        }
    }

    /// Removes all KVO and time observers.
    private func removeObservers() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
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
