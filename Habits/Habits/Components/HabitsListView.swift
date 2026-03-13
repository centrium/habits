//
//  HabitsListView.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI
import SwiftData

struct HabitsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userSettings: UserSettings
    
    @Query(sort: \Habit.orderIndex) private var habits: [Habit]

    @State private var showAddHabit = false

    init() {}

    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { habit in
                    HabitCard(habit: habit) {
                        normalizeOrderIndexes()
                    }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onMove(perform: moveHabit)

                if habits.isEmpty {
                    EmptyState()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")

                    Button {
                        showAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddHabitSheet()
            }
        }
        .environmentObject(userSettings)
        .task {
            if userSettings.eveningReflectionEnabled {
                await NotificationService.shared.scheduleEveningReflection(
                    hour: userSettings.eveningReflectionHour,
                    minute: userSettings.eveningReflectionMinute
                )
            } else {
                NotificationService.shared.removeEveningReflection()
            }
        }
    }

    private func moveHabit(from source: IndexSet, to destination: Int) {
        withAnimation(.smooth) {
            var reordered = habits
            reordered.move(fromOffsets: source, toOffset: destination)
            applyOrderIndexes(to: reordered)
        }
    }

    private func normalizeOrderIndexes() {
        applyOrderIndexes(to: habits)
    }

    private func applyOrderIndexes(to orderedHabits: [Habit]) {
        for (index, habit) in orderedHabits.enumerated() where habit.orderIndex != index {
            habit.orderIndex = index
        }
        try? modelContext.save()
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("No habits yet")
                .font(.headline)
            Text("Tap + to add one. Then tap today’s square to log.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
