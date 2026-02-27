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
    @Binding var streakGoalType: StreakGoalType
    @Binding var streakTarget: Int
    @State private var showIconPicker = false

    let palette: [(String, String)]
    let submitTitle: String
    let onSubmit: () -> Void

    var body: some View {
        Form {
            // Live preview
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
                    Picker("Cadence", selection: $streakGoalType) {
                        ForEach(StreakGoalType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $streakTarget, in: 1...999) {
                        Text("Target: \(streakTarget) per \(streakGoalType.unit)")
                    }

                    Text("Streak counts when you hit the target for the period.")
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
    }
}
