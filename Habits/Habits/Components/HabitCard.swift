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
    @Bindable var habit: Habit
    @State private var isDetailPresented = false
    @State private var service: HabitLogService?
    @State private var selectedDetent: PresentationDetent = .large
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showQuickEntry = false

    private let headerHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HabitHeader(
                habit: habit,
                selectedDate: selectedDate,
                showsQuickLogButton: true,
                showsInlineProgressText: true,
                secondaryTextOverride: nil,
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
                    selectedDate: selectedDate,
                    isInteractive: false,
                    onSelectDay: { day in
                        selectedDate = day
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
            HabitDetailSheet(habit: habit, modelContext: modelContext)
                .presentationDetents([.medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                
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
            }
        }
        .onAppear {
            if service == nil {
                service = HabitLogService(modelContext: modelContext)
            }

            service?.prepare(habit)
        }
    }
}
