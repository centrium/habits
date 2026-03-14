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
    @State private var habitPendingDeletion: Habit?

    init() {}

    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { habit in
                    HabitCard(habit: habit)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                requestDeletion(of: habit)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
                .onMove(perform: moveHabit)

                if habits.isEmpty {
                    EmptyState()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .alert(
                "Delete Habit?",
                isPresented: HabitDeletionConfirmationState.isPresentedBinding(
                    for: $habitPendingDeletion
                ),
                presenting: habitPendingDeletion
            ) { habit in
                Button("Delete Habit", role: .destructive) {
                    confirmDeletion(of: habit)
                }

                Button("Cancel", role: .cancel) {
                    cancelDeletion()
                }
            } message: { habit in
                Text(HabitDeletionConfirmationState.message(for: habit))
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
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityLabel("Settings")

                    Button {
                        showAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(TactileButtonStyle())
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddHabitSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
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
        withAnimation(AppMotion.reorder) {
            var reordered = habits
            reordered.move(fromOffsets: source, toOffset: destination)
            HabitListMutation.applyOrderIndexes(to: reordered, in: modelContext)
        }
    }

    private func requestDeletion(of habit: Habit) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            habitPendingDeletion = habit
        }
    }

    private func cancelDeletion() {
        habitPendingDeletion = nil
    }

    private func confirmDeletion(of habit: Habit) {
        cancelDeletion()

        Haptics.impactMedium()

        withAnimation(AppMotion.quickFade) {
            HabitDeletionAction.perform(
                habit: habit,
                modelContext: modelContext
            )
        }
    }
}

enum HabitDeletionConfirmationState {
    static func isPresentedBinding(for pendingHabit: Binding<Habit?>) -> Binding<Bool> {
        Binding(
            get: { pendingHabit.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    pendingHabit.wrappedValue = nil
                }
            }
        )
    }

    static func message(for habit: Habit) -> String {
        "This will permanently delete \"\(habit.name)\" and its history."
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
