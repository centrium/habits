import SwiftUI

struct RhythmCardView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme

    let isPremium: Bool
    let data: [HourValue]
    let rhythm: HabitRhythm?
    let computedState: HabitComputedState?
    let stateModel: HabitStateModel?
    let identitySnapshot: HabitIdentityStateSnapshot?
    let habit: Habit
    var onUnlock: (() -> Void)? = nil
    var onOpen: (() -> Void)? = nil

    @State private var selectedHour: Int?
    @State private var isTimingStrengthInfoPresented = false

    init(
        isPremium: Bool,
        data: [HourValue],
        rhythm: HabitRhythm?,
        computedState: HabitComputedState? = nil,
        stateModel: HabitStateModel?,
        identitySnapshot: HabitIdentityStateSnapshot?,
        habit: Habit,
        onUnlock: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil
    ) {
        self.isPremium = isPremium
        self.data = data
        self.rhythm = rhythm
        self.computedState = computedState
        self.stateModel = stateModel
        self.identitySnapshot = identitySnapshot
        self.habit = habit
        self.onUnlock = onUnlock
        self.onOpen = onOpen
    }

    private var resolvedInsight: TimeInsightResult {
        if let existing = rhythm?.timeInsight {
            return existing
        }
        return fallbackInsightFromData
    }

    private var fallbackInsightFromData: TimeInsightResult {
        let values = (0..<24).map { hour in
            data.first(where: { $0.hour == hour })?.value ?? 0
        }
        let peakHour = values.enumerated().max { lhs, rhs in
            if lhs.element == rhs.element { return lhs.offset > rhs.offset }
            return lhs.element < rhs.element
        }?.offset ?? 0
        if values.allSatisfy({ $0 == 0 }) {
            return TimeInsightResult(
                hourlyScores: values,
                peakHour: peakHour,
                confidence: 0,
                distributionShape: .flat
            )
        }
        return TimeInsightResult(
            hourlyScores: values,
            peakHour: peakHour,
            confidence: 0,
            distributionShape: .flat
        )
    }

    private var accent: Color {
        semanticAccent.cadenceAccentPrimary
    }

    private var semanticAccent: CadenceSemanticAccentTokens {
        CadenceTokens.Color.semanticAccent(for: habit, colorScheme: colorScheme)
    }

    private var selectedLabel: String? {
        guard isPremium,
              let selectedHour,
              let point = data.first(where: { $0.hour == selectedHour }) else {
            return nil
        }

        return "\(formattedTime(selectedHour)) - \(Int((point.value * 100).rounded()))% timing strength"
    }

    private var currentHour: Int {
        calendar.component(.hour, from: .now)
    }

    private var primaryInsight: String {
        timingMessage(confidence: timingConfidence)
    }

    private var passiveDetail: AttributedString {
        var text = AttributedString("Strongest window: ")
        text.foregroundColor = CadenceTokens.Color.Text.secondary

        var peak = AttributedString(formattedTime(resolvedInsight.peakHour))
        peak.foregroundColor = semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.72 : 0.64)
        text += peak

        return text
    }

    private var timingConfidence: TimingConfidence {
        if lowDataTimingGateEnabled {
            return .low
        }

        if let stateModel {
            return stateModel.timingConfidence
        }

        if let rhythm {
            let hasMatureTimingVolume = rhythm.uniqueEventCount >= 24 && rhythm.uniqueActiveDays >= 10
            if hasMatureTimingVolume, rhythm.confidence >= 0.18 {
                if rhythm.confidence < 0.55 {
                    return .medium
                }
            }
        }

        let baseConfidence = rhythm?.confidence ?? resolvedInsight.confidence
        let confidence = lowDataTimingWeight ? (baseConfidence * 0.6) : baseConfidence
        switch confidence {
        case ..<0.35:
            return .low
        case ..<0.75:
            return .medium
        default:
            return .high
        }
    }

    private func timingMessage(confidence: TimingConfidence) -> String {
        if lowDataTimingGateEnabled {
            return "Timing is still forming"
        }

        switch confidence {
        case .low:
            return "Timing is still forming"
        case .medium:
            return "Your timing is becoming more consistent"
        case .high:
            return "Your timing is consistent"
        }
    }

    private var lowDataTimingGateEnabled: Bool {
        if let computedState {
            return computedState.completionStats.validTimingSamples < 5
        }
        return (identitySnapshot?.uniqueDays ?? 0) < 5
    }

    private var lowDataTimingWeight: Bool {
        lowDataTimingGateEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InsightCardHeader.contentSpacing) {
            InsightCardHeader(
                title: "Rhythm",
                onInfoTap: { isTimingStrengthInfoPresented = true },
                infoAccessibilityLabel: "Timing strength help"
            )

            VStack(alignment: .leading, spacing: CadenceTokens.Space.sm + 2) {
                if isPremium {
                    Text(primaryInsight)
                        .font(CadenceTokens.Typography.supporting)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                RhythmLineChart(
                    data: data,
                    accent: accent,
                    selectedHour: $selectedHour,
                    selectionEnabled: isPremium,
                    nowHour: currentHour,
                    peakHour: resolvedInsight.peakHour,
                    showNowMarker: isPremium,
                    showPeakMarker: isPremium,
                    showTrailingIncompletenessFade: !isPremium
                )

                if isPremium {
                    Group {
                        if let selectedLabel {
                            Text(selectedLabel)
                                .font(CadenceTokens.Typography.microCopy)
                                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        } else {
                            Text("12PM - 100% timing strength")
                                .font(CadenceTokens.Typography.microCopy)
                                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                                .opacity(0)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isPremium {
                    Text(passiveDetail)
                        .font(CadenceTokens.Typography.microCopy)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button {
                        onUnlock?()
                    } label: {
                        VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                            Text("Your rhythm is still forming")
                                .font(CadenceTokens.Typography.body)
                            Text("See your full daily pattern")
                                .font(CadenceTokens.Typography.microCopy)
                                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, -4)
                }
            }
        }
        .padding(.horizontal, CadenceTokens.Space.lg)
        .padding(.top, InsightCardHeader.topPadding)
        .padding(.bottom, InsightCardHeader.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen?()
        }
        .onAppear {
            logTimingTrace()
        }
        .onChange(of: rhythm?.timeInsight.peakHour) { _, _ in
            logTimingTrace()
        }
        .sheet(isPresented: $isTimingStrengthInfoPresented) {
            TimingStrengthInfoSheet()
                .presentationDetents([.height(230)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }

    private func formattedTime(_ hour: Int) -> String {
        humanTime(for: hour)
    }

    private func logTimingTrace() {
        #if DEBUG
        let enginePeak = resolvedInsight.peakHour
        let displayedHour = enginePeak
        let chartHighlightedHour = resolvedInsight.peakHour
        print("[TimeInsight CONSISTENCY CHECK]")
        print("surface: Detail")
        print("enginePeak: \(enginePeak)")
        print("consumerHour: \(displayedHour)")
        print("match: \(displayedHour == enginePeak)")
        print("[TimeInsight CONSISTENCY CHECK]")
        print("surface: Momentum")
        print("enginePeak: \(enginePeak)")
        print("consumerHour: \(chartHighlightedHour)")
        print("match: \(chartHighlightedHour == enginePeak)")
        assert(displayedHour == enginePeak, "displayed peak label hour must equal engine peakHour")
        assert(chartHighlightedHour == enginePeak, "chart marker hour must equal engine peakHour")
        #endif
    }
}

private struct TimingStrengthInfoSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
            Text("Timing strength")
                .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                .foregroundStyle(CadenceTokens.Color.Text.primary)

            Text("This percentage shows how favorable this hour is for this habit, compared with your strongest hour.")
                .font(CadenceTokens.Typography.supporting)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)

            Text("100% means strongest hour. Lower values are weaker, but still usable.")
                .font(CadenceTokens.Typography.supporting)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(CadenceTokens.Space.lg)
        .presentationBackground(CadenceTokens.Color.Background.primary)
    }
}
