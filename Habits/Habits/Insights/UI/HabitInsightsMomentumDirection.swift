import SwiftUI

enum HabitInsightsMomentumDirection {
    case up
    case neutral
    case down

    var arrow: String {
        switch self {
        case .up:
            return "↑"
        case .neutral:
            return "→"
        case .down:
            return "↓"
        }
    }

    var color: Color {
        switch self {
        case .up:
            return .green
        case .neutral:
            return .secondary
        case .down:
            return .red
        }
    }

    var heroLabel: String {
        switch self {
        case .up:
            return "vs previous period"
        case .neutral:
            return "holding steady vs previous period"
        case .down:
            return "vs previous period"
        }
    }

    var momentumSummary: String {
        switch self {
        case .up:
            return "Activity increased compared to last week."
        case .neutral:
            return "Activity is in line with last week."
        case .down:
            return "Activity is below last week."
        }
    }
}
