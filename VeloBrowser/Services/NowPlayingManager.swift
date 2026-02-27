// NowPlayingManager.swift
// VeloBrowser
//
// Manages lock screen and Control Center now playing information.

import MediaPlayer
import UIKit

/// Protocol for now playing info management.
@MainActor
protocol NowPlayingManagerProtocol {
    /// Updates the now playing info displayed on lock screen and Control Center.
    ///
    /// - Parameters:
    ///   - title: The media title.
    ///   - artist: The artist or website name.
    ///   - duration: Total duration in seconds.
    ///   - currentTime: Current playback position in seconds.
    ///   - rate: Playback rate (0.0 = paused, 1.0 = playing).
    func update(title: String, artist: String, duration: TimeInterval, currentTime: TimeInterval, rate: Float)

    /// Clears all now playing info.
    func clearNowPlaying()

    /// Sets up remote command handlers for lock screen controls.
    ///
    /// - Parameters:
    ///   - onPlay: Called when the user taps play.
    ///   - onPause: Called when the user taps pause.
    ///   - onToggle: Called when the user taps toggle play/pause.
    ///   - onSeek: Called when the user seeks to a position (seconds).
    func setupRemoteCommands(
        onPlay: @escaping @Sendable () -> Void,
        onPause: @escaping @Sendable () -> Void,
        onToggle: @escaping @Sendable () -> Void,
        onSeek: @escaping @Sendable (TimeInterval) -> Void
    )
}

/// Manages MPNowPlayingInfoCenter and MPRemoteCommandCenter.
///
/// Provides lock screen controls (play/pause/seek) and displays
/// the currently playing media's title, artist (website name),
/// duration, and elapsed time.
@Observable
@MainActor
final class NowPlayingManager: NowPlayingManagerProtocol {

    // MARK: - Init

    /// Creates a new NowPlayingManager.
    init() {}

    // MARK: - Now Playing Info

    /// Updates the now playing information displayed on the lock screen.
    func update(
        title: String,
        artist: String,
        duration: TimeInterval,
        currentTime: TimeInterval,
        rate: Float
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: rate
        ]

        if let artworkImage = generatePlaceholderArtwork() {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clears all now playing information from lock screen and Control Center.
    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Remote Commands

    /// Configures the remote command center handlers for lock screen controls.
    func setupRemoteCommands(
        onPlay: @escaping @Sendable () -> Void,
        onPause: @escaping @Sendable () -> Void,
        onToggle: @escaping @Sendable () -> Void,
        onSeek: @escaping @Sendable (TimeInterval) -> Void
    ) {
        let center = MPRemoteCommandCenter.shared()

        // Clear existing targets
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            onPlay()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { _ in
            onToggle()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            onSeek(positionEvent.positionTime)
            return .success
        }

        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }

    // MARK: - Private

    /// Generates a placeholder artwork image using SF Symbols.
    private func generatePlaceholderArtwork() -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .regular)
            if let symbol = UIImage(systemName: "music.note", withConfiguration: config) {
                let imageSize = CGSize(width: 120, height: 120)
                let origin = CGPoint(
                    x: (size.width - imageSize.width) / 2,
                    y: (size.height - imageSize.height) / 2
                )
                symbol.withTintColor(.white, renderingMode: .alwaysOriginal)
                    .draw(in: CGRect(origin: origin, size: imageSize))
            }
        }
    }
}
