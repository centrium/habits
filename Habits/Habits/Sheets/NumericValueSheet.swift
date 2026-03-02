//
//  NumericValueSheet.swift
//  Habits
//
//  Created by Codex on 01/03/2026.
//

import SwiftUI

struct NumericValueSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialValue: Double
    let formattingContext: ValueFormattingContext
    let inputContext: ValueInputContext
    let unitLabel: String?
    let onSave: (Double) -> Void

    @State private var valueString: String
    @FocusState private var isFocused: Bool

    init(
        title: String,
        initialValue: Double,
        formattingContext: ValueFormattingContext,
        inputContext: ValueInputContext,
        unitLabel: String? = nil,
        onSave: @escaping (Double) -> Void
    ) {
        self.title = title
        self.initialValue = initialValue
        self.formattingContext = formattingContext
        self.inputContext = inputContext
        self.unitLabel = unitLabel
        self.onSave = onSave
        _valueString = State(
            initialValue: HabitValueFormatter.inputString(
                for: NSDecimalNumber(value: initialValue).decimalValue,
                context: formattingContext
            )
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.headline)

            VStack(spacing: 10) {
                TextField("", text: $valueString)
                    .keyboardType(inputContext.metricKind == .count ? .numberPad : .decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .focused($isFocused)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.15))
                    )
                    .padding(.horizontal, 32)

                if let unitLabel, !unitLabel.isEmpty {
                    Text(unitLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Done") {
                    let fallback = NSDecimalNumber(value: initialValue).decimalValue
                    let parsed = ValueInputParser.parse(valueString, context: inputContext) ?? fallback
                    onSave(ValueInputParser.sanitizeForStorage(parsed, context: inputContext))
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 32)
        .onAppear { isFocused = true }
        .presentationDetents([.height(280)])
    }
}
