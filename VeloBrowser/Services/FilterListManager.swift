// FilterListManager.swift
// VeloBrowser
//
// Manages custom ad block filter lists imported via URL.

import Foundation
import os.log

/// A user-added filter list subscription.
struct FilterList: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var url: URL
    var isEnabled: Bool
    var ruleCount: Int
    var lastUpdated: Date?

    init(name: String, url: URL) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isEnabled = true
        self.ruleCount = 0
        self.lastUpdated = nil
    }
}

/// Manages custom filter list subscriptions.
@Observable
@MainActor
final class FilterListManager {
    private(set) var lists: [FilterList] = []
    private(set) var isUpdating: Bool = false

    /// Well-known filter lists users can add with one tap.
    static let popularLists: [(name: String, url: String)] = [
        ("EasyList", "https://easylist.to/easylist/easylist.txt"),
        ("EasyPrivacy", "https://easylist.to/easylist/easyprivacy.txt"),
        ("Fanboy's Annoyance", "https://secure.fanboy.co.nz/fanboy-annoyance.txt"),
        ("Peter Lowe's List", "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0"),
        ("ABPVN (Vietnam)", "https://raw.githubusercontent.com/nicenicks/nicenicks-adblock-filter/master/nicenicks-adblock-filter.txt")
    ]

    private static let storageKey = "customFilterLists"
    private static let rulesDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("FilterLists", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        restore()
    }

    /// Adds a new filter list by URL.
    func addList(name: String, url: URL) {
        guard !lists.contains(where: { $0.url == url }) else { return }
        var list = FilterList(name: name, url: url)
        lists.append(list)
        save()

        Task {
            await updateList(id: list.id)
        }
    }

    /// Removes a filter list.
    func removeList(id: UUID) {
        lists.removeAll { $0.id == id }
        // Clean up cached rules file
        let file = Self.rulesDir.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: file)
        save()
    }

    /// Toggles a filter list on/off.
    func toggleList(id: UUID) {
        guard let idx = lists.firstIndex(where: { $0.id == id }) else { return }
        lists[idx].isEnabled.toggle()
        save()
    }

    /// Downloads and parses a filter list, converting to WebKit JSON rules.
    func updateList(id: UUID) async {
        guard let idx = lists.firstIndex(where: { $0.id == id }) else { return }
        isUpdating = true
        defer { isUpdating = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: lists[idx].url)
            guard let text = String(data: data, encoding: .utf8) else { return }
            let rules = parseFilterList(text)
            lists[idx].ruleCount = rules.count
            lists[idx].lastUpdated = Date()

            // Save as JSON for WebKit
            let jsonData = try JSONSerialization.data(withJSONObject: rules)
            let file = Self.rulesDir.appendingPathComponent("\(id.uuidString).json")
            try jsonData.write(to: file)
            save()
        } catch {
            os_log(.error, "Failed to update filter list: %@", error.localizedDescription)
        }
    }

    /// Updates all enabled lists.
    func updateAll() async {
        for list in lists where list.isEnabled {
            await updateList(id: list.id)
        }
    }

    /// Returns combined WebKit JSON rules from all enabled lists.
    func combinedRules() -> [[String: Any]] {
        var allRules: [[String: Any]] = []
        for list in lists where list.isEnabled {
            let file = Self.rulesDir.appendingPathComponent("\(list.id.uuidString).json")
            guard let data = try? Data(contentsOf: file),
                  let rules = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { continue }
            allRules.append(contentsOf: rules)
        }
        // WebKit limit: 50,000 rules max
        return Array(allRules.prefix(50_000))
    }

    /// Parses ABP/uBlock format filter list into WebKit Content Blocker JSON rules.
    private func parseFilterList(_ text: String) -> [[String: Any]] {
        var rules: [[String: Any]] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments, headers, empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("!") || trimmed.hasPrefix("[") { continue }

            // Basic domain block: ||example.com^
            if trimmed.hasPrefix("||") && trimmed.hasSuffix("^") {
                let domain = String(trimmed.dropFirst(2).dropLast(1))
                guard !domain.isEmpty, domain.count < 200 else { continue }
                let escaped = NSRegularExpression.escapedPattern(for: domain)
                    .replacingOccurrences(of: "\\*", with: ".*")
                rules.append([
                    "trigger": ["url-filter": ".*\(escaped).*"],
                    "action": ["type": "block"]
                ])
            }

            // Keep rules count manageable
            if rules.count >= 10_000 { break }
        }

        return rules
    }

    private func save() {
        if let data = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([FilterList].self, from: data) else { return }
        lists = decoded
    }
}
