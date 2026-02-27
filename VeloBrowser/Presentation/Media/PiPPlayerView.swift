// PiPPlayerView.swift
// VeloBrowser
//
// UIViewRepresentable hosting an AVPlayerLayer for Picture-in-Picture support.

import AVFoundation
import AVKit
import SwiftUI

/// A hidden view that hosts an `AVPlayerLayer` required for PiP.
///
/// AVPictureInPictureController requires a player layer to be
/// in the view hierarchy. This view provides that layer and reports
/// the PiP controller back to the ``MediaPlayerService``.
struct PiPPlayerView: UIViewRepresentable {
    /// The AVPlayer to attach to the player layer.
    let player: AVPlayer?

    /// Called when the PiP controller is created and ready.
    var onPiPControllerReady: ((AVPictureInPictureController) -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coord = context.coordinator

        guard let player else {
            // No player — clean up
            coord.playerLayer?.removeFromSuperlayer()
            coord.playerLayer = nil
            coord.pipController = nil
            return
        }

        if let existingLayer = coord.playerLayer {
            // Update existing layer's player if changed
            if existingLayer.player !== player {
                existingLayer.player = player
            }
        } else {
            // Create new player layer
            let layer = AVPlayerLayer(player: player)
            layer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            uiView.layer.addSublayer(layer)
            coord.playerLayer = layer

            if AVPictureInPictureController.isPictureInPictureSupported() {
                if let pip = AVPictureInPictureController(playerLayer: layer) {
                    coord.pipController = pip
                    onPiPControllerReady?(pip)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Coordinator holding references to the player layer and PiP controller.
    final class Coordinator {
        var playerLayer: AVPlayerLayer?
        var pipController: AVPictureInPictureController?
    }
}
