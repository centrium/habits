import SwiftData
import SwiftUI

private enum GlobalInsightsSpacing {
    static let section: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let titleToContent: CGFloat = 8
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
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 36)
            } else {
                GlobalInsightsEmptyState()
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
            }
        }
        .background(colorScheme == .light ? Color.appBackground : Color.appGroupedBackground)
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
            VStack(alignment: .leading, spacing: 12) {
                ProSwoosh(size: .small)

                VStack(alignment: .leading, spacing: 4) {
                    metricLine(label: "Momentum", value: hero.momentum)
                    metricLine(label: "Consistency", value: hero.consistency)
                }

                Text(hero.statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metricLine(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary.opacity(0.65))

            Text("\(value)%")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Color.systemAccent)
        }
    }
}

private struct GlobalInsightsMetricsSection: View {
    let metrics: GlobalInsightsMetrics

    var body: some View {
        GlobalInsightsSurface(padding: 18) {
            HStack(alignment: .top, spacing: 12) {
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
        VStack(spacing: 7) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct GlobalInsightsHabitSnapshotSection: View {
    let rows: [GlobalInsightHabitRow]

    var body: some View {
        GlobalInsightsSurface(padding: 18) {
            VStack(alignment: .leading, spacing: GlobalInsightsSpacing.titleToContent) {
                Text("Habit Snapshot")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(row.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)

                            Text(row.statusLabel)
                                .font(.caption.weight(.regular))
                                .foregroundStyle(statusColor(for: row.statusLabel))
                        }
                        .opacity(rowOpacity(for: index))
                    }
                }
            }
        }
    }

    private func statusColor(for label: String) -> Color {
        switch label {
        case "Needs attention":
            return Color.orange.opacity(0.72)
        case "Strong":
            return Color.systemAccent
        default:
            return .primary
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
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(primaryLine)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(secondaryLine)
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.secondary)
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
                attributed[attributedRange].foregroundColor = Color.systemAccent
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
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Add a little more habit history to unlock a fuller overview.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .cadenceSurface(cornerRadius: 18)
    }
}
