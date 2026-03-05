// VeloLogoView.swift
// VeloBrowser
//
// Branded Velo logo using the actual app icon asset.

import SwiftUI

/// The Velo brand logo — displays the app icon image asset.
///
/// Falls back to a gradient circle with "V" if the image asset is unavailable.
struct VeloLogoView: View {
    /// The size of the logo.
    let size: CGFloat

    var body: some View {
        Image("VeloBrand")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}
