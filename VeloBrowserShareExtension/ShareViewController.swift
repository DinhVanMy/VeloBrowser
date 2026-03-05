// ShareViewController.swift
// VeloBrowserShareExtension
//
// Receives shared URLs/text from other apps and opens them in VelGo.

import UIKit
import UniformTypeIdentifiers

/// Share extension that opens shared URLs in VelGo browser.
/// Uses a custom URL scheme (velgo://) to pass the URL to the main app.
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            complete()
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                        if let url = item as? URL {
                            self?.openInVelGo(url)
                        } else {
                            self?.complete()
                        }
                    }
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                        if let text = item as? String, let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                            self?.openInVelGo(url)
                        } else if let text = item as? String {
                            // Treat as search query
                            let query = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
                            if let searchURL = URL(string: "velgo://search?q=\(query)") {
                                self?.openURL(searchURL)
                            }
                            self?.complete()
                        } else {
                            self?.complete()
                        }
                    }
                    return
                }
            }
        }
        complete()
    }

    private func openInVelGo(_ url: URL) {
        // Encode the shared URL into VelGo's custom URL scheme
        guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let velgoURL = URL(string: "velgo://open?url=\(encoded)") else {
            complete()
            return
        }
        openURL(velgoURL)
        complete()
    }

    private func openURL(_ url: URL) {
        // Use responder chain to open URL from extension
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = r.next
        }
        // Fallback: use selector-based approach for extensions
        let selector = sel_registerName("openURL:")
        var nextResponder = self.next
        while let r = nextResponder {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                return
            }
            nextResponder = r.next
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
