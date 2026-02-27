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
            // Gradient background circle — matches AppIcon gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 28/255, green: 51/255, blue: 117/255),
                            Color(red: 51/255, green: 107/255, blue: 217/255),
                            Color(red: 77/255, green: 153/255, blue: 242/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Stylized "V" shape
            VeloVShape()
                .fill(.white)
                .frame(width: size * 0.5, height: size * 0.56)
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

        // Stylized V matching the app icon proportions
        path.move(to: CGPoint(x: w * 0.0, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.857))
        path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 1.0, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 1.0))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 1.0))
        path.closeSubpath()
        return path
    }
}
