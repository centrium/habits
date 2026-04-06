import SwiftUI
import SwiftData

struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var identity: String = ""
    @State private var subtitle: String = ""
    @State private var cueText: String = ""
    @State private var selectedHex: String = HabitColor.default.hex
    @State private var iconName: String? = nil
    @State private var category: HabitCategory = .general
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

    init(onHabitAdded: ((Habit) -> Void)? = nil) {
        self.onHabitAdded = onHabitAdded
    }

    var body: some View {
        NavigationStack {
            HabitFormView(
                name: $name,
                identity: $identity,
                subtitle: $subtitle,
                cueText: $cueText,
                selectedHex: $selectedHex,
                iconName: $iconName,
                category: $category,
                hasStreakGoal: $hasStreakGoal,
                goalType: $goalType,
                goalPeriod: $goalPeriod,
                streakTarget: $streakTarget,
                targetValue: $targetValue,
                unit: $unit,
                allowsDecimals: $allowsDecimals,
                reminders: $reminders
            )
            .navigationTitle("Add Habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DismissButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addHabit()
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
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

        let trimmedIdentity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIdentity = trimmedIdentity.isEmpty ? nil : trimmedIdentity

        let trimmedCueText = cueText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCueText = trimmedCueText.isEmpty ? nil : trimmedCueText

        let trimmedIcon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalIcon = trimmedIcon.isEmpty ? nil : trimmedIcon

        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalUnit = trimmedUnit.isEmpty ? nil : trimmedUnit

        let habit = Habit(
            name: trimmedName,
            colorHex: HabitColor.from(hex: selectedHex).hex,
            identity: finalIdentity,
            category: category,
            subtitle: finalSubtitle,
            iconName: finalIcon,
            hasStreakGoal: hasStreakGoal,
            goalPeriod: goalPeriod,
            goalType: goalType,
            streakTarget: streakTarget,
            targetValue: finalUnit == nil ? nil : targetValue,
            unit: finalUnit,
            allowsDecimals: allowsDecimals,
            orderIndex: nextIndex,
            cueText: finalCueText,
            cueType: finalCueText == nil ? .none : .userDefined
        )

        habit.reminders = reminders.map { $0.makeReminder() }

        modelContext.insert(habit)
        _ = modelContext.saveAndSyncWidgetData()
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
