//
//  TargetNumberSheet.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//


import SwiftUI

struct TargetNumberSheet: View {

    @Environment(\.dismiss) private var dismiss

    let initialValue: Int
    let goalType: StreakGoalType
    let onSave: (Int) -> Void

    @State private var valueString: String
    @FocusState private var isFocused: Bool

    init(
        initialValue: Int,
        goalType: StreakGoalType,
        onSave: @escaping (Int) -> Void
    ) {
        self.initialValue = initialValue
        self.goalType = goalType
        self.onSave = onSave
        _valueString = State(initialValue: "\(initialValue)")
    }

    var body: some View {

        VStack(spacing: 24) {

            Text("Set \(goalType.unit.capitalized) Target")
                .font(.headline)

            TextField("", text: $valueString)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .focused($isFocused)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.15))
                )
                .padding(.horizontal, 32)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Done") {
                    let cleaned = Int(valueString) ?? initialValue
                    let final = max(1, cleaned)
                    onSave(final)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 32)
        .onAppear { isFocused = true }
        .presentationDetents([.height(260)])
    }
}
