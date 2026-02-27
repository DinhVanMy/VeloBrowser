// ShareSheet.swift
// VeloBrowser
//
// UIActivityViewController wrapper for SwiftUI sharing.

import SwiftUI

/// A SwiftUI wrapper around `UIActivityViewController` for sharing content.
///
/// Presents the standard iOS share sheet with the provided items.
struct ShareSheet: UIViewControllerRepresentable {
    /// The items to share (URLs, strings, images, etc.).
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
