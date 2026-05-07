import Foundation

struct MetaLine: Equatable {
    let text: String
}

enum MetaDisplayFormatter {
    static func format(
        habit: Habit,
        service: HabitLogService,
        asOf now: Date,
        weekStartPreference: WeekStartPreference
    ) -> [MetaLine] {
        [MetaLine(
            text: HabitSecondaryMetricFormatter.text(
                habit: habit,
                service: service,
                asOf: now,
                weekStartPreference: weekStartPreference
            )
        )]
    }
}

