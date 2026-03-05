// QRScannerView.swift
// VeloBrowser
//
// Camera-based QR code scanner that opens scanned URLs.

import SwiftUI
import AVFoundation

/// A SwiftUI view that scans QR codes and returns the detected URL.
struct QRScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onURLDetected: (URL) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRScannerView

        init(parent: QRScannerView) {
            self.parent = parent
        }

        func didDetectURL(_ url: URL) {
            parent.onURLDetected(url)
            parent.isPresented = false
        }

        func didFailWithError(_ error: Error) {
            parent.isPresented = false
        }
    }
}

/// Delegate for QR scanner events.
@MainActor
protocol QRScannerDelegate: AnyObject {
    func didDetectURL(_ url: URL)
    func didFailWithError(_ error: Error)
}

/// UIKit view controller for camera-based QR scanning.
final class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDetected = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showNoCameraLabel()
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417, .dataMatrix]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        // Scan guide overlay
        let guide = UIView()
        guide.layer.borderColor = UIColor.white.cgColor
        guide.layer.borderWidth = 2
        guide.layer.cornerRadius = 12
        guide.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guide)
        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guide.widthAnchor.constraint(equalToConstant: 250),
            guide.heightAnchor.constraint(equalToConstant: 250)
        ])

        let label = UILabel()
        label.text = "Point camera at QR code"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: guide.bottomAnchor, constant: 24)
        ])

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func showNoCameraLabel() {
        let label = UILabel()
        label.text = "Camera not available"
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let string = metadata.stringValue else { return }

        // Dispatch back to main for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.hasDetected else { return }
            self.hasDetected = true
            self.captureSession?.stopRunning()

            if let url = URL(string: string), url.scheme?.hasPrefix("http") == true {
                HapticManager.success()
                self.delegate?.didDetectURL(url)
            } else if let encoded = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)") {
                HapticManager.success()
                self.delegate?.didDetectURL(searchURL)
            } else {
                self.hasDetected = false
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession?.startRunning()
                }
            }
        }
    }
}
