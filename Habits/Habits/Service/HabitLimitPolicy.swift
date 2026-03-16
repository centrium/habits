import Foundation

enum HabitAddDestination: Equatable {
    case addHabitSheet
    case paywall(feature: PremiumFeature)
}

struct HabitLimitPolicy: Equatable {
    static let freeHabitLimit = 3
    static let upgradeHintThreshold = 2

    let habitCount: Int
    let hasUnlimitedHabitsAccess: Bool

    var addHabitDestination: HabitAddDestination {
        if hasUnlimitedHabitsAccess {
            return .addHabitSheet
        }

        if habitCount >= Self.freeHabitLimit {
            return .paywall(feature: .unlimitedHabits)
        }

        return .addHabitSheet
    }

    var showsUpgradeHint: Bool {
        !hasUnlimitedHabitsAccess && habitCount == Self.upgradeHintThreshold
    }

    var showsLockedSlot: Bool {
        !hasUnlimitedHabitsAccess && habitCount == Self.freeHabitLimit
    }
}
