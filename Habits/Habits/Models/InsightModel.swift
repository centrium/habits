//
//  InsightModel.swift
//  Habits
//
//  Created by Matt Adams on 04/03/2026.
//

import Foundation

enum HabitInsightGoalMode {
    case frequency
    case cumulative
    case openEnded
}

enum TimeOfDayBucket {
    case morning
    case afternoon
    case evening
    case night
}

struct HabitInsightsPeriodSnapshot {
    let start: Date
    let end: Date
    let progressCount: Int
    let progressValue: Double
    let target: Double?
    let progress: Double
    let progressClamped: Double
    let surplus: Double
    let completionRatio: Double?
    let isCompleted: Bool?
    let activeDays: Int
}

enum HabitInsightsPaceStatus: Equatable {
    case completed
    case likelyToHitTarget
    case likelyShort
    case paceOnly
}

struct HabitInsightsPaceSnapshot {
    let unitName: String
    let elapsedUnits: Double
    let remainingUnits: Double
    let requiredPerUnit: Double?
    let projectedTotal: Double
    let status: HabitInsightsPaceStatus
}

struct HabitInsightsStreakSnapshot {
    let current: Int
    let longest: Int
}

struct HabitInsightsCompletionHistorySnapshot {
    let completed: Int
    let total: Int
}

struct MonthInsight: Identifiable {
    let month: Date
    let monthLabel: String
    let goal: Int
    let completionCount: Int
    let goalMet: Bool
    let completionRatio: Double

    var id: Date { month }
}

struct HabitInsightsDebugRow: Identifiable {
    let key: String
    let periodStart: Date
    let periodEnd: Date
    let countTotal: Int
    let valueTotal: Double

    var id: String { key }
}

struct HabitInsightsDebugSnapshot {
    let anchorDate: Date
    let logAnchorDate: Date?
    let asOfUpperBound: Date
    let periodStart: Date
    let periodEnd: Date
    let periodProgressCount: Int
    let periodProgressValue: Double
    let progressSoFarCount: Int
    let progressSoFarValue: Double
    let target: Double?
    let elapsedUnits: Double
    let remainingUnits: Double
    let projected: Double
    let periodRows: [HabitInsightsDebugRow]
}

struct HabitInsightsSnapshot {
    let anchorDate: Date
    let cadence: GoalPeriod
    let goalMode: HabitInsightGoalMode
    let isValueBased: Bool
    let target: Double?
    let effectiveStartDate: Date
    let currentPeriod: HabitInsightsPeriodSnapshot
    let currentPeriodSoFar: HabitInsightsPeriodSnapshot
    let pace: HabitInsightsPaceSnapshot
    let streak: HabitInsightsStreakSnapshot
    let completionHistory: HabitInsightsCompletionHistorySnapshot?
    let trendBuckets: [HabitInsightsPeriodSnapshot]
    let progressCurrent: Int
    let goal: Int
    let goalMet: Bool
    let overflowCount: Int
    let currentStreak: Int
    let longestStreak: Int
    let projectedMonthlyTotal: Int
    let projectedCompletion: Int
    let projectedGoalDifference: Int
    let consistencyScore: Double?
    let averageLogsPerWeek: Double?
    let lastSixMonths: [MonthInsight]
    let strongestWeekday: String?
    let weakestWeekday: String?
    let commonLogWindow: String?
    let timingInsight: String?
    let milestoneInsight: String?
    let recoveryInsight: String?
    let motivationMessage: String?
    let patternSummary: String?
    let debug: HabitInsightsDebugSnapshot
}

struct HabitInsightsViewModel {
    let title: String
    let cards: [HabitInsightsCard]
    let notes: [String]
}

enum HabitInsightsCard: Identifiable {
    case achievement(HabitInsightsAchievementBlock)
    case goalPace(HabitInsightsGoalPaceBlock)
    case momentum(HabitInsightsMomentumBlock)
    case consistency(HabitInsightsConsistencyBlock)
    case hero(HabitInsightsHeroBlock)
    case motivation(MotivationCard)
    case intent(HabitInsightsIntentBlock)
    case trend(HabitInsightsTrendBlock)
    case weeklyRhythm(HabitInsightsWeeklyRhythmBlock)
    case completionHistory(HabitInsightsCompletionHistoryBlock)
    case behaviourInsights(HabitInsightsBehaviourBlock)
    case greigMode(HabitInsightsGreigModeBlock)
    case debug(HabitInsightsDebugBlock)

    var id: String {
        switch self {
        case .achievement:
            return "achievement"
        case .goalPace:
            return "goal-pace"
        case .momentum:
            return "momentum"
        case .consistency:
            return "consistency"
        case .hero:
            return "hero"
        case .motivation:
            return "motivation"
        case .intent:
            return "intent"
        case .trend:
            return "trend"
        case .weeklyRhythm:
            return "weekly-rhythm"
        case .completionHistory:
            return "completion-history"
        case .behaviourInsights:
            return "behaviour-insights"
        case .greigMode:
            return "greig-mode"
        case .debug:
            return "debug"
        }
    }
}

struct HabitInsightsAchievementBlock {
    let progressText: String
    let statusText: String
    let overflowText: String?
    let progressRatio: Double
}

struct HabitInsightsMomentumBlock {
    let currentStreakText: String
    let longestStreakText: String
    let paceText: String
}

struct HabitInsightsConsistencyBlock {
    let scoreText: String
    let averageText: String?
}

struct HabitInsightsHeroBlock {
    let heading: String
    let valueText: String
    let statusText: String?
    let surplusText: String?
    let periodLabel: String
    let comparisonText: String?
}

enum Tone {
    case encouragement
    case celebration
    case nudge
}

struct MotivationCard {
    let headline: String
    let supportingText: String
    let iconName: String
    let tone: Tone

    var message: String {
        "\(headline)\n\(supportingText)"
    }
}

struct HabitInsightsIntentBlock {
    let heading: String
    let primaryText: String
    let secondaryText: String?
    let projectionText: String
}

struct HabitInsightsTrendPoint: Identifiable {
    let periodStart: Date
    let label: String
    let value: Double

    var id: Date { periodStart }
}

struct HabitInsightsChartPoint: Identifiable {
    let x: Double
    let y: Double

    var id: String {
        "\(x)-\(y)"
    }
}

struct HabitInsightsGoalPaceBlock {
    let heading: String
    let expectedLine: [HabitInsightsChartPoint]
    let actualLine: [HabitInsightsChartPoint]
    let projectionLine: [HabitInsightsChartPoint]
    let targetValue: Double
    let statusText: String
    let targetText: String
}

struct HabitInsightsTrendBlock {
    let heading: String
    let points: [HabitInsightsTrendPoint]
    let targetLine: Double?
    let unitText: String?
    let insightText: String?
    let insightSupportingText: String?
    let isValueBased: Bool
    let isCompletionRatioBars: Bool
}

struct HabitInsightsWeeklyRhythmDay: Identifiable {
    let index: Int
    let dayLabel: String
    let fullDayLabel: String
    let entries: Int

    var id: Int { index }
}

struct HabitInsightsWeeklyRhythmBlock {
    let heading: String
    let days: [HabitInsightsWeeklyRhythmDay]
}

struct HabitInsightsCompletionHistoryBlock {
    let heading: String
    let completionRateText: String
    let streakText: String
    let longestStreakText: String?
}

struct HabitInsightsBehaviourBlock {
    let heading: String
    let observations: [String]
    let suggestion: String
}

struct HabitInsightsGreigModeBlock {
    let heading: String
    let headline: String
    let supportText: String
    let iconName: String
}

struct HabitInsightsDebugBlock {
    let heading: String
    let lines: [String]
}
