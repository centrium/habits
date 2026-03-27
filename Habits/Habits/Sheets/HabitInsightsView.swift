import SwiftUI

struct HabitInsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
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
            greigModeEnabled: userSettings.greigModeEnabled,
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
        .background(colorScheme == .light ? Color.appBackground : Color.appGroupedBackground)
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
                withAnimation(AppMotion.reveal) {
                    hasAnimatedIn = true
                }
            }
        }
    }
}

private struct HabitInsightsCardsRenderer: View {
    let viewModel: HabitInsightsViewModel
    let accent: Color
    let hasAnimatedIn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 14)
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 6)
                .animation(AppMotion.reveal, value: hasAnimatedIn)

            VStack(spacing: 16) {
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
                    HabitInsightsPanel(background: Color.appTertiaryGroupedBackground) {
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
                    .animation(AppMotion.reveal.delay(0.15), value: hasAnimatedIn)
                }
            }
        }
    }

    private var renderRows: [HabitInsightsRenderRow] {
        var rows: [HabitInsightsRenderRow] = []
        var index = 0

        while index < viewModel.cards.count {
            let card = viewModel.cards[index]
            if case .achievement(let achievement) = card,
               index + 1 < viewModel.cards.count,
               case .momentum(let momentum) = viewModel.cards[index + 1] {
                rows.append(.paired(achievement, momentum))
                index += 2
                continue
            }

            rows.append(.single(card))
            index += 1
        }

        return rows
    }

    @ViewBuilder
    private func rowView(_ row: HabitInsightsRenderRow) -> some View {
        switch row {
        case .single(let card):
            cardView(card)
        case .paired(let achievement, let momentum):
            HStack(alignment: .top, spacing: 16) {
                AchievementCardView(block: achievement, accent: accent, minHeight: 210)
                    .frame(maxWidth: .infinity)
                MomentumCardView(block: momentum, minHeight: 210)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func cardView(_ card: HabitInsightsCard) -> some View {
        switch card {
        case .overview(let block):
            OverviewCardView(block: block)
        case .achievement(let block):
            AchievementCardView(block: block, accent: accent)
        case .goalPace(let block):
            GoalPaceCardView(block: block, accent: accent, hasAnimatedIn: hasAnimatedIn)
        case .momentum(let block):
            MomentumCardView(block: block)
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
    case paired(HabitInsightsAchievementBlock, HabitInsightsMomentumBlock)
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

private struct MomentumCardView: View {
    let block: HabitInsightsMomentumBlock
    var minHeight: CGFloat? = nil

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Momentum")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(block.score)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(block.momentumLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(block.currentStreakText)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 6) {
                    if !block.longestStreakText.isEmpty {
                        Text(block.longestStreakText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if minHeight == nil {
                        Text(block.paceText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(block.supportingText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: minHeight, alignment: .topLeading)
        }
    }
}

private struct PerformanceSignalsCardView: View {
    let block: HabitInsightsPerformanceSignalsBlock

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 18) {
                Text(block.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(block.signals) { signal in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(signal.gauge.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        GradientGaugeView(
                            value: signal.gauge.value,
                            labels: signal.gauge.labels,
                            valueText: signal.displayValue
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
}

private struct OverviewCardView: View {
    let block: HabitInsightsOverviewBlock

    private let columns = [
        GridItem(.flexible(minimum: 120), spacing: 14, alignment: .leading),
        GridItem(.flexible(minimum: 120), spacing: 14, alignment: .leading)
    ]

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Overview")
                    .font(.headline)
                    .foregroundStyle(.primary)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    OverviewMetricCell(
                        title: "Consistency",
                        value: "\(block.consistency)%"
                    )
                    OverviewMetricCell(
                        title: "Best Month",
                        value: block.bestMonth
                    )
                    OverviewMetricCell(
                        title: "Most Missed Day",
                        value: block.mostMissedDay
                    )
                    OverviewMetricCell(
                        title: "Average Streak",
                        value: "\(block.averageStreak) \(block.averageStreak == 1 ? "day" : "days")"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct OverviewMetricCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var toneColor: Color {
        accent
    }

    var body: some View {
        HabitInsightsPanel(
            backgroundStyle: AnyShapeStyle(
                LinearGradient(
                    colors: [toneColor.opacity(0.18), toneColor.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        ) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: block.iconName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(accent)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Coaching")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(block.headline)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
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

    private var maxEntries: Int {
        max(block.days.map(\.entries).max() ?? 0, 1)
    }

    var body: some View {
        HabitInsightsPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(block.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(block.days.enumerated()), id: \.element.id) { idx, day in
                        VStack(spacing: 7) {
                            ZStack(alignment: .top) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(dayColor(for: day))
                                    .frame(width: barWidth, height: barHeight(for: day))
                                    .scaleEffect(y: hasAnimatedIn ? 1 : 0, anchor: .bottom)
                                    .animation(.easeOut(duration: 0.5).delay(0.03 * Double(idx)), value: hasAnimatedIn)
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
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for day: HabitInsightsWeeklyRhythmDay) -> CGFloat {
        if day.entries == 0 {
            return 10
        }
        return max(12, CGFloat(Double(day.entries) / Double(maxEntries)) * (chartHeight - 14))
    }

    private func dayColor(for day: HabitInsightsWeeklyRhythmDay) -> Color {
        guard day.entries > 0 else {
            return accent.opacity(0.25)
        }
        let ratio = Double(day.entries) / Double(maxEntries)
        if ratio >= 0.85 {
            return accent
        }
        if ratio >= 0.5 {
            return accent.opacity(0.7)
        }
        return accent.opacity(0.4)
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
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(block.observations, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                Text(block.suggestion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            return "High confidence"
        case .medium:
            return "Moderate confidence"
        case .low:
            return "Low confidence"
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
                        .font(.headline)
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
                            .foregroundStyle(.primary)
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
        HabitInsightsPanel(background: Color.appTertiaryGroupedBackground) {
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
                        accent: Color(hex: scenario.habit.colorHex),
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
