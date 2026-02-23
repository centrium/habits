//
//  AddHabitSheet.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI
import SwiftData

struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var selectedHex: String = "#7C3AED"

    private let palette: [(String, String)] = [
        ("Violet", "#7C3AED"),
        ("Blue",   "#3B82F6"),
        ("Mint",   "#34D399"),
        ("Amber",  "#F59E0B"),
        ("Pink",   "#EC4899"),
        ("Teal",   "#14B8A6")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
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
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addHabit()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addHabit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let habit = Habit(name: trimmed, colorHex: selectedHex)
        modelContext.insert(habit)
        try? modelContext.save()
    }
}