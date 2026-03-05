// DoHService.swift
// VeloBrowser
//
// DNS-over-HTTPS resolver using Cloudflare, Google, or NextDNS.

import Foundation
import os.log

/// Available DoH providers.
enum DoHProvider: String, CaseIterable, Identifiable {
    case disabled = "Disabled"
    case cloudflare = "Cloudflare (1.1.1.1)"
    case google = "Google (8.8.8.8)"
    case quad9 = "Quad9 (9.9.9.9)"

    var id: String { rawValue }

    var endpoint: URL? {
        switch self {
        case .disabled: return nil
        case .cloudflare: return URL(string: "https://cloudflare-dns.com/dns-query")
        case .google: return URL(string: "https://dns.google/dns-query")
        case .quad9: return URL(string: "https://dns.quad9.net:5053/dns-query")
        }
    }
}

/// DNS-over-HTTPS resolution result.
struct DoHResult {
    let domain: String
    let addresses: [String]
    let ttl: TimeInterval
    let resolvedAt: Date
}

/// Service providing DNS-over-HTTPS resolution.
@Observable
@MainActor
final class DoHService {
    /// Currently selected DoH provider.
    var provider: DoHProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: "dohProvider") ?? "Disabled"
            return DoHProvider(rawValue: raw) ?? .disabled
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "dohProvider")
        }
    }

    /// Number of DNS queries resolved via DoH.
    private(set) var totalResolved: Int = 0

    /// Simple DNS cache.
    private var cache: [String: DoHResult] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes

    /// Resolves a domain using DoH. Returns IP addresses or nil if disabled/failed.
    func resolve(_ domain: String) async -> [String]? {
        guard provider != .disabled, let endpoint = provider.endpoint else { return nil }

        // Check cache
        if let cached = cache[domain],
           Date().timeIntervalSince(cached.resolvedAt) < cached.ttl {
            return cached.addresses
        }

        // Build DNS wire format query
        guard let queryData = buildDNSQuery(for: domain) else { return nil }

        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.httpBody = queryData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let addresses = parseDNSResponse(data)
            if !addresses.isEmpty {
                let result = DoHResult(domain: domain, addresses: addresses, ttl: cacheTTL, resolvedAt: Date())
                cache[domain] = result
                totalResolved += 1
            }
            return addresses.isEmpty ? nil : addresses
        } catch {
            os_log(.error, "DoH resolution failed for %@: %@", domain, error.localizedDescription)
            return nil
        }
    }

    /// Clears the DNS cache.
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - DNS Wire Format

    /// Builds a minimal DNS query in wire format for A records.
    private func buildDNSQuery(for domain: String) -> Data? {
        var data = Data()
        // Header: ID=0, QR=0, OPCODE=0, RD=1
        data.append(contentsOf: [0x00, 0x00]) // ID
        data.append(contentsOf: [0x01, 0x00]) // Flags: RD=1
        data.append(contentsOf: [0x00, 0x01]) // QDCOUNT=1
        data.append(contentsOf: [0x00, 0x00]) // ANCOUNT=0
        data.append(contentsOf: [0x00, 0x00]) // NSCOUNT=0
        data.append(contentsOf: [0x00, 0x00]) // ARCOUNT=0

        // Question: domain name
        for label in domain.split(separator: ".") {
            guard label.count < 64 else { return nil }
            data.append(UInt8(label.count))
            data.append(contentsOf: label.utf8)
        }
        data.append(0x00) // Root label

        data.append(contentsOf: [0x00, 0x01]) // QTYPE=A
        data.append(contentsOf: [0x00, 0x01]) // QCLASS=IN

        return data
    }

    /// Parses a DNS wire format response, extracting A record addresses.
    private func parseDNSResponse(_ data: Data) -> [String] {
        guard data.count > 12 else { return [] }
        var addresses: [String] = []

        let ancount = (Int(data[6]) << 8) | Int(data[7])
        guard ancount > 0 else { return [] }

        // Skip header (12 bytes) + question section
        var offset = 12
        // Skip question name
        while offset < data.count {
            let len = Int(data[offset])
            if len == 0 { offset += 1; break }
            if len >= 0xC0 { offset += 2; break } // Pointer
            offset += 1 + len
        }
        offset += 4 // QTYPE + QCLASS

        // Parse answers
        for _ in 0..<ancount {
            guard offset + 12 <= data.count else { break }

            // Skip name (may be pointer)
            if data[offset] & 0xC0 == 0xC0 {
                offset += 2
            } else {
                while offset < data.count && data[offset] != 0 {
                    offset += 1 + Int(data[offset])
                }
                offset += 1
            }

            guard offset + 10 <= data.count else { break }

            let rtype = (Int(data[offset]) << 8) | Int(data[offset + 1])
            let rdlength = (Int(data[offset + 8]) << 8) | Int(data[offset + 9])
            offset += 10

            if rtype == 1 && rdlength == 4 && offset + 4 <= data.count {
                // A record
                let ip = "\(data[offset]).\(data[offset+1]).\(data[offset+2]).\(data[offset+3])"
                addresses.append(ip)
            }

            offset += rdlength
        }

        return addresses
    }
}
