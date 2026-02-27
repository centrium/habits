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
    @State private var selectedDate = Date()

    // Layout tuning
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 4
    private let monthLabelHeight: CGFloat = 14
    private let headerHeight: CGFloat = 40

    private var accent: Color {
        Color(hex: habit.colorHex)
    }

    var body: some View {
        Button {
            isDetailPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HabitHeader(
                    habit: habit,
                    showsQuickLogButton: true,
                    onQuickLog: {
                        service?.increment(for: habit, on: Date())
                    }
                )
                .frame(height: headerHeight)

                if let service = service {
                    HabitHeatmap(
                        habit: habit,
                        service: service,
                        selectedDate: selectedDate,
                        onSelectDay: { day in
                            selectedDate = day
                        }
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .sheet(isPresented: $isDetailPresented) {
            HabitDetailSheet(habit: habit, modelContext: modelContext)
                .presentationDetents([.medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                
        }
        .onAppear {
            if service == nil {
                service = HabitLogService(modelContext: modelContext)
            }
        }
    }
}
