import SwiftUI
import SwiftData

struct HabitInsightsView: View {
    let habit: Habit
    let logAnchorDate: Date?

    init(habit: Habit, logAnchorDate: Date? = nil) {
        self.habit = habit
        self.logAnchorDate = logAnchorDate
    }

    @EnvironmentObject private var userSettings: UserSettings
    @State private var hasAnimatedIn = false
    @State private var insightsViewModel: HabitInsightsViewModel?
    @State private var hasLoadedSnapshot = false
    @State private var isViewActive = false
    @State private var insightsRequestSequence: UInt64 = 0
    @State private var insightsRefreshTask: Task<Void, Never>?

    private var accent: Color { habit.curatedColorVariants.strong }

    var body: some View {
        let title = insightsViewModel?.title ?? "Insights"
        ZStack {
            CadenceTokens.Color.Background.primary
                .ignoresSafeArea()

            ScrollView {
                if let insightsViewModel {
                    HabitInsightsCardsRenderer(
                        viewModel: insightsViewModel,
                        accent: accent,
                        hasAnimatedIn: hasAnimatedIn
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 26)
                    .padding(.bottom, 40)
                } else {
                    ProgressView()
                        .padding(.top, 40)
                }
            }
            .cadenceSurface(
                accent: Color.systemAccent,
                accentKey: "habit-insights-brand-ambient"
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DismissButton()
            }
        }
        .onAppear {
            isViewActive = true
            if !hasLoadedSnapshot {
                hasLoadedSnapshot = true
                refreshInsightsSnapshot()
            }
            hasAnimatedIn = false
            DispatchQueue.main.async {
                withAnimation(AppMotion.reveal) {
                    hasAnimatedIn = true
                }
            }
        }
        .onDisappear {
            isViewActive = false
            hasLoadedSnapshot = false
            insightsRefreshTask?.cancel()
            insightsRefreshTask = nil
        }
    }

    private struct InsightsSnapshotInput {
        let habit: Habit
        let logAnchorDate: Date?
        let globalLogs: [HabitLog]
        let calendar: Calendar
        let weekStartPreference: WeekStartPreference
        let greigModeEnabled: Bool
        let timezone: TimeZone
        let now: Date
    }

    private func refreshInsightsSnapshot() {
        insightsRefreshTask?.cancel()
        insightsRequestSequence &+= 1
        let requestSequence = insightsRequestSequence
        let snapshotInput = makeSnapshotInput()

        insightsRefreshTask = Task(priority: .userInitiated) {
            let result = await computeInsightsOffMain(from: snapshotInput)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard isViewActive else { return }
                guard insightsRequestSequence == requestSequence else { return }
                guard !Task.isCancelled else { return }
                withTransaction(Transaction(animation: nil)) {
                    insightsViewModel = result
                }
                insightsRefreshTask = nil
            }
        }
    }

    private func makeSnapshotInput() -> InsightsSnapshotInput {
        var calendar = Calendar.current
        let timezone = calendar.timeZone
        calendar.timeZone = timezone

        return InsightsSnapshotInput(
            habit: detachedHabitCopy(from: habit, calendar: calendar),
            logAnchorDate: logAnchorDate,
            globalLogs: [],
            calendar: calendar,
            weekStartPreference: userSettings.weekStartPreference,
            greigModeEnabled: userSettings.greigModeEnabled,
            timezone: timezone,
            now: .now
        )
    }

    private func computeInsightsOffMain(from input: InsightsSnapshotInput) async -> HabitInsightsViewModel {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let model = HabitInsightsEngine.insights(
                    for: input.habit,
                    logAnchorDate: input.logAnchorDate,
                    globalLogs: input.globalLogs,
                    calendar: input.calendar,
                    weekStartPreference: input.weekStartPreference,
                    greigModeEnabled: input.greigModeEnabled,
                    timezone: input.timezone,
                    now: input.now
                )
                continuation.resume(returning: model)
            }
        }
    }

    private func detachedHabitCopy(from habit: Habit, calendar: Calendar) -> Habit {
        let detachedHabit = Habit(
            name: habit.name,
            colorHex: habit.colorHex,
            identity: habit.identity,
            category: habit.category,
            subtitle: habit.subtitle,
            iconName: habit.iconName,
            hasStreakGoal: habit.hasStreakGoal,
            goalPeriod: habit.goalPeriod,
            goalType: habit.goalType,
            streakTarget: habit.streakTarget,
            targetValue: habit.targetValue,
            unit: habit.unit,
            allowsDecimals: habit.allowsDecimals,
            createdAt: habit.createdAt,
            orderIndex: habit.orderIndex,
            triggerHabitID: habit.triggerHabitID,
            cueText: habit.cueText,
            cueSourceHabitId: habit.cueSourceHabitId,
            cueType: habit.cueTypeValue
        )
        detachedHabit.id = habit.id
        detachedHabit.logs = detachedLogsCopy(from: habit.logs, calendar: calendar)
        return detachedHabit
    }

    private func detachedLogsCopy(from logs: [HabitLog], calendar: Calendar) -> [HabitLog] {
        logs.map { log in
            let copy: HabitLog
            switch log.kind {
            case .entry:
                copy = HabitLog(
                    timestamp: log.effectiveTimestamp,
                    value: log.numericValue,
                    createdAt: log.createdAt,
                    calendar: calendar
                )
            case .legacyDailyTotal:
                copy = HabitLog(
                    day: log.day,
                    count: log.count,
                    createdAt: log.createdAt,
                    calendar: calendar
                )
            }

            copy.id = log.id
            copy.day = log.day
            copy.count = log.count
            copy.timestamp = log.timestamp
            copy.value = log.value
            copy.logKindRaw = log.logKindRaw
            copy.createdAt = log.createdAt
            return copy
        }
    }
}

private struct HabitInsightsCardsRenderer: View {
    let viewModel: HabitInsightsViewModel
    let accent: Color
    let hasAnimatedIn: Bool

    var body: some View {
        VStack(spacing: 22) {
            ForEach(Array(renderRows.enumerated()), id: \.offset) { index, row in
                rowView(row)
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .offset(y: hasAnimatedIn ? 0 : 8)
                    .animation(
                        AppMotion.reveal.delay(0.02 * Double(index)),
                        value: hasAnimatedIn
                    )
            }

            if !viewModel.notes.isEmpty {
                HabitInsightsPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.notes, id: \.self) { note in
                            Text(note)
                                .font(CadenceTokens.Typography.microCopy)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 8)
                .animation(AppMotion.reveal.delay(0.15), value: hasAnimatedIn)
            }
        }
    }

    private var renderRows: [HabitInsightsRenderRow] {
        var rows: [HabitInsightsRenderRow] = []

        if let coaching {
            rows.append(.single(.motivation(coaching)))
        }
        if let summary {
            rows.append(.single(.overview(summary)))
        }
        if let signals {
            rows.append(.single(.performanceSignals(signals)))
        }
        if weeklyRhythm != nil || behaviourInsights != nil {
            rows.append(.behaviour(weeklyRhythm, behaviourInsights))
        }
        if let greigMode {
            rows.append(.single(.greigMode(greigMode)))
        }

        return rows
    }

    @ViewBuilder
    private func rowView(_ row: HabitInsightsRenderRow) -> some View {
        switch row {
        case .single(let card):
            cardView(card)
        case .behaviour(let rhythm, let insights):
            VStack(spacing: 16) {
                if let rhythm {
                    WeeklyRhythmCardView(block: rhythm, accent: accent, hasAnimatedIn: hasAnimatedIn)
                }
                if let insights {
                    BehaviourInsightsCardView(block: insights)
                }
            }
        }
    }

    private var coaching: MotivationCard? {
        for card in viewModel.cards {
            if case .motivation(let block) = card {
                return block
            }
        }
        return nil
    }

    private var summary: HabitInsightsOverviewBlock? {
        for card in viewModel.cards {
            if case .overview(let block) = card {
                return block
            }
        }
        return nil
    }

    private var signals: HabitInsightsPerformanceSignalsBlock? {
        for card in viewModel.cards {
            if case .performanceSignals(let block) = card {
                return block
            }
        }
        return nil
    }

    private var weeklyRhythm: HabitInsightsWeeklyRhythmBlock? {
        for card in viewModel.cards {
            if case .weeklyRhythm(let block) = card {
                return block
            }
        }
        return nil
    }

    private var behaviourInsights: HabitInsightsBehaviourBlock? {
        for card in viewModel.cards {
            if case .behaviourInsights(let block) = card {
                return block
            }
        }
        return nil
    }

    private var greigMode: HabitInsightsGreigModeBlock? {
        for card in viewModel.cards {
            if case .greigMode(let block) = card {
                return block
            }
        }
        return nil
    }

    @ViewBuilder
    private func cardView(_ card: HabitInsightsCard) -> some View {
        switch card {
        case .overview(let block):
            OverviewCardView(block: block, accent: accent)
        case .achievement(let block):
            AchievementCardView(block: block, accent: accent)
        case .goalPace(let block):
            GoalPaceCardView(block: block, accent: accent, hasAnimatedIn: hasAnimatedIn)
        case .identityState(let block):
            IdentityStateCardView(block: block)
        case .performanceSignals(let block):
            PerformanceSignalsCardView(block: block)
        case .consistency(let block):
            ConsistencyCardView(block: block)
        case .hero(let block):
            HeroCardView(block: block, accent: accent)
        case .motivation(let block):
            MotivationCardView(block: block, accent: accent)
        case .intent(let block):
            IntentCardView(block: block)
        case .trend(let block):
            TrendCardView(block: block, accent: accent, hasAnimatedIn: hasAnimatedIn)
        case .weeklyRhythm(let block):
            WeeklyRhythmCardView(block: block, accent: accent, hasAnimatedIn: hasAnimatedIn)
        case .completionHistory(let block):
            CompletionHistoryCardView(block: block)
        case .behaviourInsights(let block):
            BehaviourInsightsCardView(block: block)
        case .greigMode(let block):
            GreigModeCardView(block: block, accent: accent)
        case .debug(let block):
            DebugCardView(block: block)
        }
    }
}

private enum HabitInsightsRenderRow {
    case single(HabitInsightsCard)
    case behaviour(HabitInsightsWeeklyRhythmBlock?, HabitInsightsBehaviourBlock?)
}

private struct AchievementCardView: View {
    let block: HabitInsightsAchievementBlock
    let accent: Color
    var minHeight: CGFloat? = nil

    private var clampedRatio: Double {
        min(max(block.progressRatio, 0), 1)
    }

    private var metricDisplay: AchievementMetricDisplay {
        buildMetricDisplay(from: block.progressText)
    }

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Achievement")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                RadialProgressView(
                    progress: clampedRatio,
                    accent: accent,
                    progressText: metricDisplay.ringText
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(metricDisplay.progressLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(block.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let overflowText = block.overflowText {
                        Text(overflowText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: minHeight, alignment: .topLeading)
        }
    }

    private func buildMetricDisplay(from progressText: String) -> AchievementMetricDisplay {
        let slashParts = progressText
            .split(separator: "/", maxSplits: 1)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let currencySymbols = Set(["$", "£", "€", "¥", "₹", "₩", "₽"])

        guard slashParts.count == 2 else {
            let ring = compactRingToken(from: progressText, currencySymbols: currencySymbols)
            return AchievementMetricDisplay(ringText: ring, progressLine: progressText)
        }

        let current = slashParts[0]
        let target = slashParts[1]
        let combined = current + target
        let hasCurrency = combined.contains { currencySymbols.contains(String($0)) }

        let ring = compactRingToken(from: current, currencySymbols: currencySymbols)
        let progressLine = hasCurrency ? "\(current) of \(target)" : "\(current) / \(target)"
        return AchievementMetricDisplay(ringText: ring, progressLine: progressLine)
    }

    private func compactRingToken(
        from raw: String,
        currencySymbols: Set<String>
    ) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "0" }

        let collapsed = trimmed.replacingOccurrences(of: " ", with: "")
        let first = collapsed.first.map(String.init)
        let hasCurrencyPrefix = first.map { currencySymbols.contains($0) } ?? false
        if collapsed.count <= 5 {
            return collapsed
        }

        let numeric = ringNumericToken(from: collapsed)
        if hasCurrencyPrefix, let symbol = first {
            let withSymbol = "\(symbol)\(numeric)"
            if withSymbol.count <= 5 {
                return withSymbol
            }
        }
        return numeric
    }

    private func ringNumericToken(from raw: String) -> String {
        let allowed = Set("0123456789.,")
        let cleaned = raw.filter { allowed.contains($0) }.replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned) else { return "0" }
        if value >= 1_000_000 {
            return "\(Int((value / 1_000_000).rounded()))m"
        }
        if value >= 1_000 {
            return "\(Int((value / 1_000).rounded()))k"
        }
        return normalizedMetricToken(cleaned)
    }

    private func normalizedMetricToken(_ raw: String) -> String {
        let normalized = raw.replacingOccurrences(of: ",", with: "")
        guard let value = Double(normalized) else { return "0" }
        if abs(value.rounded() - value) < 0.001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private struct AchievementMetricDisplay {
        let ringText: String
        let progressLine: String
    }
}

private struct IdentityStateCardView: View {
    let block: HabitInsightsIdentityStateBlock
    var minHeight: CGFloat? = nil

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text(CadenceLanguage.identityTitle())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(block.line)
                    .font(.subheadline)
                    .foregroundStyle(identityLineColor(for: block.state))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: minHeight, alignment: .topLeading)
        }
    }

    private func identityLineColor(for state: HabitIdentityState) -> Color {
        _ = state
        return .secondary
    }
}

private struct PerformanceSignalsCardView: View {
    let block: HabitInsightsPerformanceSignalsBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 18) {
                Text("Signals")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .opacity(0.92)

                ForEach(block.signals) { signal in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(signal.gauge.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if !signal.displayValue.isEmpty {
                            if signal.gauge.title == "Identity Signal" {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(signal.displayValue)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    if let descriptor = identitySecondaryDescriptor(for: signal.displayValue) {
                                        Text(descriptor)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .opacity(0.8)
                                    }
                                }
                            } else {
                                Text(signal.displayValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        GradientGaugeView(
                            value: signal.gauge.value,
                            labels: signal.gauge.labels,
                            emphasizeActiveZone: signal.gauge.title == "Identity Signal",
                            activeBandLabel: signal.gauge.title == "Identity Signal" ? signal.displayValue : nil,
                            calibrationProfile: calibrationProfile(for: signal.gauge.title)
                        )

                        Text(signal.gauge.explanation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func identitySecondaryDescriptor(for label: String) -> String? {
        switch label {
        case "Start":
            return "Early pattern"
        case "Build":
            return "Routine forming"
        case "Steady":
            return "Reliable pattern"
        case "Strong":
            return "Consistent pattern"
        case "Slip":
            return "Recent dip"
        case "Rebuild":
            return "Pattern reset"
        default:
            return nil
        }
    }

    private func calibrationProfile(for title: String) -> SignalMarkerCalibration.Profile {
        switch title {
        case "Identity Signal":
            return .identity
        case "Habit Risk":
            return .risk
        case "Habit Strength":
            return .strength
        default:
            return .none
        }
    }
}

private struct OverviewCardView: View {
    let block: HabitInsightsOverviewBlock
    let accent: Color

    private let columns = [
        GridItem(.flexible(minimum: 120), spacing: 14, alignment: .leading),
        GridItem(.flexible(minimum: 120), spacing: 14, alignment: .leading)
    ]

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Summary")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .opacity(0.92)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    OverviewMetricCell(
                        title: "Consistency",
                        value: "\(block.consistency)%",
                        style: .primary,
                        accent: accent
                    )
                    OverviewMetricCell(
                        title: "Average Streak",
                        value: "\(block.averageStreak) \(block.averageStreak == 1 ? "day" : "days")",
                        style: .secondary,
                        accent: accent
                    )
                    OverviewMetricCell(
                        title: "Entries this week",
                        value: "\(block.entriesThisWeek) \(block.entriesThisWeek == 1 ? "entry" : "entries")",
                        style: .secondary,
                        accent: accent
                    )
                    OverviewMetricCell(
                        title: "Best Month",
                        value: block.bestMonth,
                        style: .secondary,
                        accent: accent
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct OverviewMetricCell: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let value: String
    let style: Style
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(0.9)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(valueFont)
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var valueFont: Font {
        switch style {
        case .primary:
            return .title3.weight(.medium)
        case .secondary:
            return .title3.weight(.regular)
        }
    }

    private var valueColor: Color {
        switch style {
        case .primary:
            return accent.opacity(0.92)
        case .secondary:
            return .primary
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
                    .font(.title3.weight(.semibold))
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
                    .font(.title3.weight(.semibold))
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
    let accent: Color

    private var headlineText: AttributedString {
        let headline = block.headline
        guard let range = headline.range(of: #"\d+\s+days?\s+in\s+a\s+row"#, options: .regularExpression) else {
            var full = AttributedString(headline)
            full.foregroundColor = .primary
            return full
        }

        let prefix = String(headline[..<range.lowerBound])
        let highlighted = String(headline[range])
        let suffix = String(headline[range.upperBound...])
        var styled = AttributedString(prefix + highlighted + suffix)
        styled.foregroundColor = .primary

        if let highlightRange = styled.range(of: highlighted) {
            styled[highlightRange].foregroundColor = accent.opacity(0.74)
        }

        return styled
    }

    var body: some View {
        HabitInsightsPanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: block.iconName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(accent)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Coaching")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(headlineText)
                        .font(.headline.weight(.semibold))
                    Text(block.supportingText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TrendCardView: View {
    let block: HabitInsightsTrendBlock
    let accent: Color
    let hasAnimatedIn: Bool

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

    private var peakValue: Double {
        max(block.points.map(\.value).max() ?? 0, 0)
    }

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(block.heading)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

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
                            ForEach(Array(block.points.enumerated()), id: \.element.id) { idx, point in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(barColor(for: point))
                                    .frame(width: width, height: barHeight(for: point.value))
                                    .overlay {
                                        if isPeak(point) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.primary.opacity(0.08))
                                        }
                                    }
                                    .scaleEffect(y: hasAnimatedIn ? 1 : 0.02, anchor: .bottom)
                                    .animation(
                                        .easeOut(duration: 0.3).delay(0.02 * Double(idx)),
                                        value: hasAnimatedIn
                                    )
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
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let supporting = block.insightSupportingText {
                    Text(supporting)
                        .font(.footnote)
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

    private func barColor(for point: HabitInsightsTrendPoint) -> Color {
        guard point.value > 0 else {
            return accent.opacity(0.25)
        }

        if peakValue > 0, point.value == peakValue {
            return accent
        }

        return accent
    }

    private func isPeak(_ point: HabitInsightsTrendPoint) -> Bool {
        peakValue > 0 && point.value == peakValue
    }
}

private struct GoalPaceCardView: View {
    let block: HabitInsightsGoalPaceBlock
    let accent: Color
    let hasAnimatedIn: Bool

    private let chartHeight: CGFloat = 122

    private var maxY: Double {
        let values = block.expectedLine.map(\.y) + block.actualLine.map(\.y) + block.projectionLine.map(\.y) + [block.targetValue]
        return max(values.max() ?? 1, 1)
    }

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(block.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)

                GeometryReader { geometry in
                    let progress = hasAnimatedIn ? 1.0 : 0.0

                    ZStack(alignment: .bottomLeading) {
                        Path { path in
                            let y = yPosition(for: 0, height: geometry.size.height)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.secondary.opacity(0.14), lineWidth: 1)

                        gradientArea(in: geometry.size)
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.15), accent.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(progress)

                        linePath(points: block.expectedLine, in: geometry.size)
                            .trimmedPath(from: 0, to: progress)
                            .stroke(
                                Color.secondary.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                            )

                        linePath(points: block.actualLine, in: geometry.size)
                            .trimmedPath(from: 0, to: progress)
                            .stroke(
                                accent,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: accent.opacity(0.25), radius: 6)

                        linePath(points: block.projectionLine, in: geometry.size)
                            .trimmedPath(from: 0, to: progress)
                            .stroke(
                                accent.opacity(0.6),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4])
                            )

                        Circle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                            .position(
                                x: xPosition(for: 1, width: geometry.size.width),
                                y: yPosition(for: block.targetValue, height: geometry.size.height)
                            )

                        Text("Goal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .position(
                                x: max(20, xPosition(for: 1, width: geometry.size.width) - 18),
                                y: max(8, yPosition(for: block.targetValue, height: geometry.size.height) - 12)
                            )
                    }
                    .animation(.easeOut(duration: 0.6), value: hasAnimatedIn)
                }
                .frame(height: chartHeight)

                Text(block.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(block.targetText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func linePath(
        points: [HabitInsightsChartPoint],
        in size: CGSize
    ) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: xPosition(for: first.x, width: size.width), y: yPosition(for: first.y, height: size.height)))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: xPosition(for: point.x, width: size.width), y: yPosition(for: point.y, height: size.height)))
        }
        return path
    }

    private func gradientArea(in size: CGSize) -> Path {
        guard let first = block.actualLine.first, let last = block.actualLine.last else {
            return Path()
        }
        var path = linePath(points: block.actualLine, in: size)
        path.addLine(to: CGPoint(x: xPosition(for: last.x, width: size.width), y: yPosition(for: 0, height: size.height)))
        path.addLine(to: CGPoint(x: xPosition(for: first.x, width: size.width), y: yPosition(for: 0, height: size.height)))
        path.closeSubpath()
        return path
    }

    private func xPosition(for x: Double, width: CGFloat) -> CGFloat {
        CGFloat(min(max(x, 0), 1)) * width
    }

    private func yPosition(for y: Double, height: CGFloat) -> CGFloat {
        let normalized = min(max(y / maxY, 0), 1)
        return height - (CGFloat(normalized) * height)
    }
}

private struct WeeklyRhythmCardView: View {
    let block: HabitInsightsWeeklyRhythmBlock
    let accent: Color
    let hasAnimatedIn: Bool

    @State private var selectedDayID: Int?
    private let chartHeight: CGFloat = 116
    private let barWidth: CGFloat = 24

    private var rawMaxScore: Double {
        block.days.map(\.score).max() ?? 0
    }

    private var primaryDayID: Int? {
        guard rawMaxScore > 0 else { return nil }
        let maxDays = block.days.filter { $0.score == rawMaxScore }
        guard maxDays.count == 1 else { return nil }
        return maxDays.first?.id
    }

    private var secondaryDayIDs: Set<Int> {
        guard rawMaxScore > 0 else { return [] }
        let low = rawMaxScore * 0.7
        let high = rawMaxScore * 0.9
        return Set(
            block.days
                .filter { day in
                    let value = day.score
                    return day.id != primaryDayID && value >= low && value <= high
                }
                .map(\.id)
        )
    }

    private var lowDayIDs: Set<Int> {
        guard rawMaxScore > 0 else { return [] }
        let cutoff = rawMaxScore * 0.4
        return Set(
            block.days
                .filter { day in
                    day.score > 0 && day.score < cutoff
                }
                .map(\.id)
        )
    }

    private var secondaryClusterDayIDs: Set<Int> {
        let secondary = block.days.enumerated().filter { secondaryDayIDs.contains($0.element.id) }
        guard secondary.count >= 2 else { return [] }

        var clustered: Set<Int> = []
        for (index, day) in secondary {
            let prevIsSecondary = index > 0 && secondaryDayIDs.contains(block.days[index - 1].id)
            let nextIsSecondary = index + 1 < block.days.count && secondaryDayIDs.contains(block.days[index + 1].id)
            if prevIsSecondary || nextIsSecondary {
                clustered.insert(day.id)
            }
        }
        return clustered
    }

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(block.heading)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .opacity(0.92)

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(block.days.enumerated()), id: \.element.id) { idx, day in
                        VStack(spacing: 7) {
                            ZStack(alignment: .top) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(dayColor(for: day))
                                    .frame(width: barWidth, height: barHeight(for: day))
                                    .scaleEffect(y: hasAnimatedIn ? 1 : 0, anchor: .bottom)
                                    .shadow(
                                        color: isPrimary(day) ? accent.opacity(0.09) : .clear,
                                        radius: isPrimary(day) ? 3 : 0,
                                        x: 0,
                                        y: isPrimary(day) ? 1 : 0
                                    )
                                    .animation(barAnimation(for: day, index: idx), value: hasAnimatedIn)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeOut(duration: 0.18)) {
                                            selectedDayID = selectedDayID == day.id ? nil : day.id
                                        }
                                    }

                                if selectedDayID == day.id {
                                    Text("\(day.fullDayLabel)\n\(day.entries) \(day.entries == 1 ? "entry" : "entries")")
                                        .font(.footnote)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .offset(y: -56)
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                        .zIndex(1)
                                }
                            }
                            .frame(height: chartHeight, alignment: .bottom)

                            Text(day.dayLabel)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .opacity(labelOpacity(for: day))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for day: HabitInsightsWeeklyRhythmDay) -> CGFloat {
        if day.score == 0 {
            return 10
        }
        let minimumNonZeroHeight = chartHeight * 0.12
        let normalized = min(max(day.score, 0), 1)
        let proportionalHeight = CGFloat(normalized) * (chartHeight - 14)
        return max(minimumNonZeroHeight, proportionalHeight)
    }

    private func dayColor(for day: HabitInsightsWeeklyRhythmDay) -> Color {
        guard day.entries > 0 else {
            return accent.opacity(0.22)
        }
        if isPrimary(day) {
            return accent
        }
        if secondaryDayIDs.contains(day.id) {
            return accent.opacity(secondaryClusterDayIDs.contains(day.id) ? 0.78 : 0.72)
        }
        if lowDayIDs.contains(day.id) {
            return accent.opacity(0.24)
        }
        return accent.opacity(0.5)
    }

    private func isPrimary(_ day: HabitInsightsWeeklyRhythmDay) -> Bool {
        primaryDayID == day.id
    }

    private func labelOpacity(for day: HabitInsightsWeeklyRhythmDay) -> Double {
        if isPrimary(day) {
            return 0.95
        }
        if secondaryDayIDs.contains(day.id) {
            return 0.7
        }
        return 0.52
    }

    private func barAnimation(for day: HabitInsightsWeeklyRhythmDay, index: Int) -> Animation {
        let duration = isPrimary(day) ? 0.56 : 0.46
        let baseDelay = 0.03 * Double(index)
        let primaryLag = isPrimary(day) ? 0.03 : 0
        return .easeOut(duration: duration).delay(baseDelay + primaryLag)
    }
}

private struct RadialProgressView: View {
    let progress: Double
    let accent: Color
    let progressText: String

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.15), lineWidth: 6)

            Circle()
                .trim(from: 0, to: min(max(animatedProgress, 0), 1))
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(progressText)
                .font(.title3.weight(.bold))
                .foregroundStyle(accent)
                .monospacedDigit()
                .minimumScaleFactor(0.60)
                .lineLimit(1)
        }
        .frame(width: 112, height: 112)
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.35)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.35)) {
                animatedProgress = newValue
            }
        }
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

private struct BehaviourInsightsCardView: View {
    let block: HabitInsightsBehaviourBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(block.heading)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .opacity(0.92)

                ForEach(block.observations, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                Text(block.suggestion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GreigModeCardView: View {
    let block: HabitInsightsGreigModeBlock
    let accent: Color

    private var confidenceText: String {
        switch block.confidence {
        case .high:
            return "Projection signal: clear"
        case .medium:
            return "Projection signal: emerging"
        case .low:
            return "Projection signal: early"
        }
    }

    private var confidenceColor: Color {
        switch block.confidence {
        case .high:
            return Color(red: 0.26, green: 0.63, blue: 0.43)
        case .medium:
            return Color(red: 0.75, green: 0.54, blue: 0.24)
        case .low:
            return Color(red: 0.74, green: 0.35, blue: 0.34)
        }
    }

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(block.heading)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("beta")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
                .padding(.bottom, 7)

                HStack(spacing: 6) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 6, height: 6)

                    Text(confidenceText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: block.iconName)
                        .font(.title3)
                        .foregroundStyle(accent)
                        .opacity(0.9)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(block.headline)
                            .font(.body)
                            .foregroundStyle(accent.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(block.supportText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DebugCardView: View {
    let block: HabitInsightsDebugBlock

    var body: some View {
        HabitInsightsPanel {
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
            colorHex: HabitColor.teal.hex,
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

    ScrollView {
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
                        accent: scenario.habit.curatedColorVariants.strong,
                        hasAnimatedIn: true
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 20)
    }
    .background(Color.appGroupedBackground)
}
#endif
