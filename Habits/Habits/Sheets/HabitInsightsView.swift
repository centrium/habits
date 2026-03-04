import SwiftData
import SwiftUI

struct HabitInsightsView: View {
    let habit: Habit
    
    @EnvironmentObject private var userSettings: UserSettings
    @State private var hasAnimatedIn = false

    private var accent: Color {
        Color(hex: habit.colorHex)
    }
    
    // MARK: - Insights Engine

    private var insights: HabitInsights {
        HabitInsightsEngine.insights(
            for: habit,
            referenceDate: .now,
            calendar: .current,
            weekStartPreference: userSettings.weekStartPreference
        )
    }

    // MARK: - Derived Values

    private var completionRate: Double {
        insights.completionRate
    }

    private var completedDays: Int {
        insights.progressSeries.filter { $0.progress >= 1 }.count
    }

    private var totalDays: Int {
        insights.progressSeries.count
    }

    private var averagePerDay: Double {
        insights.averagePerDay
    }

    private var currentStreak: Int {
        insights.currentStreak
    }

    private var longestStreak: Int {
        insights.longestStreak
    }

    private var momentumPercentage: Double {
        insights.momentumPercentage
    }

    private var momentumDirection: HabitInsightsMomentumDirection {
        if momentumPercentage > 0 {
            return .up
        } else if momentumPercentage < 0 {
            return .down
        } else {
            return .neutral
        }
    }

    private var recentActivity: [Int] {
        insights.progressSeries.map { Int($0.progress.rounded()) }
    }

    // MARK: - UI

    var body: some View {
        ScrollView {
            VStack(spacing: 38) {

                HeroSection(
                    completionRate: completionRate,
                    completedDays: completedDays,
                    totalDays: totalDays,
                    momentumPercentage: Int(momentumPercentage),
                    momentumDirection: momentumDirection,
                    accent: accent
                )
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.32), value: hasAnimatedIn)

                TrendSection(
                    activity: recentActivity,
                    accent: accent,
                    animateBars: hasAnimatedIn
                )
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.36).delay(0.03), value: hasAnimatedIn)

                PerformanceSection(
                    averagePerDay: averagePerDay,
                    currentStreak: currentStreak,
                    longestStreak: longestStreak
                )
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.38).delay(0.06), value: hasAnimatedIn)

                MomentumSection(
                    percentage: Int(momentumPercentage.rounded()),
                    direction: momentumDirection
                )
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: hasAnimatedIn)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insights")
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
