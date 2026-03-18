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
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @Bindable var habit: Habit
    @State private var isDetailPresented = false
    @State private var service: HabitLogService?
    @State private var selectedDetent: PresentationDetent = .large
    @State private var selectedDate = Date()
    @State private var showQuickEntry = false
    @State private var showHeatmapPaywall = false
    private let onDeleted: (() -> Void)?

    private let headerHeight: CGFloat = 40

    init(habit: Habit, onDeleted: (() -> Void)? = nil) {
        self.habit = habit
        self.onDeleted = onDeleted
    }

    var body: some View {
        let now = Date()
        let displayedStreak = habit.displayStreak(
            referenceDate: now,
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        )

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

            if let service = service {
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
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
                service = HabitLogService(modelContext: modelContext, calendar: calculationCalendar)
            }

            selectedDate = calculationCalendar.startOfDay(for: selectedDate)
            service?.updateCalendar(calculationCalendar)
            service?.prepare(habit)
        }
        .onChange(of: userSettings.weekStartPreference) { _, _ in
            selectedDate = calculationCalendar.startOfDay(for: selectedDate)
            service?.updateCalendar(calculationCalendar)
        }
        .onChange(of: deepLinkManager.openHabitID) { _, id in
            guard let id else { return }

            if id == habit.id {
                isDetailPresented = true

                DispatchQueue.main.async {
                    deepLinkManager.openHabitID = nil
                }
            }
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
