// TabGroup.swift
// VeloBrowser
//
// Model and management for tab groups (color-coded collections).

import SwiftUI

/// A named, color-coded group of tabs.
struct TabGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorName: String
    var tabIDs: [UUID]
    var createdAt: Date

    init(name: String, colorName: String = "blue", tabIDs: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.colorName = colorName
        self.tabIDs = tabIDs
        self.createdAt = .now
    }

    var color: Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }

    static let availableColors = ["blue", "red", "orange", "yellow", "green", "purple", "pink"]
}

/// Manages tab groups with persistence.
@Observable
@MainActor
final class TabGroupManager {
    private(set) var groups: [TabGroup] = []

    private static let storageKey = "tabGroups"

    init() {
        restore()
    }

    func createGroup(name: String, color: String = "blue", tabIDs: [UUID] = []) {
        let group = TabGroup(name: name, colorName: color, tabIDs: tabIDs)
        groups.append(group)
        save()
    }

    func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        save()
    }

    func renameGroup(id: UUID, name: String) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[idx].name = name
        save()
    }

    func setColor(id: UUID, color: String) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[idx].colorName = color
        save()
    }

    func addTab(_ tabID: UUID, to groupID: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        if !groups[idx].tabIDs.contains(tabID) {
            groups[idx].tabIDs.append(tabID)
            save()
        }
    }

    func removeTab(_ tabID: UUID, from groupID: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[idx].tabIDs.removeAll { $0 == tabID }
        save()
    }

    /// Returns the group a tab belongs to, if any.
    func group(for tabID: UUID) -> TabGroup? {
        groups.first { $0.tabIDs.contains(tabID) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([TabGroup].self, from: data) else { return }
        groups = decoded
    }
}
