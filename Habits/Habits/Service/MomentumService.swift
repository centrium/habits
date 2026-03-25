import Foundation

enum MomentumBand: String {
    case low = "Low Momentum"
    case building = "Building Momentum"
    case strong = "Strong Momentum"
    case high = "High Momentum"

    init(score: Int) {
        switch score {
        case ...30:
            self = .low
        case ...60:
            self = .building
        case ...80:
            self = .strong
        default:
            self = .high
        }
    }
}

struct MomentumBreakdown {
    let score: Int
    let streak: Int
    let completionRate: Double
    let consistency: Double
    let completedDays: Int
    let totalDays: Int
    let band: MomentumBand
    let isMomentumDropping: Bool

    var momentumLabel: String {
        band.rawValue
    }
}

struct MomentumService {
    private let scoreService: MomentumScoreService

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.scoreService = MomentumScoreService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }

    func score(
        for goal: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> Int {
        scoreService.score(for: goal, now: now, windowDays: windowDays)
    }

    func breakdown(
        for goal: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> MomentumBreakdown {
        scoreService.breakdown(for: goal, now: now, windowDays: windowDays)
    }
}
