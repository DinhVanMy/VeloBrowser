// NowPlayingView.swift
// VeloBrowser
//
// Full-screen now playing view with artwork, progress, and controls.

import SwiftUI

/// Full now playing view with artwork, progress slider, and playback controls.
///
/// Presented as a sheet when the user taps the mini player bar.
/// Shows media title, source website, progress, and provides
/// play/pause, seek, PiP toggle, and skip controls.
struct NowPlayingView: View {
    @Bindable var mediaPlayer: MediaPlayerService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Drag indicator
            Capsule()
                .fill(DesignSystem.Colors.textTertiary)
                .frame(width: 36, height: 5)
                .padding(.top, DesignSystem.Spacing.sm)

            Spacer()

            // Artwork
            artworkView

            // Title & Source
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(mediaPlayer.currentTitle)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let host = mediaPlayer.pageURL?.host() {
                    Text(host)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // Progress
            progressView
                .padding(.horizontal, DesignSystem.Spacing.lg)

            // Controls
            controlsView

            // PiP button
            if mediaPlayer.isPiPSupported {
                pipButton
            }

            Spacer()
        }
        .background(DesignSystem.Colors.backgroundPrimary)
    }

    // MARK: - Artwork

    private var artworkView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.container)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.accent.opacity(0.3),
                            DesignSystem.Colors.accent.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.accent)
        }
        .frame(width: 280, height: 280)
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Slider(
                value: Binding(
                    get: { mediaPlayer.currentTime },
                    set: { mediaPlayer.seek(to: $0) }
                ),
                in: 0...max(mediaPlayer.duration, 1)
            )
            .tint(DesignSystem.Colors.accent)

            HStack {
                Text(formatTime(mediaPlayer.currentTime))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                Text("-\(formatTime(max(0, mediaPlayer.duration - mediaPlayer.currentTime)))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            // Rewind 15s
            Button {
                mediaPlayer.seek(to: max(0, mediaPlayer.currentTime - 15))
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(
                        minWidth: DesignSystem.minimumTouchTarget,
                        minHeight: DesignSystem.minimumTouchTarget
                    )
            }
            .accessibilityLabel("Rewind 15 seconds")

            // Play/Pause
            Button {
                mediaPlayer.togglePlayPause()
            } label: {
                Image(systemName: mediaPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .accessibilityLabel(mediaPlayer.isPlaying ? "Pause" : "Play")

            // Forward 15s
            Button {
                mediaPlayer.seek(to: min(mediaPlayer.duration, mediaPlayer.currentTime + 15))
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(
                        minWidth: DesignSystem.minimumTouchTarget,
                        minHeight: DesignSystem.minimumTouchTarget
                    )
            }
            .accessibilityLabel("Forward 15 seconds")
        }
    }

    // MARK: - PiP

    private var pipButton: some View {
        Button {
            mediaPlayer.togglePiP()
        } label: {
            Label(
                mediaPlayer.isPiPActive ? "Exit PiP" : "Picture in Picture",
                systemImage: mediaPlayer.isPiPActive ? "pip.exit" : "pip.enter"
            )
            .font(DesignSystem.Typography.subheadline)
            .foregroundStyle(DesignSystem.Colors.accent)
        }
        .accessibilityLabel(mediaPlayer.isPiPActive ? "Exit Picture in Picture" : "Enter Picture in Picture")
    }

    // MARK: - Helpers

    /// Formats seconds into MM:SS string.
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
