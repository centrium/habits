import SwiftData
import SwiftUI

private enum GlobalInsightsSpacing {
    static let section = CadenceTokens.Space.xl
    static let cardPadding = CadenceTokens.Space.xl
    static let titleToContent = CadenceTokens.Space.sm
}

struct GlobalInsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var userSettings: UserSettings
    @Query(sort: \Habit.orderIndex) private var habits: [Habit]

    private var snapshot: GlobalInsightsSnapshot? {
        GlobalInsightsService(
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        ).snapshot(for: habits, now: .now)
    }

    var body: some View {
        ScrollView {
            if let snapshot {
                VStack(alignment: .leading, spacing: GlobalInsightsSpacing.section) {
                    GlobalInsightsHeroSection(hero: snapshot.hero)
                    GlobalInsightsMetricsSection(metrics: snapshot.metrics)
                    GlobalInsightsHabitSnapshotSection(rows: snapshot.topHabits)
                    GlobalInsightsGreigSection(greig: snapshot.greig)
                }
                .padding(.horizontal, CadenceTokens.Space.xl)
                .padding(.top, CadenceTokens.Space.x2l)
                .padding(.bottom, CadenceTokens.Space.x3l + CadenceTokens.Space.xs)
            } else {
                GlobalInsightsEmptyState()
                    .padding(.horizontal, CadenceTokens.Space.xl)
                    .padding(.top, CadenceTokens.Space.x2l)
                    .padding(.bottom, CadenceTokens.Space.x3l + CadenceTokens.Space.xs)
            }
        }
        .background(colorScheme == .light ? CadenceTokens.Color.Background.primary : Color.appGroupedBackground)
        .navigationTitle("Global Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calculationCalendar: Calendar {
        userSettings.weekLayoutStrategy().calendarForCalculations()
    }
}

private struct GlobalInsightsHeroSection: View {
    let hero: GlobalInsightsHero

    var body: some View {
        GlobalInsightsSurface(padding: GlobalInsightsSpacing.cardPadding) {
            VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
                ProSwoosh(size: .small)

                VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                    metricLine(label: "Identity", value: CadenceLanguage.shortLabel(for: hero.dominantState))
                    metricLine(label: "Consistency", value: hero.consistency)
                }

                Text(hero.summaryText)
                    .font(CadenceTokens.Typography.sectionHeader)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metricLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(CadenceTokens.Typography.sectionHeader)
                .foregroundStyle(CadenceTokens.Color.Text.tertiary)

            Text(value)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(CadenceTokens.Color.accent(from: HabitColor.default.hex).primary)
        }
    }

    private func metricLine(label: String, value: Int) -> some View {
        metricLine(label: label, value: "\(value)%")
    }
}

private struct GlobalInsightsMetricsSection: View {
    let metrics: GlobalInsightsMetrics

    var body: some View {
        GlobalInsightsSurface(padding: CadenceTokens.Space.lg + 2) {
            HStack(alignment: .top, spacing: CadenceTokens.Space.md) {
                metricColumn(
                    title: "Current streak",
                    value: metrics.bestCurrentStreak == 0 ? "0" : "\(metrics.bestCurrentStreak)d"
                )
                metricColumn(title: "Best day", value: metrics.bestDayOfWeek)
                metricColumn(title: "At risk", value: "\(metrics.atRiskCount)")
            }
        }
    }

    private func metricColumn(title: String, value: String) -> some View {
        VStack(spacing: CadenceTokens.Space.sm - 1) {
            Text(value)
                .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                .foregroundStyle(CadenceTokens.Color.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(CadenceTokens.Typography.supporting.weight(.medium))
                .foregroundStyle(CadenceTokens.Color.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct GlobalInsightsHabitSnapshotSection: View {
    let rows: [GlobalInsightHabitRow]

    var body: some View {
        GlobalInsightsSurface(padding: CadenceTokens.Space.lg + 2) {
            VStack(alignment: .leading, spacing: GlobalInsightsSpacing.titleToContent) {
                Text("Habit Snapshot")
                    .font(CadenceTokens.Typography.supporting.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)

                VStack(alignment: .leading, spacing: CadenceTokens.Space.md + 2) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(row.name)
                                .font(CadenceTokens.Typography.body.weight(.medium))
                                .foregroundStyle(CadenceTokens.Color.Text.primary)

                            Spacer(minLength: 0)

                            Text(row.statusLabel)
                                .font(CadenceTokens.Typography.supporting.weight(.regular))
                                .foregroundStyle(statusColor(for: row.state))
                        }
                        .opacity(rowOpacity(for: index))
                    }
                }
            }
        }
    }

    private func statusColor(for state: HabitIdentityState) -> Color {
        switch state {
        case .holding:
            return CadenceTokens.Color.accent(from: HabitColor.default.hex).primary
        case .returning:
            return CadenceTokens.Color.Text.secondary.opacity(0.72)
        case .starting:
            return CadenceTokens.Color.Text.tertiary
        case .building:
            return CadenceTokens.Color.Text.primary
        }
    }

    private func rowOpacity(for index: Int) -> Double {
        switch index {
        case 0:
            return 1
        case 1:
            return 0.94
        default:
            return 0.88
        }
    }
}

private struct GlobalInsightsGreigSection: View {
    let greig: GlobalInsightsGreig

    var body: some View {
        GlobalInsightsSurface(padding: GlobalInsightsSpacing.cardPadding) {
            VStack(alignment: .leading, spacing: GlobalInsightsSpacing.titleToContent) {
                Text("Greig Mode")
                    .font(CadenceTokens.Typography.supporting.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)

                Text(primaryLine)
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(secondaryLine)
                    .font(CadenceTokens.Typography.body)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var primaryLine: AttributedString {
        highlightedText(from: greig.trajectoryText)
    }

    private var secondaryLine: AttributedString {
        highlightedText(from: "\(greig.suggestionText) \(greig.outcomeText)")
    }

    private func highlightedText(from string: String) -> AttributedString {
        var attributed = AttributedString(string)
        let pattern = #"\~\d+"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(string.startIndex..<string.endIndex, in: string)
            let matches = regex.matches(in: string, options: [], range: nsRange)

            for match in matches {
                guard let range = Range(match.range, in: string),
                      let attributedRange = Range(range, in: attributed) else {
                    continue
                }
                attributed[attributedRange].foregroundColor = CadenceTokens.Color.accent(from: HabitColor.default.hex).primary
            }
        }

        return attributed
    }
}

private struct GlobalInsightsEmptyState: View {
    var body: some View {
        GlobalInsightsSurface(padding: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Insights")
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)

                Text("Add a little more habit history to unlock a fuller overview.")
                    .font(CadenceTokens.Typography.body)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
            }
        }
    }
}

private struct GlobalInsightsSurface<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(
        padding: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.elevatedCornerRadius)
    }
}
