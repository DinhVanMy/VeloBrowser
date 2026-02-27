// PlatformLogos.swift
// VeloBrowser
//
// Authentic platform logos rendered as SwiftUI views for quick-access cards.

import SwiftUI

// MARK: - YouTube Logo

/// YouTube play-button logo.
struct YouTubeLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(Color.red)
                .frame(width: size * 0.9, height: size * 0.64)

            Path { path in
                let cx = size / 2
                let cy = size / 2
                let s = size * 0.18
                path.move(to: CGPoint(x: cx - s * 0.6, y: cy - s))
                path.addLine(to: CGPoint(x: cx + s, y: cy))
                path.addLine(to: CGPoint(x: cx - s * 0.6, y: cy + s))
                path.closeSubpath()
            }
            .fill(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Facebook Logo

/// Facebook circle "f" logo.
struct FacebookLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.09, green: 0.47, blue: 0.95))

            // Simplified "f"
            Text("f")
                .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(x: size * 0.02, y: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - TikTok Logo

/// TikTok logo with characteristic color split effect.
struct TikTokLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(.black)

            ZStack {
                // Cyan shadow
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(Color(red: 0.15, green: 0.96, blue: 0.93))
                    .offset(x: -1.5, y: 1.5)

                // Pink shadow
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.17, blue: 0.33))
                    .offset(x: 1.5, y: -1.5)

                // White front
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Twitter/X Logo

/// X (formerly Twitter) logo.
struct TwitterXLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.black)

            // X shape
            Path { path in
                let s = size * 0.7
                let o = size * 0.15
                let scale = s / 24.0

                path.move(to: CGPoint(x: 18.901 * scale + o, y: 1.153 * scale + o))
                path.addLine(to: CGPoint(x: 22.581 * scale + o, y: 1.153 * scale + o))
                path.addLine(to: CGPoint(x: 14.541 * scale + o, y: 10.343 * scale + o))
                path.addLine(to: CGPoint(x: 24 * scale + o, y: 22.846 * scale + o))
                path.addLine(to: CGPoint(x: 16.594 * scale + o, y: 22.846 * scale + o))
                path.addLine(to: CGPoint(x: 10.794 * scale + o, y: 15.262 * scale + o))
                path.addLine(to: CGPoint(x: 4.156 * scale + o, y: 22.846 * scale + o))
                path.addLine(to: CGPoint(x: 0.474 * scale + o, y: 22.846 * scale + o))
                path.addLine(to: CGPoint(x: 9.074 * scale + o, y: 13.016 * scale + o))
                path.addLine(to: CGPoint(x: 0 + o, y: 1.154 * scale + o))
                path.addLine(to: CGPoint(x: 7.594 * scale + o, y: 1.154 * scale + o))
                path.addLine(to: CGPoint(x: 12.837 * scale + o, y: 8.086 * scale + o))
                path.closeSubpath()

                path.move(to: CGPoint(x: 17.61 * scale + o, y: 20.644 * scale + o))
                path.addLine(to: CGPoint(x: 19.649 * scale + o, y: 20.644 * scale + o))
                path.addLine(to: CGPoint(x: 6.486 * scale + o, y: 3.24 * scale + o))
                path.addLine(to: CGPoint(x: 4.298 * scale + o, y: 3.24 * scale + o))
                path.closeSubpath()
            }
            .fill(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Instagram Logo

/// Instagram camera logo with gradient background.
struct InstagramLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.23, blue: 0.79),
                            Color(red: 0.84, green: 0.18, blue: 0.42),
                            Color(red: 0.99, green: 0.55, blue: 0.15)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.14)
                .stroke(.white, lineWidth: size * 0.055)
                .frame(width: size * 0.58, height: size * 0.58)

            Circle()
                .stroke(.white, lineWidth: size * 0.05)
                .frame(width: size * 0.28, height: size * 0.28)

            Circle()
                .fill(.white)
                .frame(width: size * 0.065, height: size * 0.065)
                .offset(x: size * 0.17, y: -size * 0.17)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Reddit Logo

/// Reddit Snoo logo (simplified).
struct RedditLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.27, blue: 0.0))

            VStack(spacing: 0) {
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.07, height: size * 0.07)
                    .offset(x: size * 0.06, y: size * 0.02)

                ZStack {
                    Ellipse()
                        .fill(.white)
                        .frame(width: size * 0.55, height: size * 0.4)

                    HStack(spacing: size * 0.11) {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.27, blue: 0.0))
                            .frame(width: size * 0.08, height: size * 0.08)
                        Circle()
                            .fill(Color(red: 1.0, green: 0.27, blue: 0.0))
                            .frame(width: size * 0.08, height: size * 0.08)
                    }
                    .offset(y: -size * 0.02)
                }
            }
            .offset(y: size * 0.06)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Wikipedia Logo

/// Wikipedia "W" logo.
struct WikipediaLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.92))

            Text("W")
                .font(.system(size: size * 0.42, weight: .bold, design: .serif))
                .foregroundStyle(.black)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Gmail Logo

/// Gmail envelope "M" logo.
struct GmailLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(Color(white: 0.95))

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.06)
                    .fill(.white)
                    .frame(width: size * 0.78, height: size * 0.56)

                RoundedRectangle(cornerRadius: size * 0.06)
                    .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: size * 0.035)
                    .frame(width: size * 0.78, height: size * 0.56)

                Path { path in
                    let w = size * 0.78
                    let h = size * 0.56
                    let ox = (size - w) / 2
                    let oy = (size - h) / 2
                    path.move(to: CGPoint(x: ox + size * 0.015, y: oy + size * 0.015))
                    path.addLine(to: CGPoint(x: size / 2, y: oy + h * 0.52))
                    path.addLine(to: CGPoint(x: ox + w - size * 0.015, y: oy + size * 0.015))
                }
                .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: size * 0.035)
            }
        }
        .frame(width: size, height: size)
    }
}
