// VeloLogoView.swift
// VeloBrowser
//
// Branded Velo logo rendered as a SwiftUI view with gradient background.

import SwiftUI

/// The Velo Browser brand logo — a stylized "V" inside a gradient circle.
struct VeloLogoView: View {
    /// The size of the logo.
    let size: CGFloat

    var body: some View {
        ZStack {
            // Gradient background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.20, blue: 0.46),
                            Color(red: 0.20, green: 0.42, blue: 0.85),
                            Color(red: 0.30, green: 0.60, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Stylized "V" shape
            VeloVShape()
                .fill(.white)
                .frame(width: size * 0.5, height: size * 0.45)
                .offset(y: -size * 0.01)

            // Small speed accent lines
            VStack(spacing: size * 0.04) {
                RoundedRectangle(cornerRadius: size * 0.01)
                    .fill(.white.opacity(0.5))
                    .frame(width: size * 0.12, height: size * 0.02)
                RoundedRectangle(cornerRadius: size * 0.01)
                    .fill(.white.opacity(0.35))
                    .frame(width: size * 0.08, height: size * 0.02)
            }
            .offset(x: -size * 0.28, y: -size * 0.05)
        }
        .frame(width: size, height: size)
    }
}

/// The "V" letterform shape for the Velo logo.
private struct VeloVShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Stylized V with slightly rounded edges
        path.move(to: CGPoint(x: w * 0.0, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 1.0, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 1.0))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 1.0))
        path.closeSubpath()
        return path
    }
}
