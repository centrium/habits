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
    @State private var isDetailPresented = false
    @State private var selectedDetent: PresentationDetent = .large
    @State private var selectedDate = Date()
    @State private var showQuickEntry = false
    @State private var showHeatmapPaywall = false
    @State private var displayedStreak: Int = 0
    private let isReordering: Bool
    private let trailingAccessory: AnyView?
    private let onDeleted: (() -> Void)?

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
        trailingAccessory: AnyView? = nil,
        onDeleted: (() -> Void)? = nil
    ) {
        self.habit = habit
        self.isReordering = isReordering
        self.trailingAccessory = trailingAccessory
        self.onDeleted = onDeleted
    }

    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
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
                        _ = habitLogService.quickLog(for: habit, on: currentDay)
                    } else {
                        showQuickEntry = true
                    }
                },
                onQuickLogLongPress: nil
            )
            .frame(height: headerHeight)


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
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitListCardContainer()
        .contentShape(Rectangle())
        .onTapGesture {
            isDetailPresented = true
        }
        .sheet(isPresented: $isDetailPresented) {
            HabitDetailSheet(
                habit: habit,
                initialCalendar: calculationCalendar,
                onDeleted: onDeleted
            )
                .presentationDetents([.medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showQuickEntry) {
                CumulativeQuickEntrySheet(
                    goalName: habit.name,
                    unitLabel: habit.trimmedUnit,
                    initialValue: habitLogService.suggestedQuickEntryValue(for: habit),
                    formattingContext: habitLogService.valueFormattingContext(for: habit),
                    inputContext: habitLogService.valueInputContext(for: habit)
                ) { newValue in
                    let currentDay = CurrentDayResolver.currentDay(calendar: calculationCalendar)
                    _ = habitLogService.addLog(for: habit, on: currentDay, value: max(0, newValue))
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
}
