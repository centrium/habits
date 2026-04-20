import Foundation

struct EveningReflectionProgress: Equatable {
    let totalHabits: Int
    let completedHabitsToday: Int
    let remainingHabits: Int

    init(totalHabits: Int, completedHabitsToday: Int, remainingHabits: Int? = nil) {
        let safeTotal = max(0, totalHabits)
        let safeCompleted = min(max(0, completedHabitsToday), safeTotal)
        let inferredRemaining = max(0, safeTotal - safeCompleted)

        self.totalHabits = safeTotal
        self.completedHabitsToday = safeCompleted
        let requestedRemaining = remainingHabits ?? inferredRemaining
        self.remainingHabits = min(max(0, requestedRemaining), safeTotal)
    }
}

struct EveningReflectionContent: Equatable {
    let title: String
    let body: String
}

enum EveningReflection {
    static let title = "Evening Reflection"
    static let description = "A gentle reminder to reflect on your habit progress for the day."
    static let identifier = "evening-reflection"

    static let earliestHour = 17
    static let latestHour = 22
    static let defaultHour = 20
    static let defaultMinute = 0

    static let previewMessages: [String] = [
        "No check-ins yet today.",
        "Nice progress today.",
        "Just one habit left today.",
        "Everything done today. Nice work."
    ]

    static func isAllowed(hour: Int, minute: Int) -> Bool {
        guard (0..<60).contains(minute) else { return false }
        if hour == latestHour {
            return minute == 0
        }
        return (earliestHour..<latestHour).contains(hour)
    }

    static func clamped(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
        if hour < earliestHour {
            return (earliestHour, 0)
        }

        if hour > latestHour {
            return (latestHour, 0)
        }

        let boundedMinute = min(max(minute, 0), 59)

        if hour == latestHour {
            return (latestHour, 0)
        }

        return (hour, boundedMinute)
    }

    static func date(
        hour: Int,
        minute: Int,
        on referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let normalized = clamped(hour: hour, minute: minute)
        let dayStart = calendar.startOfDay(for: referenceDate)
        return calendar.date(
            bySettingHour: normalized.hour,
            minute: normalized.minute,
            second: 0,
            of: dayStart
        ) ?? dayStart
    }

    static func clamped(date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return self.date(
            hour: components.hour ?? defaultHour,
            minute: components.minute ?? defaultMinute,
            on: date,
            calendar: calendar
        )
    }

    static func timeRange(for referenceDate: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let start = date(hour: earliestHour, minute: 0, on: referenceDate, calendar: calendar)
        let end = date(hour: latestHour, minute: 0, on: referenceDate, calendar: calendar)
        return start...end
    }

    static func content(for progress: EveningReflectionProgress) -> EveningReflectionContent {
        if progress.completedHabitsToday == 0 {
            return EveningReflectionContent(
                title: title,
                body: "No check-ins yet today.\nTomorrow is another opportunity."
            )
        }

        if progress.remainingHabits == 0 {
            return EveningReflectionContent(
                title: title,
                body: "Everything done today.\nWell done."
            )
        }

        if progress.remainingHabits == 1 {
            return EveningReflectionContent(
                title: title,
                body: "Just one habit left today.\nFinish strong."
            )
        }

        return EveningReflectionContent(
            title: title,
            body: "Nice progress today. Keep building the habit."
        )
    }
}
