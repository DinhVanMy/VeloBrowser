// PageCaptureService.swift
// VeloBrowser
//
// Captures full-page screenshots and exports to PDF.

import UIKit
import WebKit
import os.log

/// Service for capturing full web pages as images or PDFs.
@MainActor
final class PageCaptureService {

    /// Captures a full-page screenshot of the web view.
    func captureFullPage(webView: WKWebView) async -> UIImage? {
        let config = WKSnapshotConfiguration()
        // Capture the full scrollable content
        let contentSize = await getContentSize(webView: webView)
        config.rect = CGRect(origin: .zero, size: contentSize)

        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: config) { image, error in
                if let error {
                    os_log(.error, "Full-page screenshot failed: %@", error.localizedDescription)
                }
                continuation.resume(returning: image)
            }
        }
    }

    /// Exports the web page as PDF data.
    func exportPDF(webView: WKWebView) async -> Data? {
        await withCheckedContinuation { continuation in
            webView.createPDF { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    os_log(.error, "PDF export failed: %@", error.localizedDescription)
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Prints the web page using system print dialog.
    func printPage(webView: WKWebView, from viewController: UIViewController? = nil) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = webView.title ?? "Web Page"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printFormatter = webView.viewPrintFormatter()
        printController.present(animated: true)
    }

    /// Saves image to Photos library.
    func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    /// Creates a share activity for PDF data.
    func sharePDF(_ data: Data, title: String) -> URL? {
        let fileName = sanitizeFileName(title) + ".pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            os_log(.error, "Failed to write PDF: %@", error.localizedDescription)
            return nil
        }
    }

    private func getContentSize(webView: WKWebView) async -> CGSize {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(
                "[document.body.scrollWidth, Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)]"
            ) { result, _ in
                if let dims = result as? [CGFloat], dims.count == 2 {
                    continuation.resume(returning: CGSize(width: dims[0], height: min(dims[1], 20000)))
                } else {
                    continuation.resume(returning: webView.scrollView.contentSize)
                }
            }
        }
    }

    private func sanitizeFileName(_ name: String) -> String {
        let sanitized = name.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
        let trimmed = String(sanitized.prefix(50))
        return trimmed.isEmpty ? "webpage" : trimmed
    }
}
