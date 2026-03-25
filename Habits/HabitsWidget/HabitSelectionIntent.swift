//
//  HabitSelectionIntent.swift
//  HabitsWidget
//
//  Created by Codex on 25/03/2026.
//

import AppIntents
import Foundation

struct HabitEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")
    static var defaultQuery = HabitEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct HabitEntityQuery: EntityQuery {
    func entities(for identifiers: [HabitEntity.ID]) async throws -> [HabitEntity] {
        let entitiesByID = Dictionary(
            uniqueKeysWithValues: WidgetDataStore.shared.load().map {
                ($0.id, HabitEntity(id: $0.id, name: $0.name))
            }
        )

        return identifiers.compactMap { entitiesByID[$0] }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        WidgetDataStore.shared.load().map { HabitEntity(id: $0.id, name: $0.name) }
    }
}

struct HabitSelectionIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Habit Selection"
    static let description = IntentDescription("Choose which habit the momentum widget should display.")

    @Parameter(title: "Habit")
    var habit: HabitEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Show momentum for \(\.$habit)")
    }
}
