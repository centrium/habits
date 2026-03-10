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

    @Published var openHabitID: UUID?

    func openHabit(_ id: UUID) {
        openHabitID = id
    }

}
