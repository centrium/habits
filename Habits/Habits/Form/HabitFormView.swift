//
//  HabitFormView.swift
//  Habits
//
//  Created by Matt Adams on 26/02/2026.
//

import SwiftUI

struct HabitFormView: View {
    @Binding var name: String
    @Binding var subtitle: String
    @Binding var selectedHex: String
    @Binding var iconName: String?
    @Binding var hasStreakGoal: Bool
    @Binding var goalType: GoalType
    @Binding var goalPeriod: GoalPeriod
    @Binding var streakTarget: Int
    @Binding var targetValue: Double
    @Binding var unit: String
    @Binding var allowsDecimals: Bool
    let palette: [(String, String)]

    @State private var showIconPicker = false
    @State private var showingFrequencyTargetEditor = false
    @State private var showingCumulativeTargetEditor = false

    var body: some View {
        Form {
            Section {
                HabitHeaderPreview(
                    name: name,
                    subtitle: subtitle,
                    iconName: iconName,
                    colorHex: selectedHex
                )
                .padding(.vertical, 4)
            }

            Section("Habit") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)

                TextField("Subtitle (optional)", text: $subtitle)
            }

            Section("Colour") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(palette, id: \.1) { item in
                            let hex = item.1
                            let color = Color(hex: hex)

                            Button {
                                selectedHex = hex
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle().stroke(
                                            Color.white.opacity(selectedHex == hex ? 0.9 : 0.15),
                                            lineWidth: selectedHex == hex ? 2 : 1
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Section("Icon") {
                Button {
                    showIconPicker = true
                } label: {
                    HStack {
                        Text("Icon")

                        Spacer()

                        if let iconName, !iconName.isEmpty {
                            Image(systemName: iconName)
                                .foregroundStyle(Color(hex: selectedHex))
                        } else {
                            Text("None")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
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

                    Picker("Cadence", selection: $goalPeriod) {
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
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerSheet(
                selectedIcon: iconName,
                accentHex: selectedHex
            ) { newIcon in
                iconName = newIcon
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingFrequencyTargetEditor) {
            TargetNumberSheet(
                initialValue: streakTarget,
                goalType: goalPeriod
            ) { newValue in
                streakTarget = newValue
            }
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
        }
    }

    private var frequencyTargetRow: some View {
        HStack(spacing: 8) {
            Text("Target:")

            Text("\(streakTarget)")
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                )
                .onTapGesture {
                    showingFrequencyTargetEditor = true
                }

            Text("per \(goalPeriod.unit)")
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 14) {
                Button {
                    streakTarget = max(1, streakTarget - 1)
                } label: {
                    Image(systemName: "minus")
                }

                Button {
                    streakTarget += 1
                } label: {
                    Image(systemName: "plus")
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var cumulativeTargetRow: some View {
        HStack(spacing: 8) {
            Text("Target:")

            Text(cumulativeTargetLabel)
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                )
                .onTapGesture {
                    showingCumulativeTargetEditor = true
                }

            if let trimmedUnit {
                Text(trimmedUnit)
                    .foregroundStyle(.secondary)
            }

            Spacer()
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
