//
//  DeepLinkManager.swift
//  Habits
//
//  Created by Matt Adams on 10/03/2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class DeepLinkManager: ObservableObject {

    static let shared = DeepLinkManager()

    @Published var pendingHabitID: UUID?
    @Published var selectedHabitID: UUID?

    func openHabit(_ id: UUID) {
        pendingHabitID = id
    }

    func processPendingHabitIfNeeded() {
        guard let pendingHabitID else { return }
        selectedHabitID = pendingHabitID
        self.pendingHabitID = nil
    }

    func clearSelectedHabit(_ id: UUID) {
        guard selectedHabitID == id else { return }
        selectedHabitID = nil
    }

    func handle(url: URL) {
        guard let id = Self.habitID(from: url) else { return }
        pendingHabitID = id
    }

    static func habitID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == "habits" else { return nil }
        guard url.host?.lowercased() == "habit" else { return nil }

        let pathParts = url.pathComponents.dropFirst()
        guard
            let idString = pathParts.first,
            let id = UUID(uuidString: idString)
        else {
            return nil
        }

        return id
    }
}
