import Foundation

struct PremiumHistoryGate {
    static let freeHistoryLimitDays = 90
    static let lockedPreviewDays = 14
    static let premiumHistoryLimitDays = 365

    static var freeHistoryWithPreviewDays: Int {
        freeHistoryLimitDays + lockedPreviewDays
    }

    struct Context {
        let calendar: Calendar
        let premiumStatus: PremiumStatus
        let today: Date
        let freeLimitDate: Date
        let earliestVisibleDate: Date
        let premiumBoundaryWeekCount: Int = 13

        init(
            calendar: Calendar,
            premiumStatus: PremiumStatus,
            now: Date = Date()
        ) {
            let normalizedNow = calendar.startOfDay(for: now)
            self.calendar = calendar
            self.premiumStatus = premiumStatus
            self.today = normalizedNow
            self.freeLimitDate = calendar.date(
                byAdding: .day,
                value: -PremiumHistoryGate.freeHistoryLimitDays,
                to: normalizedNow
            ) ?? normalizedNow
            self.earliestVisibleDate = calendar.date(
                byAdding: .day,
                value: -PremiumHistoryGate.freeHistoryWithPreviewDays,
                to: normalizedNow
            ) ?? normalizedNow
        }

        func isLocked(date: Date) -> Bool {
            switch premiumStatus {
            case .unknown, .premium:
                return false
            case .free:
                return PremiumHistoryGate.isDateLocked(
                    date,
                    today: today,
                    calendar: calendar
                )
            }
        }

        func visibleIntensity(for rawIntensity: Double, on date: Date) -> Double {
            isLocked(date: date) ? 0 : rawIntensity
        }

        func usesLockedStyle(on date: Date) -> Bool {
            isLocked(date: date)
        }
    }

    static func isLocked(
        date: Date,
        premiumStatus: PremiumStatus,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        switch premiumStatus {
        case .unknown, .premium:
            return false
        case .free:
            return isDateLocked(date, today: now, calendar: calendar)
        }
    }

    static func isDateLocked(
        _ date: Date,
        today: Date,
        calendar: Calendar
    ) -> Bool {
        let normalized = calendar.startOfDay(for: date)
        let normalizedToday = calendar.startOfDay(for: today)
        let cutoff = calendar.date(
            byAdding: .day,
            value: -freeHistoryLimitDays,
            to: normalizedToday
        ) ?? normalizedToday
        return normalized < cutoff
    }
}
