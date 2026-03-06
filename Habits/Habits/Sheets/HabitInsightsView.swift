import SwiftUI

struct HabitInsightsView: View {
    let habit: Habit
    let logAnchorDate: Date?

    init(habit: Habit, logAnchorDate: Date? = nil) {
        self.habit = habit
        self.logAnchorDate = logAnchorDate
    }

    @EnvironmentObject private var userSettings: UserSettings
    @State private var hasAnimatedIn = false

    private var accent: Color {
        Color(hex: habit.colorHex)
    }

    private var insights: HabitInsightsViewModel {
        HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: logAnchorDate,
            calendar: .current,
            weekStartPreference: userSettings.weekStartPreference,
            now: .now
        )
    }

    var body: some View {
        ScrollView {
            HabitInsightsCardsRenderer(
                viewModel: insights,
                accent: accent,
                hasAnimatedIn: hasAnimatedIn
            )
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(insights.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DismissButton()
            }
        }
        .onAppear {
            hasAnimatedIn = false
            DispatchQueue.main.async {
                hasAnimatedIn = true
            }
        }
    }
}

private struct HabitInsightsCardsRenderer: View {
    let viewModel: HabitInsightsViewModel
    let accent: Color
    let hasAnimatedIn: Bool

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                cardView(card)
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .offset(y: hasAnimatedIn ? 0 : 8)
                    .animation(
                        .easeOut(duration: 0.24).delay(0.02 * Double(index)),
                        value: hasAnimatedIn
                    )
            }

            if !viewModel.notes.isEmpty {
                HabitInsightsPanel(background: Color(.tertiarySystemGroupedBackground)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.notes, id: \.self) { note in
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 8)
                .animation(.easeOut(duration: 0.24).delay(0.15), value: hasAnimatedIn)
            }
        }
    }

    @ViewBuilder
    private func cardView(_ card: HabitInsightsCard) -> some View {
        switch card {
        case .achievement(let block):
            AchievementCardView(block: block, accent: accent)
        case .momentum(let block):
            MomentumCardView(block: block)
        case .consistency(let block):
            ConsistencyCardView(block: block)
        case .hero(let block):
            HeroCardView(block: block, accent: accent)
        case .motivation(let block):
            MotivationCardView(block: block)
        case .intent(let block):
            IntentCardView(block: block)
        case .trend(let block):
            TrendCardView(block: block, accent: accent)
        case .completionHistory(let block):
            CompletionHistoryCardView(block: block)
        case .patterns(let block):
            PatternCardView(block: block)
        case .retention(let block):
            RetentionCardView(block: block)
        case .debug(let block):
            DebugCardView(block: block)
        }
    }
}

private struct AchievementCardView: View {
    let block: HabitInsightsAchievementBlock
    let accent: Color

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Achievement")
                    .font(.headline)
                Text(block.progressText)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(accent)
                    .monospacedDigit()
                Text(block.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let overflowText = block.overflowText {
                    Text(overflowText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(max(block.progressRatio, 0), 1))
                    .tint(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MomentumCardView: View {
    let block: HabitInsightsMomentumBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Momentum")
                    .font(.headline)
                Text(block.currentStreakText)
                    .font(.subheadline.weight(.semibold))
                Text(block.longestStreakText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(block.paceText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ConsistencyCardView: View {
    let block: HabitInsightsConsistencyBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Consistency")
                    .font(.headline)
                Text(block.scoreText)
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                if let averageText = block.averageText {
                    Text(averageText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HeroCardView: View {
    let block: HabitInsightsHeroBlock
    let accent: Color

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text(block.heading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(block.valueText)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(accent)
                    .monospacedDigit()

                Text(block.periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let status = block.statusText {
                    Text(status)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if let surplus = block.surplusText {
                    Text(surplus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let comparison = block.comparisonText {
                    Text(comparison)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct IntentCardView: View {
    let block: HabitInsightsIntentBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(block.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(block.primaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let secondary = block.secondaryText {
                    Text(secondary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(block.projectionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MotivationCardView: View {
    let block: MotivationCard

    private var toneColor: Color {
        switch block.tone {
        case .encouragement:
            return .blue
        case .celebration:
            return .green
        case .nudge:
            return .orange
        }
    }

    var body: some View {
        HabitInsightsPanel(background: toneColor.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(block.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TrendCardView: View {
    let block: HabitInsightsTrendBlock
    let accent: Color

    private let chartHeight: CGFloat = 86
    private let barSpacing: CGFloat = 5

    private var maxValue: Double {
        get {
            if block.isCompletionRatioBars {
                return 1
            }
            return max(block.points.map(\.value).max() ?? 1, block.targetLine ?? 0, 1)
        }
    }

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(block.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)

                GeometryReader { geometry in
                    let barCount = CGFloat(max(block.points.count, 1))
                    let totalSpacing = barSpacing * max(barCount - 1, 0)
                    let width = max(4, (geometry.size.width - totalSpacing) / barCount)

                    ZStack(alignment: .bottomLeading) {
                        if let target = block.targetLine {
                            let targetY = min(CGFloat(target / maxValue), 1)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.14))
                                .frame(height: 1)
                                .offset(y: -targetY * chartHeight)
                        }

                        HStack(alignment: .bottom, spacing: barSpacing) {
                            ForEach(block.points) { point in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(point.value > 0 ? accent.opacity(0.8) : Color.secondary.opacity(0.15))
                                    .frame(width: width, height: barHeight(for: point.value))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: chartHeight)

                HStack(spacing: barSpacing) {
                    ForEach(block.points) { point in
                        Text(shortLabel(point.label))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                if let unit = block.unitText, block.isValueBased {
                    Text("Unit: \(unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let insight = block.insightText {
                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func barHeight(for value: Double) -> CGFloat {
        if block.isCompletionRatioBars {
            if value >= 1 {
                return chartHeight
            }
            if value > 0 {
                return max(12, min(CGFloat(value), 1) * chartHeight)
            }
            return 6
        }

        return max(6, CGFloat(value / maxValue) * chartHeight)
    }

    private func shortLabel(_ raw: String) -> String {
        let split = raw.split(separator: " ")
        return String(split.first ?? Substring(raw))
    }
}

private struct CompletionHistoryCardView: View {
    let block: HabitInsightsCompletionHistoryBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 9) {
                Text(block.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(block.completionRateText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text(block.streakText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let longest = block.longestStreakText {
                    Text(longest)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PatternCardView: View {
    let block: HabitInsightsPatternBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(block.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(block.items, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RetentionCardView: View {
    let block: HabitInsightsRetentionBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(block.heading)
                    .font(.headline)
                ForEach(block.items, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DebugCardView: View {
    let block: HabitInsightsDebugBlock

    var body: some View {
        HabitInsightsPanel(background: Color(.tertiarySystemGroupedBackground)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(block.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(block.lines, id: \.self) { line in
                    Text(line)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
private struct HabitInsightsPreviewScenario: Identifiable {
    let id: String
    let title: String
    let habit: Habit

    static func all(referenceDate: Date, calendar: Calendar) -> [HabitInsightsPreviewScenario] {
        [
            makeScenario(
                id: "daily-frequency",
                title: "Daily Frequency",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .daily,
                goalType: .frequency,
                hasGoal: true
            ),
            makeScenario(
                id: "weekly-frequency",
                title: "Weekly Frequency",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .weekly,
                goalType: .frequency,
                hasGoal: true
            ),
            makeScenario(
                id: "monthly-frequency",
                title: "Monthly Frequency",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .monthly,
                goalType: .frequency,
                hasGoal: true
            ),
            makeScenario(
                id: "yearly-frequency",
                title: "Yearly Frequency",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .yearly,
                goalType: .frequency,
                hasGoal: true
            ),
            makeScenario(
                id: "daily-cumulative",
                title: "Daily Cumulative",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .daily,
                goalType: .cumulative,
                hasGoal: true
            ),
            makeScenario(
                id: "weekly-cumulative",
                title: "Weekly Cumulative",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .weekly,
                goalType: .cumulative,
                hasGoal: true
            ),
            makeScenario(
                id: "monthly-cumulative",
                title: "Monthly Cumulative",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .monthly,
                goalType: .cumulative,
                hasGoal: true
            ),
            makeScenario(
                id: "yearly-cumulative",
                title: "Yearly Cumulative",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .yearly,
                goalType: .cumulative,
                hasGoal: true
            ),
            makeScenario(
                id: "daily-open",
                title: "Daily Open",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .daily,
                goalType: .frequency,
                hasGoal: false
            ),
            makeScenario(
                id: "weekly-open",
                title: "Weekly Open",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .weekly,
                goalType: .frequency,
                hasGoal: false
            ),
            makeScenario(
                id: "monthly-open",
                title: "Monthly Open",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .monthly,
                goalType: .frequency,
                hasGoal: false
            ),
            makeScenario(
                id: "yearly-open",
                title: "Yearly Open",
                referenceDate: referenceDate,
                calendar: calendar,
                goalPeriod: .yearly,
                goalType: .frequency,
                hasGoal: false
            )
        ]
    }

    private static func makeScenario(
        id: String,
        title: String,
        referenceDate: Date,
        calendar: Calendar,
        goalPeriod: GoalPeriod,
        goalType: GoalType,
        hasGoal: Bool
    ) -> HabitInsightsPreviewScenario {
        let createdAt = calendar.date(byAdding: .month, value: -6, to: referenceDate) ?? referenceDate
        let habit = Habit(
            name: title,
            colorHex: "#22A699",
            hasStreakGoal: hasGoal,
            goalPeriod: goalPeriod,
            goalType: goalType,
            streakTarget: goalType == .frequency ? 7 : 1,
            targetValue: goalType == .cumulative ? 20 : nil,
            unit: goalType == .cumulative ? "km" : nil,
            allowsDecimals: goalType == .cumulative,
            createdAt: createdAt
        )

        seedLogs(
            for: habit,
            goalPeriod: goalPeriod,
            goalType: goalType,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return HabitInsightsPreviewScenario(id: id, title: title, habit: habit)
    }

    private static func seedLogs(
        for habit: Habit,
        goalPeriod: GoalPeriod,
        goalType: GoalType,
        referenceDate: Date,
        calendar: Calendar
    ) {
        for dayOffset in 0..<120 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let shouldLog = weekday == 2 || weekday == 4 || weekday == 6
            guard shouldLog else { continue }

            if goalType == .frequency {
                habit.log(on: day, amount: 1, calendar: calendar)
                if dayOffset % 11 == 0 {
                    habit.log(on: day, amount: 1, calendar: calendar)
                }
            } else {
                let value = dayOffset % 9 == 0 ? 4.5 : 2.1
                habit.logValue(on: day, value: value, calendar: calendar)
            }
        }
    }
}

#Preview("Insights Debug Harness") {
    let calendar = Calendar.autoupdatingCurrent
    let referenceDate = Date()
    let scenarios = HabitInsightsPreviewScenario.all(referenceDate: referenceDate, calendar: calendar)

    return ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(scenarios) { scenario in
                VStack(alignment: .leading, spacing: 10) {
                    Text(scenario.title)
                        .font(.headline)
                        .padding(.horizontal, 20)

                    let model = HabitInsightsEngine.insights(
                        for: scenario.habit,
                        logAnchorDate: referenceDate,
                        calendar: calendar,
                        weekStartPreference: .monday,
                        now: referenceDate
                    )

                    HabitInsightsCardsRenderer(
                        viewModel: model,
                        accent: Color(hex: scenario.habit.colorHex),
                        hasAnimatedIn: true
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 20)
    }
    .background(Color(.systemGroupedBackground))
}
#endif
