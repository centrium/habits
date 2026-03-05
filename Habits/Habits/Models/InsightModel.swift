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
    let debug: HabitInsightsDebugSnapshot
}

struct HabitInsightsViewModel {
    let title: String
    let cards: [HabitInsightsCard]
    let notes: [String]
}

enum HabitInsightsCard: Identifiable {
    case hero(HabitInsightsHeroBlock)
    case motivation(MotivationCard)
    case intent(HabitInsightsIntentBlock)
    case trend(HabitInsightsTrendBlock)
    case completionHistory(HabitInsightsCompletionHistoryBlock)
    case patterns(HabitInsightsPatternBlock)
    case debug(HabitInsightsDebugBlock)

    var id: String {
        switch self {
        case .hero:
            return "hero"
        case .motivation:
            return "motivation"
        case .intent:
            return "intent"
        case .trend:
            return "trend"
        case .completionHistory:
            return "completion-history"
        case .patterns:
            return "patterns"
        case .debug:
            return "debug"
        }
    }
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
    let message: String
    let tone: Tone
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

struct HabitInsightsTrendBlock {
    let heading: String
    let points: [HabitInsightsTrendPoint]
    let targetLine: Double?
    let unitText: String?
    let isValueBased: Bool
}

struct HabitInsightsCompletionHistoryBlock {
    let heading: String
    let completionRateText: String
    let streakText: String
    let longestStreakText: String?
}

struct HabitInsightsPatternBlock {
    let heading: String
    let items: [String]
}

struct HabitInsightsDebugBlock {
    let heading: String
    let lines: [String]
}
