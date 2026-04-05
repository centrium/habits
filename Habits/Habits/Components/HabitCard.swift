//
//  HabitCard.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import SwiftUI

struct HabitCard: View {
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var habitLogService: HabitLogService
    
    @Bindable var habit: Habit
    @State private var selectedDate = Date()
    @State private var showQuickEntry = false
    @State private var showHeatmapPaywall = false
    @State private var displayedStreak: Int = 0
    private let isReordering: Bool
    private let relationText: String?
    private let flowRootColorHex: String?
    private let shouldNudgeFlow: Bool
    private let onFrequencyCompletion: ((Habit) -> Void)?
    private let trailingAccessory: AnyView?
    private let onTap: (() -> Void)?

    private let headerHeight: CGFloat = 40
    
    private func updateDisplayedStreak() {
        let now = Date()
        let newValue = habit.displayStreak(
            referenceDate: now,
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        )

        if newValue != displayedStreak {
            displayedStreak = newValue
        }
    }

    init(
        habit: Habit,
        isReordering: Bool = false,
        relationText: String? = nil,
        flowRootColorHex: String? = nil,
        shouldNudgeFlow: Bool = false,
        onFrequencyCompletion: ((Habit) -> Void)? = nil,
        trailingAccessory: AnyView? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.habit = habit
        self.isReordering = isReordering
        self.relationText = relationText
        self.flowRootColorHex = flowRootColorHex
        self.shouldNudgeFlow = shouldNudgeFlow
        self.onFrequencyCompletion = onFrequencyCompletion
        self.trailingAccessory = trailingAccessory
        self.onTap = onTap
    }

    var body: some View {
        
        VStack(alignment: .leading, spacing: HabitRowGrid.headerToHeatmapSpacing) {
            HabitHeader(
                habit: habit,
                selectedDate: selectedDate,
                calendar: calculationCalendar,
                weekStartPreference: userSettings.weekStartPreference,
                isReordering: isReordering,
                showsQuickLogButton: true,
                showsInlineProgressText: true,
                secondaryTextOverride: nil,
                currentStreak: displayedStreak,
                trailingAccessory: trailingAccessory,
                onQuickLog: { _ in
                    let currentDay = CurrentDayResolver.currentDay(calendar: calculationCalendar)
                    selectedDate = currentDay
                    if habit.goalType == .frequency {
                        let wasComplete = habit.isComplete(for: currentDay, calendar: calculationCalendar)
                        _ = habitLogService.quickLog(for: habit, on: currentDay)
                        let isNowComplete = habit.isComplete(for: currentDay, calendar: calculationCalendar)
                        if !wasComplete && isNowComplete {
                            onFrequencyCompletion?(habit)
                        }
                    } else {
                        showQuickEntry = true
                    }
                },
                onQuickLogLongPress: nil
            )
            .frame(height: headerHeight)

            Group {
                if let relationText {
                    Text(relationText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.86))
                        .lineLimit(1)
                        .transition(.opacity)
                } else {
                    Text(" ")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .opacity(0)
                }
            }
            .frame(height: 18, alignment: .leading)

                HabitHeatmap(
                    habit: habit,
                    service: habitLogService,
                    calendarProvider: heatmapCalendarProvider,
                    selectedDate: selectedDate,
                    isInteractive: false,
                    onSelectDay: { day in
                        selectedDate = day
                    },
                    onTapLockedDay: { _ in
                        guard purchaseService.premiumStatus != .unknown else { return }
                        showHeatmapPaywall = true
                    },
                    isCompact: true
                )
            
        }
        .padding(.horizontal, HabitRowGrid.contentLeading)
        .padding(.vertical, CadenceTokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
        .overlay {
            RoundedRectangle(cornerRadius: CadenceTokens.Surface.cardCornerRadius, style: .continuous)
                .stroke(
                    shouldNudgeFlow ? flowTintColor.opacity(0.55) : .clear,
                    lineWidth: shouldNudgeFlow ? 1.5 : 0
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isReordering else { return }
            onTap?()
        }
        .sheet(isPresented: $showQuickEntry) {
                CumulativeQuickEntrySheet(
                    goalName: habit.name,
                    unitLabel: habit.trimmedUnit,
                    initialValue: habitLogService.suggestedQuickEntryValue(for: habit),
                    todayTotal: habitLogService.value(
                        for: habit,
                        on: CurrentDayResolver.currentDay(calendar: calculationCalendar)
                    ),
                    targetValue: habit.effectiveTargetValue,
                    formattingContext: habitLogService.valueFormattingContext(for: habit),
                    inputContext: habitLogService.valueInputContext(for: habit)
                ) { newValue in
                    let currentDay = CurrentDayResolver.currentDay(calendar: calculationCalendar)
                    _ = habitLogService.addLog(for: habit, on: currentDay, value: max(0, newValue))
                } onClearDay: {
                    let currentDay = CurrentDayResolver.currentDay(calendar: calculationCalendar)
                    _ = habitLogService.clearEntries(for: habit, on: currentDay)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            
        }
        .sheet(isPresented: $showHeatmapPaywall) {
            PaywallView(feature: .fullHeatmapHistory)
                .environmentObject(purchaseService)
        }
        .onAppear {
            selectedDate = calculationCalendar.startOfDay(for: selectedDate)
            
            if displayedStreak == 0 {
                updateDisplayedStreak()
            }
        }
        .onChange(of: habit.logs) { _, _ in
            updateDisplayedStreak()
        }
        .onChange(of: userSettings.weekStartPreference) { _, _ in
            selectedDate = calculationCalendar.startOfDay(for: selectedDate)
            updateDisplayedStreak()
        }
        .animation(.easeInOut(duration: 0.22), value: shouldNudgeFlow)
    }

    private var weekLayoutStrategy: WeekLayoutStrategy {
        userSettings.weekLayoutStrategy()
    }

    private var calculationCalendar: Calendar {
        weekLayoutStrategy.calendarForCalculations()
    }

    private var heatmapCalendarProvider: CalendarProvider {
        weekLayoutStrategy.calendarProviderForHeatmap()
    }

    private var flowTintColor: Color {
        let resolvedHex = flowRootColorHex ?? habit.colorHex
        return CadenceTokens.Color.accent(from: resolvedHex).primary
    }
}
