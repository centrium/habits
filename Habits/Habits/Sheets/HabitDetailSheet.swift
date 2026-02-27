import SwiftUI
import SwiftData

struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var month = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var service: HabitLogService
    @State private var showEdit = false
    

    let habit: Habit

    init(habit: Habit, modelContext: ModelContext) {
        self.habit = habit
        _service = State(initialValue: HabitLogService(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Card container
                    VStack(alignment: .leading, spacing: 12) {

                        HabitHeader(
                            habit: habit,
                            showsQuickLogButton: false,
                            onQuickLog: {}
                        )
                        
                        if let details = habit.progressDetails(for: selectedDate),
                           let progress = habit.progress(for: selectedDate) {

                            let target = details.target
                            let current = details.current
                            let capped = min(current, target)
                            let surplus = max(0, current - target)

                            VStack(alignment: .leading, spacing: 8) {

                                Text("\(capped) / \(target) this \(habit.streakGoalType.unit)")
                                    .font(.headline)

                                ProgressView(value: progress)
                                    .tint(Color(hex: habit.colorHex))
                                    .animation(.easeInOut(duration: 0.25), value: progress)

                                if surplus > 0 {
                                    Text("+\(surplus) extra")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                let streak = habit.currentStreak()

                                if streak > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "flame.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color(hex: habit.colorHex))

                                        Text("\(streak) \(habit.streakGoalType.unit) streak")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: habit.colorHex).opacity(0.15))
                                    )
                                }
                            }
                            Divider().opacity(0.2)
                        }
                        HabitHeatmap(
                            habit: habit,
                            service: service,
                            selectedDate: selectedDate,
                            onSelectDay: { day in
                               selectedDate = day
                            }
                        )

                        Divider().opacity(0.2)

                        CalendarMonthView(
                            month: $month,
                            habit: habit,
                            service: service,
                            selectedDate: selectedDate,
                               onSelectDay: { day in
                                   selectedDate = day
                               }
                        )
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Intentional breathing room / future expansion
                    Color.clear
                        .frame(height: 200)
                        .allowsHitTesting(false)
                }
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { })
            .background(
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // X dismiss (left)
                ToolbarItem(placement: .navigationBarLeading) {
                    DismissButton()
                }

                // Edit (right)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button() {
                        showEdit = true
                    } label: {
                        Text("Edit")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .presentationBackground(Color(.systemBackground))
        .sheet(isPresented: $showEdit) {
            EditHabitSheet(habit: habit)
        }
    }
}
