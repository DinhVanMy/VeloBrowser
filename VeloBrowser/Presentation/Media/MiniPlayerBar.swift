// MiniPlayerBar.swift
// VeloBrowser
//
// Floating mini player bar shown when media is playing in background.

import SwiftUI

/// A compact bar showing the currently playing media with playback controls.
///
/// Displayed above the bottom toolbar when background audio is active.
/// Tapping the bar expands to the full ``NowPlayingView``.
struct MiniPlayerBar: View {
    @Bindable var mediaPlayer: MediaPlayerService
    var onExpand: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Media info (tappable area)
            Button(action: onExpand) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "music.note")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(width: 32, height: 32)
                        .background(DesignSystem.Colors.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mediaPlayer.currentTitle)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        if let host = mediaPlayer.pageURL?.host() {
                            Text(host)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                mediaPlayer.togglePlayPause()
            } label: {
                Image(systemName: mediaPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(
                        minWidth: DesignSystem.minimumTouchTarget,
                        minHeight: DesignSystem.minimumTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(mediaPlayer.isPlaying ? "Pause" : "Play")

            // Close
            Button {
                mediaPlayer.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.bold())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Stop playback")
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            DesignSystem.Colors.backgroundPrimary
                .shadow(.drop(color: .black.opacity(0.08), radius: 4, y: -1))
        )
    }
}
