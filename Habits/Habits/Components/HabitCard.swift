//
//  HabitCard.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import SwiftUI
import SwiftData

struct HabitCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var uiStateStore: HabitUIStateStore
    @Bindable var habit: Habit
    @State private var isDetailPresented = false
    @State private var service: HabitLogService?
    @State private var selectedDetent: PresentationDetent = .large
    @State private var selectedDate = Date()
    @State private var showQuickEntry = false
    @State private var showHeatmapPaywall = false
    @State private var displayedStreak: Int = 0
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

    init(habit: Habit, onDeleted: (() -> Void)? = nil) {
        self.habit = habit
        self.onDeleted = onDeleted
    }

    var body: some View {
        /*let now = Date()
        let displayedStreak = habit.displayStreak(
            referenceDate: now,
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        )
*/
        
        VStack(alignment: .leading, spacing: 12) {
            HabitHeader(
                habit: habit,
                selectedDate: selectedDate,
                calendar: calculationCalendar,
                weekStartPreference: userSettings.weekStartPreference,
                showsQuickLogButton: true,
                showsInlineProgressText: true,
                secondaryTextOverride: nil,
                currentStreak: displayedStreak,
                onQuickLog: { date in
                    if habit.goalType == .frequency {
                        _ = service?.quickLog(for: habit, on: date)
                    } else {
                        showQuickEntry = true
                    }
                },
                onQuickLogLongPress: nil
            )
            .frame(height: headerHeight)

            if let service {
                HabitHeatmap(
                    habit: habit,
                    service: service,
                    calendarProvider: heatmapCalendarProvider,
                    selectedDate: selectedDate,
                    isInteractive: false,
                    onSelectDay: { day in
                        selectedDate = day
                    },
                    onTapLockedDay: { _ in
                        showHeatmapPaywall = true
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appSurface(level: .standard, cornerRadius: 16)
        .contentShape(Rectangle())
        .onTapGesture {
            isDetailPresented = true
        }
        .sheet(isPresented: $isDetailPresented) {
            HabitDetailSheet(
                habit: habit,
                modelContext: modelContext,
                initialCalendar: calculationCalendar,
                onDeleted: onDeleted
            )
                .presentationDetents([.medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showQuickEntry) {
            if let service {
                CumulativeQuickEntrySheet(
                    goalName: habit.name,
                    unitLabel: habit.trimmedUnit,
                    initialValue: service.suggestedQuickEntryValue(for: habit),
                    formattingContext: service.valueFormattingContext(for: habit),
                    inputContext: service.valueInputContext(for: habit)
                ) { newValue in
                    _ = service.addLog(for: habit, on: selectedDate, value: max(0, newValue))
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
        .sheet(isPresented: $showHeatmapPaywall) {
            PaywallView(feature: .fullHeatmapHistory)
                .environmentObject(purchaseService)
        }
        .onAppear {
            if service == nil {
                service = HabitLogService(
                    modelContext: modelContext,
                    calendar: calculationCalendar,
                    uiStateStore: uiStateStore
                )
            }

            selectedDate = calculationCalendar.startOfDay(for: selectedDate)
            service?.setUIStateStore(uiStateStore)
            service?.updateCalendar(calculationCalendar)
            service?.prepare(habit)
            
            if displayedStreak == 0 {
                updateDisplayedStreak()
            }
        }
        .onChange(of: habit.logs) { _, _ in
            updateDisplayedStreak()
        }
        .onChange(of: userSettings.weekStartPreference) { _, _ in
            selectedDate = calculationCalendar.startOfDay(for: selectedDate)
            service?.updateCalendar(calculationCalendar)
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
