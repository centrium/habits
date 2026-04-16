import CoreGraphics
import Foundation

enum StreakIndicatorPresentation {
    static let minimumDotCount = 5
    static let maximumDotCount = 7
    static let reservedWidth: CGFloat = 44

    struct DirectionalDots: Equatable {
        struct Dot: Equatable {
            let isFilled: Bool
            let isToday: Bool
            let isAtRisk: Bool
        }

        let dots: [Dot]

        var filledCount: Int {
            dots.filter(\.isFilled).count
        }
    }

    struct Context: Equatable {
        let streak: Int
        let showBadge: Bool
        let isAtRisk: Bool
        let status: StreakStatus
        let directionalDots: DirectionalDots
    }

    static func shouldShow(streak: Int) -> Bool {
        streak > 0
    }

    static func valueText(for streak: Int) -> String {
        "\(max(0, streak))"
    }

    static func context(
        streakState: StreakState
    ) -> Context {
        let streak = max(0, streakState.currentStreak)
        let showsBadge = shouldShow(streak: streak)
        let isAtRisk = showsBadge && streakState.status == .atRisk
        let dots = directionalDots(
            streak: streak,
            hasMetRequirementToday: streakState.hasMetRequirementToday,
            isAtRisk: isAtRisk
        )

        return Context(
            streak: streak,
            showBadge: showsBadge,
            isAtRisk: isAtRisk,
            status: streakState.status,
            directionalDots: dots
        )
    }

    private static func directionalDots(
        streak: Int,
        hasMetRequirementToday: Bool,
        isAtRisk: Bool
    ) -> DirectionalDots {
        let dotCount = min(max(streak + 1, minimumDotCount), maximumDotCount)
        let filledCount = min(streak, dotCount)

        let todayIndex: Int = {
            if hasMetRequirementToday {
                return min(max(streak - 1, 0), dotCount - 1)
            }
            return min(streak, dotCount - 1)
        }()

        let dots = (0..<dotCount).map { index in
            DirectionalDots.Dot(
                isFilled: index < filledCount,
                isToday: index == todayIndex,
                isAtRisk: isAtRisk && index == todayIndex
            )
        }

        return DirectionalDots(dots: dots)
    }
}
