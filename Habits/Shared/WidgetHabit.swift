//
//  WidgetHabit.swift
//  Habits
//
//  Created by Matt Adams on 20/03/2026.
//

import Foundation
import OSLog

enum CadencePaletteToken: String, CaseIterable {
    case fern
    case sage
    case cobalt
    case sky
    case iris
    case amethyst
    case apricot
    case amber
    case coral
    case rose
    case teal
    case cyan
}

struct CadencePaletteTones {
    let base: String
    let soft: String
    let strong: String
}

struct CadenceHeatmapScale {
    let scale1: String
    let scale2: String
    let scale3: String
    let scale4: String
    let scale5: String
}

struct CadencePaletteRoles {
    let primaryAccent: String
    let secondaryAccent: String
    let ambientSurface: String
    let highlightPeak: String
}

enum CadenceColorPalette {
    static func roles(for token: CadencePaletteToken) -> CadencePaletteRoles {
        switch token {
        case .fern:
            return CadencePaletteRoles(
                primaryAccent: "#4CAF50",
                secondaryAccent: "#3E9A43",
                ambientSurface: "#76C879",
                highlightPeak: "#9FE26A"
            )
        case .sage:
            return CadencePaletteRoles(
                primaryAccent: "#8BC34A",
                secondaryAccent: "#74A93A",
                ambientSurface: "#A9D86F",
                highlightPeak: "#C4FF8C"
            )
        case .cobalt:
            return CadencePaletteRoles(
                primaryAccent: "#1565C0",
                secondaryAccent: "#0F52A3",
                ambientSurface: "#4D8ED8",
                highlightPeak: "#5FB0E6"
            )
        case .sky:
            return CadencePaletteRoles(
                primaryAccent: "#42A5F5",
                secondaryAccent: "#2E8FDE",
                ambientSurface: "#78C1F8",
                highlightPeak: "#8FD3FF"
            )
        case .iris:
            return CadencePaletteRoles(
                primaryAccent: "#7E57C2",
                secondaryAccent: "#6945AD",
                ambientSurface: "#A583D8",
                highlightPeak: "#C7A8FF"
            )
        case .amethyst:
            return CadencePaletteRoles(
                primaryAccent: "#5E35B1",
                secondaryAccent: "#4D2897",
                ambientSurface: "#8763CA",
                highlightPeak: "#A785E6"
            )
        case .apricot:
            return CadencePaletteRoles(
                primaryAccent: "#FF8A65",
                secondaryAccent: "#E3734E",
                ambientSurface: "#FFAF94",
                highlightPeak: "#FFB77A"
            )
        case .amber:
            return CadencePaletteRoles(
                primaryAccent: "#FFB300",
                secondaryAccent: "#E09A00",
                ambientSurface: "#FFCB4D",
                highlightPeak: "#FFE27A"
            )
        case .coral:
            return CadencePaletteRoles(
                primaryAccent: "#FF6F61",
                secondaryAccent: "#E45C50",
                ambientSurface: "#FF968C",
                highlightPeak: "#FFB3C1"
            )
        case .rose:
            return CadencePaletteRoles(
                primaryAccent: "#EC407A",
                secondaryAccent: "#D12D67",
                ambientSurface: "#F073A0",
                highlightPeak: "#FFB3C1"
            )
        case .teal:
            return CadencePaletteRoles(
                primaryAccent: "#009688",
                secondaryAccent: "#007D73",
                ambientSurface: "#48B8AE",
                highlightPeak: "#5EF2E0"
            )
        case .cyan:
            return CadencePaletteRoles(
                primaryAccent: "#00ACC1",
                secondaryAccent: "#0093A6",
                ambientSurface: "#57CAD9",
                highlightPeak: "#6BD7EB"
            )
        }
    }

    static func light(for token: CadencePaletteToken) -> CadencePaletteTones {
        let roles = roles(for: token)
        return CadencePaletteTones(
            base: roles.primaryAccent,
            soft: roles.ambientSurface,
            strong: roles.secondaryAccent
        )
    }

    static func dark(for token: CadencePaletteToken) -> CadencePaletteTones {
        let roles = roles(for: token)
        return CadencePaletteTones(
            base: roles.secondaryAccent,
            soft: mix(hex: roles.ambientSurface, with: "#121212", towardSecond: 0.70),
            strong: roles.highlightPeak
        )
    }

    static func highlight(for token: CadencePaletteToken) -> CadencePaletteTones {
        let roles = roles(for: token)
        return CadencePaletteTones(
            base: roles.highlightPeak,
            soft: roles.ambientSurface,
            strong: roles.highlightPeak
        )
    }

    static func heatmapLight(for token: CadencePaletteToken) -> CadenceHeatmapScale {
        switch token {
        case .fern, .sage:
            return CadenceHeatmapScale(
                scale1: "#E4F1DE",
                scale2: "#C8E6BE",
                scale3: "#9FD173",
                scale4: "#73B34A",
                scale5: "#4F7A3F"
            )
        case .cobalt, .sky:
            return CadenceHeatmapScale(
                scale1: "#E1EDFA",
                scale2: "#C4DCF3",
                scale3: "#8FBBE6",
                scale4: "#5C94D2",
                scale5: "#2F5F8A"
            )
        case .iris, .amethyst:
            return CadenceHeatmapScale(
                scale1: "#ECE5F8",
                scale2: "#D5C4EF",
                scale3: "#B497DE",
                scale4: "#8C6BCB",
                scale5: "#5E3F8A"
            )
        case .teal, .cyan:
            return CadenceHeatmapScale(
                scale1: "#E1F4F2",
                scale2: "#BFE9E3",
                scale3: "#84D2C7",
                scale4: "#49B7A8",
                scale5: "#176E68"
            )
        case .rose, .coral:
            return CadenceHeatmapScale(
                scale1: "#F8E7EB",
                scale2: "#F1CBD5",
                scale3: "#E29DAF",
                scale4: "#C97186",
                scale5: "#7A3F47"
            )
        case .amber:
            return CadenceHeatmapScale(
                scale1: "#F8F0D9",
                scale2: "#EEDFAE",
                scale3: "#E0C36A",
                scale4: "#C29A1F",
                scale5: "#8A6E14"
            )
        case .apricot:
            return CadenceHeatmapScale(
                scale1: "#F9EBDD",
                scale2: "#F3D5BC",
                scale3: "#E8B186",
                scale4: "#D3874A",
                scale5: "#8A4A14"
            )
        }
    }

    static func heatmapDark(for token: CadencePaletteToken) -> CadenceHeatmapScale {
        switch token {
        case .fern, .sage:
            return CadenceHeatmapScale(
                scale1: "#203225",
                scale2: "#2C4930",
                scale3: "#3D6640",
                scale4: "#51884E",
                scale5: "#6EAF60"
            )
        case .cobalt, .sky:
            return CadenceHeatmapScale(
                scale1: "#1F2E43",
                scale2: "#2C4362",
                scale3: "#3E5B84",
                scale4: "#5478AC",
                scale5: "#6E9BDA"
            )
        case .iris, .amethyst:
            return CadenceHeatmapScale(
                scale1: "#2A2340",
                scale2: "#3A305A",
                scale3: "#52407C",
                scale4: "#7057A8",
                scale5: "#9474D6"
            )
        case .teal, .cyan:
            return CadenceHeatmapScale(
                scale1: "#1A3533",
                scale2: "#25514C",
                scale3: "#33726A",
                scale4: "#46998D",
                scale5: "#5CBEB0"
            )
        case .rose, .coral:
            return CadenceHeatmapScale(
                scale1: "#3A242A",
                scale2: "#55323A",
                scale3: "#794753",
                scale4: "#A86172",
                scale5: "#D07D92"
            )
        case .amber:
            return CadenceHeatmapScale(
                scale1: "#3D3417",
                scale2: "#5B4D22",
                scale3: "#826C30",
                scale4: "#B29142",
                scale5: "#D8B35D"
            )
        case .apricot:
            return CadenceHeatmapScale(
                scale1: "#3E2B1A",
                scale2: "#5D3F24",
                scale3: "#885A32",
                scale4: "#BB7B45",
                scale5: "#DE9762"
            )
        }
    }

    static func token(from baseHex: String) -> CadencePaletteToken? {
        let normalized = normalizeHex(baseHex)
        if let directMatch = CadencePaletteToken.allCases.first(
            where: { normalizeHex(light(for: $0).base) == normalized }
        ) {
            return directMatch
        }

        return CadencePaletteToken.allCases.first {
            legacyBaseHexes(for: $0).contains(normalized)
        }
    }

    static func normalizeHex(_ hex: String) -> String {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return cleaned.hasPrefix("#") ? cleaned : "#\(cleaned)"
    }

    static func lighten(hex: String, by amount: Double) -> String {
        let rgb = RGB(hex: hex)
        return rgb.mixed(with: RGB(hex: "#FFFFFF"), amount: amount).hex
    }

    static func mix(hex: String, with otherHex: String, towardSecond amount: Double) -> String {
        let first = RGB(hex: hex)
        let second = RGB(hex: otherHex)
        return first.mixed(with: second, amount: amount).hex
    }

    private static func legacyBaseHexes(for token: CadencePaletteToken) -> Set<String> {
        switch token {
        case .fern: return ["#5FAF7A", "#8BC34A"]
        case .sage: return ["#7FBF95", "#388E3C"]
        case .cobalt: return ["#5B7DB8", "#1976D2"]
        case .sky: return ["#6F95C8", "#4FA6E8"]
        case .iris: return ["#7A6FB2", "#7B61D1"]
        case .amethyst: return ["#8B80C2", "#5A47B8"]
        case .apricot: return ["#C69C4F", "#FF9800"]
        case .amber: return ["#D2AE6A", "#FFB300"]
        case .coral: return ["#C46A6A", "#FF6F61"]
        case .rose: return ["#C46A6A", "#FF69B4"]
        case .teal: return ["#5FA3A0", "#009688"]
        case .cyan: return ["#5FA3A0", "#19AFCF"]
        }
    }
}

private struct RGB {
    let r: Double
    let g: Double
    let b: Double

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.r = Double((value >> 16) & 0xFF) / 255.0
        self.g = Double((value >> 8) & 0xFF) / 255.0
        self.b = Double(value & 0xFF) / 255.0
    }

    private init(r: Double, g: Double, b: Double) {
        self.r = min(max(r, 0), 1)
        self.g = min(max(g, 0), 1)
        self.b = min(max(b, 0), 1)
    }

    func mixed(with other: RGB, amount: Double) -> RGB {
        let t = min(max(amount, 0), 1)
        return RGB(
            r: (r * (1 - t)) + (other.r * t),
            g: (g * (1 - t)) + (other.g * t),
            b: (b * (1 - t)) + (other.b * t)
        )
    }

    var hex: String {
        String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)),
            Int(round(g * 255)),
            Int(round(b * 255))
        )
    }
}

enum CadenceStateKey: Equatable {
    case gettingStarted
    case building
    case steady
    case strong
    case slipping
    case rebuilding
}

enum CadenceCopyCatalog {
    // Cadence copy rule:
    // Do not add state-label or state-line string literals outside this file.
    static func identityTitle() -> String {
        "Identity"
    }

    static func identityEmptyPrompt() -> String {
        "Make this part of who you are"
    }

    static func identityHelper() -> String {
        "This helps turn habits into part of who you are"
    }

    static func identityPlaceholder() -> String {
        "e.g. Someone who moves daily"
    }

    static func identityStat(days: Int, window: Int) -> String {
        "Shown up \(days) of the last \(window) days"
    }

    static func identityReinforcement() -> String {
        "Each check-in reinforces this"
    }

    static func shortLabel(for state: CadenceStateKey) -> String {
        switch state {
        case .gettingStarted:
            return "Getting started"
        case .building:
            return "Building momentum"
        case .steady:
            return "Staying consistent"
        case .strong:
            return "Strong rhythm"
        case .slipping:
            return "Losing momentum"
        case .rebuilding:
            return "Getting back on track"
        }
    }

    static func identityLine(for state: CadenceStateKey) -> String {
        switch state {
        case .gettingStarted:
            return "Getting started"
        case .building:
            return "Building momentum"
        case .steady:
            return "Staying consistent"
        case .strong:
            return "Strong rhythm"
        case .slipping:
            return "Losing momentum"
        case .rebuilding:
            return "Getting back on track"
        }
    }

    static func insightLine(for state: CadenceStateKey) -> String {
        switch state {
        case .gettingStarted:
            return "You're getting started with this habit"
        case .building:
            return "This habit is building momentum"
        case .steady:
            return "This habit is staying consistent"
        case .strong:
            return "This habit has a strong rhythm"
        case .slipping:
            return "This habit is losing momentum"
        case .rebuilding:
            return "This habit is getting back on track"
        }
    }

    static func riskEarlyStage() -> String {
        "You’re still building this habit"
    }
}

enum WidgetGoalType: String, Codable {
    case binary
    case goal
    case openEnded
}

enum WidgetHeatmapAggregationKind: String, Codable {
    case completion
    case count
    case value
}

struct WidgetActivitySample: Codable, Equatable {
    let date: Date
    let value: Double
}

struct WidgetHabit: Codable, Identifiable {
    let id: UUID
    let name: String
    let identityTitle: String
    let identityLine1: String?
    let identityLine2: String?
    let isCompleteToday: Bool
    let streak: Int
    let goalType: WidgetGoalType
    let progress: Double?
    let hasActivityToday: Bool
    let iconName: String?
    let colorHex: String?
    let identityState: WidgetHabitIdentityState
    let heatmapAggregationKind: WidgetHeatmapAggregationKind
    let recentActivity: [WidgetActivitySample]

    var goalProgress: Double {
        guard goalType == .goal else { return 0 }
        return Self.clampedGoalProgress(progress)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case identityTitle
        case identityLine1
        case identityLine2
        case isCompleteToday
        case streak
        case goalType
        case progress
        case hasActivityToday
        case iconName
        case colorHex
        case identityState
        case heatmapAggregationKind
        case recentActivity

        // Legacy payload support
        case progressFraction
        case usesActivityIndicator
        case identityText
        case stateText
        case progressText
    }

    init(
        id: UUID,
        name: String,
        identityTitle: String? = nil,
        identityLine1: String? = nil,
        identityLine2: String? = nil,
        isCompleteToday: Bool,
        streak: Int,
        goalType: WidgetGoalType,
        progress: Double?,
        hasActivityToday: Bool,
        iconName: String?,
        colorHex: String?,
        identityState: WidgetHabitIdentityState = .gettingStarted,
        heatmapAggregationKind: WidgetHeatmapAggregationKind = .completion,
        recentActivity: [WidgetActivitySample] = []
    ) {
        self.id = id
        self.name = name
        self.identityTitle = Self.normalizedIdentityTitle(identityTitle, fallbackName: name)
        self.identityLine1 = Self.normalizedLine(identityLine1)
            ?? Self.defaultLine1(from: recentActivity, windowDays: 7)
        self.identityLine2 = Self.normalizedLine(identityLine2)
        self.isCompleteToday = isCompleteToday
        self.streak = streak
        self.goalType = goalType
        self.progress = Self.normalizedProgress(for: goalType, progress: progress)
        self.hasActivityToday = hasActivityToday
        self.iconName = iconName
        self.colorHex = colorHex
        self.identityState = identityState
        self.heatmapAggregationKind = heatmapAggregationKind
        self.recentActivity = recentActivity

        WidgetHabitLogger.log(
            context: "initialized",
            habitName: name,
            goalType: goalType,
            progress: self.progress
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let decodedIdentityTitle = try container.decodeIfPresent(String.self, forKey: .identityTitle)
            ?? (try container.decodeIfPresent(String.self, forKey: .identityText))
        isCompleteToday = try container.decode(Bool.self, forKey: .isCompleteToday)
        streak = try container.decode(Int.self, forKey: .streak)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        if let decodedGoalType = try container.decodeIfPresent(WidgetGoalType.self, forKey: .goalType) {
            goalType = decodedGoalType
            let decodedProgress = try container.decodeIfPresent(Double.self, forKey: .progress)
            progress = Self.normalizedProgress(for: decodedGoalType, progress: decodedProgress)
            let decodedHasActivity = try container.decodeIfPresent(Bool.self, forKey: .hasActivityToday)
            hasActivityToday = Self.resolvedHasActivity(
                explicitHasActivity: decodedHasActivity,
                goalType: decodedGoalType,
                progress: progress,
                isCompleteToday: isCompleteToday
            )
            if let decodedIdentityState = try container.decodeIfPresent(WidgetHabitIdentityState.self, forKey: .identityState) {
                identityState = decodedIdentityState
            } else {
                identityState = .gettingStarted
            }
            heatmapAggregationKind = try container.decodeIfPresent(
                WidgetHeatmapAggregationKind.self,
                forKey: .heatmapAggregationKind
            ) ?? .completion
            recentActivity = try container.decodeIfPresent(
                [WidgetActivitySample].self,
                forKey: .recentActivity
            ) ?? []
            let decodedLine1 = try container.decodeIfPresent(String.self, forKey: .identityLine1)
                ?? (try container.decodeIfPresent(String.self, forKey: .progressText))
            let decodedLine2 = try container.decodeIfPresent(String.self, forKey: .identityLine2)
                ?? (try container.decodeIfPresent(String.self, forKey: .stateText))
            identityTitle = Self.normalizedIdentityTitle(decodedIdentityTitle, fallbackName: name)
            identityLine1 = Self.normalizedLine(decodedLine1)
                ?? Self.defaultLine1(from: recentActivity, windowDays: 7)
            identityLine2 = Self.normalizedLine(decodedLine2)
            WidgetHabitLogger.log(
                context: "decoded",
                habitName: name,
                goalType: goalType,
                progress: progress
            )
            return
        }

        let legacyProgress = try container.decodeIfPresent(Double.self, forKey: .progressFraction)
        let legacyUsesActivity = try container.decodeIfPresent(Bool.self, forKey: .usesActivityIndicator) ?? false

        if legacyUsesActivity {
            goalType = .openEnded
            progress = nil
            hasActivityToday = false
        } else if let legacyProgress {
            goalType = .goal
            progress = Self.normalizedProgress(for: .goal, progress: legacyProgress)
            hasActivityToday = Self.clampedGoalProgress(progress) > 0
        } else {
            goalType = .binary
            progress = nil
            hasActivityToday = isCompleteToday
        }
        identityState = .gettingStarted
        identityTitle = name
        identityLine1 = Self.defaultLine1(from: [], windowDays: 7)
        identityLine2 = nil
        heatmapAggregationKind = .completion
        recentActivity = []

        WidgetHabitLogger.log(
            context: "decoded-legacy",
            habitName: name,
            goalType: goalType,
            progress: progress
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(identityTitle, forKey: .identityTitle)
        try container.encodeIfPresent(identityLine1, forKey: .identityLine1)
        try container.encodeIfPresent(identityLine2, forKey: .identityLine2)
        try container.encode(isCompleteToday, forKey: .isCompleteToday)
        try container.encode(streak, forKey: .streak)
        try container.encode(goalType, forKey: .goalType)
        if goalType == .goal {
            try container.encode(goalProgress, forKey: .progress)
        } else {
            try container.encodeIfPresent(progress, forKey: .progress)
        }
        try container.encode(hasActivityToday, forKey: .hasActivityToday)
        try container.encodeIfPresent(iconName, forKey: .iconName)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encode(identityState, forKey: .identityState)
        try container.encode(heatmapAggregationKind, forKey: .heatmapAggregationKind)
        try container.encode(recentActivity, forKey: .recentActivity)
    }

    private static func normalizedProgress(for goalType: WidgetGoalType, progress: Double?) -> Double? {
        if goalType == .goal {
            return clampedGoalProgress(progress)
        }

        guard let progress else { return nil }
        return progress.isFinite ? progress : nil
    }

    private static func clampedGoalProgress(_ progress: Double?) -> Double {
        guard let progress, progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    private static func resolvedHasActivity(
        explicitHasActivity: Bool?,
        goalType: WidgetGoalType,
        progress: Double?,
        isCompleteToday: Bool
    ) -> Bool {
        if let explicitHasActivity {
            return explicitHasActivity
        }

        switch goalType {
        case .goal:
            return clampedGoalProgress(progress) > 0
        case .binary:
            return isCompleteToday
        case .openEnded:
            return false
        }
    }

    private static func normalizedLine(_ line: String?) -> String? {
        guard let trimmed = line?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private static func normalizedIdentityTitle(
        _ title: String?,
        fallbackName: String
    ) -> String {
        normalizedLine(title) ?? fallbackName
    }

    private static func defaultLine1(
        from recentActivity: [WidgetActivitySample],
        windowDays: Int
    ) -> String {
        let normalizedWindow = max(1, windowDays)
        let activeDays = recentActivity
            .sorted { $0.date > $1.date }
            .prefix(normalizedWindow)
            .reduce(0) { count, sample in
                count + (sample.value > 0 ? 1 : 0)
            }

        return CadenceCopyCatalog.identityStat(days: activeDays, window: normalizedWindow)
    }
}

struct WidgetHabitSummary: Codable {
    let id: UUID
    let identityTitle: String
    let identityLine1: String?
    let identityLine2: String?
}

extension WidgetHabit {
    var summary: WidgetHabitSummary {
        WidgetHabitSummary(
            id: id,
            identityTitle: identityTitle,
            identityLine1: identityLine1,
            identityLine2: identityLine2
        )
    }
}

enum WidgetHabitIdentityState: String, Codable, Equatable {
    case gettingStarted = "starting"
    case building
    case steady
    case strong = "holding"
    case slipping
    case rebuilding = "returning"
}

struct WidgetIdentityStateSummary: Equatable {
    let state: WidgetHabitIdentityState
    let shortLabel: String
    let insightLine: String
    let recentCompletionText: String
}

struct WidgetHeatmapDay: Equatable {
    let date: Date
    let intensity: Int
}

enum WidgetFocusState {
    case noHabits
    case allComplete(primaryHabit: WidgetHabit, completedCount: Int)
    case needsAttention(WidgetHabit)
}

struct WidgetConsistencySnapshot: Equatable {
    let days: [WidgetHeatmapDay]
    let activeDayCount: Int
    let lastActiveDayIndex: Int?

    var summaryText: String {
        "\(activeDayCount)/\(days.count) days"
    }

    var hasActivity: Bool {
        activeDayCount > 0
    }
}

func selectTopWidgetHabits(
    _ habits: [WidgetHabit],
    limit: Int = 3
) -> [WidgetHabit] {
    guard !habits.isEmpty, limit > 0 else { return [] }

    let partialGoalHabits = habits
        .filter(\.isPartiallyCompleteGoalHabit)
        .sorted { lhs, rhs in
            let lhsProgress = lhs.goalProgress
            let rhsProgress = rhs.goalProgress

            if lhsProgress != rhsProgress {
                return lhsProgress > rhsProgress
            }

            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    let pendingCompletionHabits = habits
        .filter(\.isPendingCompletionHabit)
        .sorted { lhs, rhs in
            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    let openEndedNeedsAttentionHabits = habits
        .filter(\.isOpenEndedHabitWithoutActivityToday)
        .sorted { lhs, rhs in
            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    let completedHabits = habits
        .filter(\.isAlreadyAddressedHabit)
        .sorted { lhs, rhs in
            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    return Array(
        (partialGoalHabits + pendingCompletionHabits + openEndedNeedsAttentionHabits + completedHabits)
            .prefix(limit)
    )
}

func selectFocusWidgetHabit(_ habits: [WidgetHabit]) -> WidgetHabit? {
    guard !habits.isEmpty else { return nil }

    let incompleteHabits = habits.filter { !$0.hasActivityToday }
    guard !incompleteHabits.isEmpty else { return nil }

    let streakProtectionHabits = incompleteHabits
        .filter { $0.streak > 0 }
        .sorted { lhs, rhs in
            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    if let focusHabit = streakProtectionHabits.first {
        return focusHabit
    }

    return incompleteHabits.first
}

func resolveFocusWidgetState(_ habits: [WidgetHabit]) -> WidgetFocusState {
    guard !habits.isEmpty else { return .noHabits }

    if habits.allSatisfy(\.hasActivityToday), let primaryHabit = habits.first {
        return .allComplete(primaryHabit: primaryHabit, completedCount: habits.count)
    }

    if let focusHabit = selectFocusWidgetHabit(habits) {
        return .needsAttention(focusHabit)
    }

    if let primaryHabit = habits.first {
        return .allComplete(primaryHabit: primaryHabit, completedCount: habits.count)
    }

    return .noHabits
}

func makeWidgetConsistencySnapshot(
    from habits: [WidgetHabit],
    referenceDate: Date,
    calendar: Calendar = .current
) -> WidgetConsistencySnapshot {
    let today = calendar.startOfDay(for: referenceDate)
    let sourceDays = (0..<7).compactMap { offset -> (date: Date, total: Double)? in
        guard let date = calendar.date(byAdding: .day, value: -6 + offset, to: today) else {
            return nil
        }

        let total = habits.reduce(0.0) { partialResult, habit in
            partialResult + habit.widgetActivityValue(on: date, calendar: calendar)
        }

        return (date: date, total: max(total, 0))
    }

    let maximum = sourceDays.map(\.total).max() ?? 0
    let normalizedDays = sourceDays.map { day in
        WidgetHeatmapDay(
            date: day.date,
            intensity: normalizedConsistencyIntensity(for: day.total, maximum: maximum)
        )
    }
    let activeDayCount = normalizedDays.filter { $0.intensity > 0 }.count

    return WidgetConsistencySnapshot(
        days: normalizedDays,
        activeDayCount: activeDayCount,
        lastActiveDayIndex: normalizedDays.lastIndex(where: { $0.intensity > 0 })
    )
}

private extension WidgetHabit {
    var isPartiallyCompleteGoalHabit: Bool {
        goalType == .goal && goalProgress > 0 && goalProgress < 1
    }

    var isPendingCompletionHabit: Bool {
        switch goalType {
        case .binary:
            return !isCompleteToday
        case .goal:
            return goalProgress == 0
        case .openEnded:
            return false
        }
    }

    var isOpenEndedHabitWithoutActivityToday: Bool {
        goalType == .openEnded && !hasActivityToday
    }

    var isAlreadyAddressedHabit: Bool {
        switch goalType {
        case .binary:
            return isCompleteToday
        case .goal:
            return goalProgress >= 1
        case .openEnded:
            return hasActivityToday
        }
    }

    func widgetActivityValue(
        on date: Date,
        calendar: Calendar
    ) -> Double {
        let day = calendar.startOfDay(for: date)
        return recentActivity.first(where: {
            calendar.isDate($0.date, inSameDayAs: day)
        })?.value ?? 0
    }

}

extension WidgetHabit {
    var identityStateSummary: WidgetIdentityStateSummary {
        WidgetIdentityStateSummary(
            state: identityState,
            shortLabel: CadenceCopyCatalog.shortLabel(for: identityState.cadenceStateKey),
            insightLine: CadenceCopyCatalog.insightLine(for: identityState.cadenceStateKey),
            recentCompletionText: "\(recentCompletionCount(days: 7)) of last 7 days"
        )
    }

    func recentCompletionCount(days: Int) -> Int {
        let sorted = recentActivity.sorted { $0.date > $1.date }
        return Array(sorted.prefix(max(days, 0))).reduce(0) { count, sample in
            count + (sample.value > 0 ? 1 : 0)
        }
    }
}

private extension WidgetHabitIdentityState {
    var cadenceStateKey: CadenceStateKey {
        switch self {
        case .gettingStarted:
            return .gettingStarted
        case .building:
            return .building
        case .steady:
            return .steady
        case .strong:
            return .strong
        case .slipping:
            return .slipping
        case .rebuilding:
            return .rebuilding
        }
    }
}

extension WidgetFocusState {
    var titleText: String {
        switch self {
        case .noHabits:
            return "No habits yet"
        case .allComplete:
            return "All done"
        case .needsAttention(let habit):
            return habit.name
        }
    }

    var subtitleText: String {
        switch self {
        case .noHabits:
            return "Add a habit"
        case .allComplete(_, let completedCount):
            return "\(completedCount) completed today"
        case .needsAttention(let habit):
            return habit.streak == 0 ? "Log today" : "Keep \(habit.streak)-day streak"
        }
    }
}

private func normalizedConsistencyIntensity(for total: Double, maximum: Double) -> Int {
    guard total > 0, maximum > 0 else { return 0 }
    return max(1, min(4, Int(ceil((total / maximum) * 4))))
}

enum WidgetHabitLogger {
    static let logger = Logger(subsystem: "ma.Habits", category: "WidgetHabit")

    static func log(
        context: StaticString,
        habitName: String,
        goalType: WidgetGoalType,
        progress: Double?
    ) {
        logger.debug(
            "\(context, privacy: .public) habit=\(habitName, privacy: .public) goalType=\(String(describing: goalType), privacy: .public) progress=\(String(describing: progress), privacy: .public)"
        )
    }

    static func logCompactSummary(
        habitName: String,
        goalType: WidgetGoalType,
        progress: Double?
    ) {
        let progressText = progress.map { String(format: "%.1f", $0) } ?? "nil"
        logger.debug(
            "\(habitName, privacy: .public) \(goalType.rawValue, privacy: .public) \(progressText, privacy: .public)"
        )
    }

    static func logValidationFailure(
        habitName: String,
        reason: String
    ) {
        logger.error(
            "Widget payload validation failure for \(habitName, privacy: .public): \(reason, privacy: .public)"
        )
    }

    static func logStorageFailure(
        context: StaticString,
        reason: String
    ) {
        logger.error(
            "Widget storage failure \(context, privacy: .public): \(reason, privacy: .public)"
        )
    }

    static func logWidgetWrite(count: Int) {
        logger.debug("WIDGET WRITE: \(count, privacy: .public) habits saved")
    }

    static func logWidgetRead(count: Int) {
        logger.debug("WIDGET READ: \(count, privacy: .public) habits loaded")
    }
}
