import SwiftUI
import SwiftData

struct EditHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var habit: Habit
    private let onDeleted: (() -> Void)?

    @State private var name: String
    @State private var identity: String
    @State private var subtitle: String
    @State private var selectedHex: String
    @State private var iconName: String?
    @State private var category: HabitCategory
    @State private var hasStreakGoal: Bool
    @State private var goalType: GoalType
    @State private var goalPeriod: GoalPeriod
    @State private var streakTarget: Int
    @State private var targetValue: Double
    @State private var unit: String
    @State private var allowsDecimals: Bool

    @State private var reminders: [HabitReminderDraft]
    @State private var showDeleteConfirmation: Bool = false

    init(habit: Habit, onDeleted: (() -> Void)? = nil) {
        self.habit = habit
        self.onDeleted = onDeleted

        _name = State(initialValue: habit.name)
        _identity = State(initialValue: habit.identity ?? "")
        _subtitle = State(initialValue: habit.subtitle ?? "")
        _selectedHex = State(initialValue: HabitColor.from(hex: habit.colorHex).hex)
        _iconName = State(initialValue: habit.iconName)
        _category = State(initialValue: habit.category)

        _hasStreakGoal = State(initialValue: habit.hasStreakGoal)
        _goalType = State(initialValue: habit.goalType)
        _goalPeriod = State(initialValue: habit.goalPeriod)
        _streakTarget = State(initialValue: habit.streakTarget)
        _targetValue = State(initialValue: habit.targetValue ?? 1)
        _unit = State(initialValue: habit.unit ?? "")
        _allowsDecimals = State(initialValue: habit.allowsDecimals)
        _reminders = State(initialValue: HabitReminderDraft.makeDrafts(from: habit.reminders))
    }

    var body: some View {
        NavigationStack {
            HabitFormView(
                name: $name,
                identity: $identity,
                subtitle: $subtitle,
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
                reminders: $reminders,
                showsDelete: true,
                onDelete: {
                    showDeleteConfirmation = true
                }
            )
            .navigationTitle("Edit Habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DismissButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isUnchanged || !canSave)
                    .opacity((isUnchanged || !canSave) ? 0.45 : 1)
                }
            }
        }
        .alert("Delete Habit?",
                isPresented: $showDeleteConfirmation) {

             Button("Delete", role: .destructive) {
                 deleteHabit()
             }

             Button("Cancel", role: .cancel) { }

         } message: {
             Text("This will permanently remove the habit and all associated logs.")
         }
    }
    
    private func deleteHabit() {
        HabitDeletionAction.perform(
            habit: habit,
            modelContext: modelContext,
            dismissEditSheet: { dismiss() },
            onDeleted: onDeleted
        )
    }

    private var isUnchanged: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIdentity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedName == habit.name &&
               (trimmedIdentity.isEmpty ? nil : trimmedIdentity) == habit.identity &&
               (trimmedSubtitle.isEmpty ? nil : trimmedSubtitle) == habit.subtitle &&
               HabitColor.from(hex: selectedHex).hex == HabitColor.from(hex: habit.colorHex).hex &&
               iconName == habit.iconName &&
               category == habit.category &&
               hasStreakGoal == habit.hasStreakGoal &&
               goalType == habit.goalType &&
               goalPeriod == habit.goalPeriod &&
               streakTarget == habit.streakTarget &&
               targetValue == (habit.targetValue ?? 1) &&
               unit == (habit.unit ?? "") &&
               allowsDecimals == habit.allowsDecimals &&
               reminders == HabitReminderDraft.makeDrafts(from: habit.reminders)
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        guard hasStreakGoal else { return true }

        switch goalType {
        case .frequency:
            return streakTarget >= 1
        case .cumulative:
            return targetValue > 0 &&
                   !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSubtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle

        let trimmedIdentity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIdentity = trimmedIdentity.isEmpty ? nil : trimmedIdentity

        let trimmedIcon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalIcon = trimmedIcon.isEmpty ? nil : trimmedIcon

        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalUnit = trimmedUnit.isEmpty ? nil : trimmedUnit

        habit.name = trimmedName
        habit.identity = finalIdentity
        habit.subtitle = finalSubtitle
        habit.iconName = finalIcon
        habit.colorHex = HabitColor.from(hex: selectedHex).hex
        habit.category = category

        habit.hasStreakGoal = hasStreakGoal
        habit.goalType = goalType
        habit.goalPeriod = goalPeriod
        habit.streakTarget = streakTarget
        habit.targetValue = finalUnit == nil ? nil : targetValue
        habit.unit = finalUnit
        habit.allowsDecimals = allowsDecimals

        applyReminderDrafts()

        if habit.goalType == .cumulative {
            _ = habit.normalizeCumulativeLogs()
        }

        _ = modelContext.saveAndSyncWidgetData()

        dismiss()

        Task {
            await NotificationService.shared.syncNotifications(for: habit)
            await NotificationService.shared.syncEveningReflectionFromStoredSettings()
        }
    }

    private func applyReminderDrafts() {
        let existingByID = Dictionary(
            uniqueKeysWithValues: habit.reminders.map { ($0.id, $0) }
        )

        var updatedReminders: [HabitReminder] = []
        updatedReminders.reserveCapacity(reminders.count)

        for draft in reminders {
            let reminder = existingByID[draft.id] ?? draft.makeReminder()
            reminder.id = draft.id
            reminder.hour = draft.hour
            reminder.minute = draft.minute
            reminder.isEnabled = draft.isEnabled
            updatedReminders.append(reminder)
        }

        habit.reminders = updatedReminders
    }
}

enum HabitDeletionAction {
    static func perform(
        habit: Habit,
        modelContext: ModelContext,
        dismissEditSheet: () -> Void = {},
        onDeleted: (() -> Void)? = nil
    ) {
        HabitListMutation.delete(habit, in: modelContext)
        dismissEditSheet()
        onDeleted?()
    }
}
