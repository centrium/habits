import SwiftUI
import SwiftData

struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var selectedHex: String = "#7C3AED"
    @State private var iconName: String? = nil
    @State private var hasStreakGoal: Bool = false
    @State private var goalType: GoalType = .frequency
    @State private var goalPeriod: GoalPeriod = .daily
    @State private var streakTarget: Int = 1
    @State private var targetValue: Double = 1
    @State private var unit: String = ""
    @State private var allowsDecimals = false
    @State private var nextIndex: Int = 0

    @State private var reminders: [HabitReminderDraft] = []

    private let onHabitAdded: ((Habit) -> Void)?

    private let palette: [(String, String)] = [
        ("Violet", "#7C3AED"),
        ("Blue",   "#3B82F6"),
        ("Mint",   "#34D399"),
        ("Amber",  "#F59E0B"),
        ("Pink",   "#EC4899"),
        ("Teal",   "#14B8A6")
    ]

    init(onHabitAdded: ((Habit) -> Void)? = nil) {
        self.onHabitAdded = onHabitAdded
    }

    var body: some View {
        NavigationStack {
            HabitFormView(
                name: $name,
                subtitle: $subtitle,
                selectedHex: $selectedHex,
                iconName: $iconName,
                hasStreakGoal: $hasStreakGoal,
                goalType: $goalType,
                goalPeriod: $goalPeriod,
                streakTarget: $streakTarget,
                targetValue: $targetValue,
                unit: $unit,
                allowsDecimals: $allowsDecimals,
                reminders: $reminders,
                palette: palette,
            )
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DismissButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addHabit()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            nextIndex = (try? modelContext.fetchCount(FetchDescriptor<Habit>())) ?? 0
        }
    }
    
    private func nextOrderIndex() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<Habit>())) ?? 0
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        guard hasStreakGoal else { return true }

        switch goalType {
        case .frequency:
            return streakTarget >= 1
        case .cumulative:
            return targetValue > 0 && !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func addHabit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSubtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle

        let trimmedIcon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalIcon = trimmedIcon.isEmpty ? nil : trimmedIcon

        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalUnit = trimmedUnit.isEmpty ? nil : trimmedUnit

        let habit = Habit(
            name: trimmedName,
            colorHex: selectedHex,
            subtitle: finalSubtitle,
            iconName: finalIcon,
            hasStreakGoal: hasStreakGoal,
            goalPeriod: goalPeriod,
            goalType: goalType,
            streakTarget: streakTarget,
            targetValue: finalUnit == nil ? nil : targetValue,
            unit: finalUnit,
            allowsDecimals: allowsDecimals,
            orderIndex: nextIndex
        )

        habit.reminders = reminders.map { $0.makeReminder() }

        modelContext.insert(habit)
        try? modelContext.save()
        onHabitAdded?(habit)

        Task {
            await NotificationService.shared.syncNotifications(for: habit)
            await NotificationService.shared.syncEveningReflectionFromStoredSettings()

            await MainActor.run {
                dismiss()
            }
        }
    }
}
