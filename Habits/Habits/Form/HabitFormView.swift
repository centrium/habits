import SwiftUI

struct HabitReminderDraft: Identifiable, Equatable {
    var id: UUID
    var hour: Int
    var minute: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
    }

    @MainActor
    init(reminder: HabitReminder) {
        self.init(
            id: reminder.id,
            hour: reminder.hour,
            minute: reminder.minute,
            isEnabled: reminder.isEnabled
        )
    }

    func makeReminder() -> HabitReminder {
        let reminder = HabitReminder(
            hour: hour,
            minute: minute,
            isEnabled: isEnabled
        )
        reminder.id = id
        return reminder
    }

    mutating func setTime(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

extension HabitReminderDraft {
    static func makeDefault(hour: Int = 20, minute: Int = 0) -> HabitReminderDraft {
        HabitReminderDraft(hour: hour, minute: minute)
    }

    @MainActor
    static func makeDrafts(from reminders: [HabitReminder]) -> [HabitReminderDraft] {
        reminders.map(HabitReminderDraft.init(reminder:))
    }
}

extension Array where Element == HabitReminderDraft {
    func containsReminderTime(
        _ hour: Int,
        minute: Int,
        excluding reminderID: UUID
    ) -> Bool {
        contains { reminder in
            reminder.id != reminderID &&
            reminder.hour == hour &&
            reminder.minute == minute
        }
    }
}

private struct HabitReminderEditorItem: Identifiable, Equatable {
    let id: UUID
    let isNew: Bool
}

struct HabitFormView: View {
    enum InitialFocus {
        case name
        case identity
    }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var purchaseService: PurchaseService

    @Binding var name: String
    @Binding var identity: String
    @Binding var subtitle: String
    @Binding var cueText: String
    @Binding var selectedHex: String
    @Binding var iconName: String?
    @Binding var category: HabitCategory
    @Binding var hasStreakGoal: Bool
    @Binding var goalType: GoalType
    @Binding var goalPeriod: GoalPeriod
    @Binding var streakTarget: Int
    @Binding var targetValue: Double
    @Binding var unit: String
    @Binding var allowsDecimals: Bool
    @Binding var reminders: [HabitReminderDraft]
    var initialFocus: InitialFocus = .name
    var showsDelete: Bool = false
    var onDelete: (() -> Void)? = nil

    @State private var showIconPicker = false
    @State private var showingFrequencyTargetEditor = false
    @State private var showingCumulativeTargetEditor = false
    @State private var editingReminder: HabitReminderEditorItem?
    @State private var activePaywallContext: PaywallContext?
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case identity
    }

    private static let reminderTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    private static let titleCharacterLimit = 20
    private static let subtitleCharacterLimit = 25
    private static let intentCharacterLimit = 50
    private static let cueCharacterLimit = 50

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Habit")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Habit title", text: $name)
                                .font(.title3.weight(.semibold))
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .name)
                                .onChange(of: name) { _, newValue in
                                    name = String(newValue.prefix(Self.titleCharacterLimit))
                                }

                            TextField("Subtitle (optional)", text: $subtitle)
                                .font(.subheadline)
                                .onChange(of: subtitle) { _, newValue in
                                    subtitle = String(newValue.prefix(Self.subtitleCharacterLimit))
                                }

                            HStack(spacing: 12) {
                                Text("Category")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Picker("Category", selection: $category) {
                                    ForEach(HabitCategory.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .labelsHidden()
                                .tint(.secondary)
                                .font(.caption)
                            }
                        }
                        .padding(16)
                        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(CadenceLanguage.identityTitle())
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField(CadenceLanguage.identityPlaceholder(), text: $identity)
                                .font(.body)
                                .textInputAutocapitalization(.sentences)
                                .focused($focusedField, equals: .identity)
                                .lineLimit(1)
                                .onChange(of: identity) { _, newValue in
                                    identity = String(newValue.prefix(Self.intentCharacterLimit))
                                }

                            if identity.isEmpty || focusedField == .identity {
                                Text(CadenceLanguage.identityHelper())
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }

                            Divider()
                                .opacity(0.25)
                        }
                        .padding(16)
                        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cue")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("After I…, I will…", text: $cueText)
                                .font(.body)
                                .textInputAutocapitalization(.sentences)
                                .onChange(of: cueText) { _, newValue in
                                    cueText = String(newValue.prefix(Self.cueCharacterLimit))
                                }

                            Text("e.g. After I walk, I stretch • After coffee, I journal")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Appearance")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 16) {
                            let canonicalSelectedColor = HabitColor.from(hex: selectedHex)

                            LazyVGrid(columns: colorSwatchColumns, spacing: 12) {
                                ForEach(HabitColor.allCases) { paletteColor in
                                    let isSelected = (paletteColor == canonicalSelectedColor)

                                    Button {
                                        selectedHex = paletteColor.hex
                                    } label: {
                                        Circle()
                                            .fill(paletteColor.color)
                                            .frame(width: colorSwatchSize, height: colorSwatchSize)
                                            .frame(width: 40, height: 40)
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        isSelected
                                                        ? (colorScheme == .dark ? Color.white.opacity(1) : Color.black.opacity(0.92))
                                                        : Color.primary.opacity(0.16),
                                                        lineWidth: isSelected ? 2.8 : 1
                                                    )
                                                    .frame(width: 34, height: 34)
                                            }
                                            .scaleEffect(isSelected ? 1.05 : 1)
                                            .shadow(
                                                color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08),
                                                radius: isSelected ? 2.6 : 1.6,
                                                y: isSelected ? 1.4 : 0.8
                                            )
                                    }
                                    .buttonStyle(TactileButtonStyle())
                                    .accessibilityLabel(paletteColor.name)
                                }
                            }
                            .padding(4)

                            Button {
                                showIconPicker = true
                            } label: {
                                HStack {
                                    Text("Icon")

                                    Spacer()

                                    if let iconName, !iconName.isEmpty {
                                        Image(systemName: iconName)
                                            .foregroundStyle(canonicalSelectedColor.color)
                                    } else {
                                        Text("None")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(TactileButtonStyle())
                        }
                        .padding(16)
                        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
                    }
                }
                .padding(.top, 14)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Section("Goal") {
                Toggle("Set a goal", isOn: $hasStreakGoal)

                if hasStreakGoal {
                    Picker("Goal Type", selection: $goalType) {
                        ForEach(GoalType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Repeat", selection: $goalPeriod) {
                        ForEach(GoalPeriod.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if goalType == .frequency {
                        frequencyTargetRow
                    } else {
                        cumulativeTargetRow

                        TextField("Unit", text: $unit)
                            .textInputAutocapitalization(.never)

                        Toggle("Allow decimals", isOn: $allowsDecimals)
                    }

                    Text(goalDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Open-ended — log any amount.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Reminders") {
                Text("Gentle prompts to help you stay in rhythm")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if reminders.isEmpty {
                    Text("No reminders set")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reminders) { reminder in
                        reminderRow(reminder)
                    }
                    .onDelete(perform: deleteReminders)
                }

                Button {
                    if canAddReminder {
                        addReminder()
                    } else if purchaseService.premiumStatus == .free {
                        activePaywallContext = .multipleReminders
                    }
                } label: {
                    Label("Add Reminder", systemImage: "plus")
                }
                .buttonStyle(TactileButtonStyle())

                if showsMultipleReminderUpgradeHint {
                    Text("Add multiple reminders with Premium")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if showsDelete {
                Section {
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Delete Habit", systemImage: "trash")
                    }
                } footer: {
                    Text("Deleting a habit removes all history and cannot be undone.")
                }
            }
        }
        .onAppear {
            selectedHex = HabitColor.from(hex: selectedHex).hex
            name = String(name.prefix(Self.titleCharacterLimit))
            subtitle = String(subtitle.prefix(Self.subtitleCharacterLimit))
            identity = String(identity.prefix(Self.intentCharacterLimit))
            cueText = String(cueText.prefix(Self.cueCharacterLimit))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedField = (initialFocus == .identity) ? .identity : .name
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $editingReminder) { item in
            if let reminder = binding(for: item.id) {
                HabitReminderEditorSheet(
                    reminder: reminder,
                    reminderID: item.id,
                    commitTime: { hour, minute in
                        commitReminderTime(
                            reminderID: item.id,
                            hour: hour,
                            minute: minute
                        )
                    },
                    discardDuplicateNewReminder: {
                        discardDuplicateNewReminder(
                            reminderID: item.id,
                            isNew: item.isNew
                        )
                    },
                    discardNewReminder: {
                        discardNewReminder(
                            reminderID: item.id,
                            isNew: item.isNew
                        )
                    }
                )
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
                
            }
        }
        .sheet(item: $activePaywallContext) { context in
            PaywallView(context: context)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerSheet(
                selectedIcon: iconName,
                accentHex: selectedHex
            ) { newIcon in
                iconName = newIcon
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingFrequencyTargetEditor) {
            TargetNumberSheet(
                initialValue: streakTarget,
                goalType: goalPeriod
            ) { newValue in
                streakTarget = newValue
            }
            .presentationDetents([.fraction(0.32)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showingCumulativeTargetEditor) {
            NumericValueSheet(
                title: "Set \(goalPeriod.unit.capitalized) Target",
                initialValue: targetValue,
                formattingContext: ValueFormattingContext(
                    metricKind: MetricKindResolver.resolve(goalType: .cumulative, unit: trimmedUnit),
                    allowsDecimals: allowsDecimals,
                    currencyCode: CurrencyDetection.detect(unit: trimmedUnit).currencyCode
                ),
                inputContext: ValueInputContext(
                    metricKind: MetricKindResolver.resolve(goalType: .cumulative, unit: trimmedUnit),
                    allowsDecimals: allowsDecimals
                ),
                unitLabel: trimmedUnit
            ) { newValue in
                targetValue = max(newValue, allowsDecimals ? 0.1 : 1)
            }
            .presentationDetents([.fraction(0.36)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    private func binding(for reminderID: UUID) -> Binding<HabitReminderDraft>? {
        guard
            let index = reminders.firstIndex(where: { $0.id == reminderID })
        else {
            return nil
        }

        return $reminders[index]
    }

    private func reminderRow(_ reminder: HabitReminderDraft) -> some View {
        HStack(spacing: 12) {
            Button {
                editingReminder = HabitReminderEditorItem(id: reminder.id, isNew: false)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeString(for: reminder))
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Toggle("", isOn: enabledBinding(for: reminder.id))
                .labelsHidden()
        }
    }

    private let colorSwatchSize: CGFloat = 28
    private let colorSwatchColumns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10),
    ]

    private func enabledBinding(for reminderID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                reminders.first(where: { $0.id == reminderID })?.isEnabled ?? true
            },
            set: { isEnabled in
                guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else { return }
                reminders[index].isEnabled = isEnabled
            }
        )
    }

    private func addReminder() {
        let reminder = HabitReminderDraft.makeDefault()
        reminders.append(reminder)
        editingReminder = HabitReminderEditorItem(id: reminder.id, isNew: true)
    }

    private var canAddReminder: Bool {
        switch purchaseService.premiumStatus {
        case .premium:
            return true
        case .free, .unknown:
            return reminders.count < 1
        }
    }

    private var showsMultipleReminderUpgradeHint: Bool {
        purchaseService.premiumStatus == .free && reminders.count >= 1
    }

    private func deleteReminders(at offsets: IndexSet) {
        if let editingReminder,
           offsets.contains(where: { reminders[$0].id == editingReminder.id }) {
            self.editingReminder = nil
        }

        reminders.remove(atOffsets: offsets)
    }

    private func timeString(for reminder: HabitReminderDraft) -> String {
        let date = Calendar.current.date(
            from: DateComponents(hour: reminder.hour, minute: reminder.minute)
        ) ?? Date()

        return Self.reminderTimeFormatter.string(from: date)
    }

    @discardableResult
    private func commitReminderTime(
        reminderID: UUID,
        hour: Int,
        minute: Int
    ) -> Bool {
        if reminders.containsReminderTime(hour, minute: minute, excluding: reminderID) {
            return false
        }

        guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else {
            return false
        }

        reminders[index].setTime(hour: hour, minute: minute)
        return true
    }

    private func discardDuplicateNewReminder(reminderID: UUID, isNew: Bool) {
        guard isNew else { return }
        guard let reminder = reminders.first(where: { $0.id == reminderID }) else { return }
        guard reminders.containsReminderTime(reminder.hour, minute: reminder.minute, excluding: reminderID) else {
            return
        }

        removeReminder(reminderID: reminderID)
    }

    private func discardNewReminder(reminderID: UUID, isNew: Bool) {
        guard isNew else { return }
        removeReminder(reminderID: reminderID)
    }

    private func removeReminder(reminderID: UUID) {
        reminders.removeAll { $0.id == reminderID }

        if editingReminder?.id == reminderID {
            editingReminder = nil
        }
    }

    private var frequencyTargetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Target:")
                    .foregroundStyle(.secondary)

                Text("\(streakTarget)")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    )
                    .onTapGesture {
                        showingFrequencyTargetEditor = true
                    }
                    .layoutPriority(1)

                Spacer(minLength: 12)

                HStack(spacing: 14) {
                    Button {
                        streakTarget = max(1, streakTarget - 1)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(TactileButtonStyle())

                    Button {
                        streakTarget += 1
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(TactileButtonStyle())
                }
            }

            Text("per \(goalPeriod.unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var cumulativeTargetRow: some View {
        HStack(spacing: 8) {
            Text("Target:")
                .foregroundStyle(.secondary)

            Text(cumulativeTargetLabel)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                )
                .onTapGesture {
                    showingCumulativeTargetEditor = true
                }
                .layoutPriority(1)

            if let trimmedUnit {
                Text(trimmedUnit)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
    }

    private var trimmedUnit: String? {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var cumulativeTargetLabel: String {
        HabitValueFormatter.string(
            for: targetValue,
            context: ValueFormattingContext(
                metricKind: MetricKindResolver.resolve(goalType: .cumulative, unit: trimmedUnit),
                allowsDecimals: allowsDecimals,
                currencyCode: CurrencyDetection.detect(unit: trimmedUnit).currencyCode
            )
        )
    }

    private var goalDescription: String {
        switch goalType {
        case .frequency:
            return "Streak counts when you hit the target for the period."
        case .cumulative:
            return "Progress is the total amount logged within the period."
        }
    }

}

private struct HabitReminderEditorSheet: View {
    @Binding var reminder: HabitReminderDraft
    let reminderID: UUID
    let commitTime: (Int, Int) -> Bool
    let discardDuplicateNewReminder: () -> Void
    let discardNewReminder: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var shouldDiscardNewReminder = false

    private let calendar = Calendar.current

    init(
        reminder: Binding<HabitReminderDraft>,
        reminderID: UUID,
        commitTime: @escaping (Int, Int) -> Bool,
        discardDuplicateNewReminder: @escaping () -> Void,
        discardNewReminder: @escaping () -> Void
    ) {
        _reminder = reminder
        self.reminderID = reminderID
        self.commitTime = commitTime
        self.discardDuplicateNewReminder = discardDuplicateNewReminder
        self.discardNewReminder = discardNewReminder

        let draft = reminder.wrappedValue
        _selectedDate = State(
            initialValue: Calendar.current.date(
                from: DateComponents(hour: draft.hour, minute: draft.minute)
            ) ?? Date()
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reminder")
                            .font(.title3.weight(.semibold))

                        Text("Choose a time or set your own.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested times")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            quickPick("Morning", 8, 0)
                            quickPick("Afternoon", 13, 0)
                            quickPick("Evening", 20, 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()
                        .opacity(0.25)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Custom time")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ZStack {
                            DatePicker(
                                "Time",
                                selection: $selectedDate,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appSecondaryBackground)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DismissButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        commitSelectedDateAndDismiss()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                }
            }
        }
        .id(reminderID)
        .onDisappear {
            if shouldDiscardNewReminder {
                discardNewReminder()
            } else {
                discardDuplicateNewReminder()
            }
        }
        .onAppear {
            syncSelectedDate()
        }
        .onChange(of: reminder.id) { _, _ in
            syncSelectedDate()
        }
    }

    private func quickPick(_ label: String, _ hour: Int, _ minute: Int) -> some View {
        Button(label) {
            shouldDiscardNewReminder = !commitTime(hour, minute)
            dismiss()
        }
        .font(.subheadline.weight(.medium))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minHeight: 42)
        .padding(.horizontal, 20)
        .background(
            Capsule()
                .fill(quickPickBackground(hour: hour, minute: minute))
        )
        .foregroundStyle(.primary)
        .buttonStyle(TactileButtonStyle())
    }

    private func quickPickBackground(hour: Int, minute: Int) -> Color {
        if reminder.hour == hour && reminder.minute == minute {
            return .accentColor.opacity(0.12)
        }

        return Color.primary.opacity(0.05)
    }

    private func commitSelectedDateAndDismiss() {
        let components = calendar.dateComponents([.hour, .minute], from: selectedDate)
        shouldDiscardNewReminder = !commitTime(
            components.hour ?? 20,
            components.minute ?? 0
        )
        dismiss()
    }

    private func syncSelectedDate() {
        selectedDate = calendar.date(
            from: DateComponents(hour: reminder.hour, minute: reminder.minute)
        ) ?? selectedDate
    }
}
