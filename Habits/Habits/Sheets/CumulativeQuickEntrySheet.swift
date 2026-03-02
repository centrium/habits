//
//  CumulativeQuickEntrySheet.swift
//  Habits
//
//  Created by Codex on 01/03/2026.
//

import SwiftUI

struct CumulativeQuickEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let goalName: String
    let unitLabel: String?
    let initialValue: Double?
    let formattingContext: ValueFormattingContext
    let inputContext: ValueInputContext
    let onConfirm: (Double) -> Void

    @State private var valueString: String

    init(
        goalName: String,
        unitLabel: String?,
        initialValue: Double?,
        formattingContext: ValueFormattingContext,
        inputContext: ValueInputContext,
        onConfirm: @escaping (Double) -> Void
    ) {
        self.goalName = goalName
        self.unitLabel = unitLabel
        self.initialValue = initialValue
        self.formattingContext = formattingContext
        self.inputContext = inputContext
        self.onConfirm = onConfirm
        let fallbackValue = initialValue.map { NSDecimalNumber(value: $0).decimalValue } ?? Decimal(1)
        _valueString = State(
            initialValue: HabitValueFormatter.inputString(for: fallbackValue, context: formattingContext)
        )
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(goalName)
                    .font(.headline)

                if let unitLabel, !unitLabel.isEmpty {
                    Text(unitLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("", text: $valueString)
                .keyboardType(inputContext.metricKind == .count ? .numberPad : .decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.secondary.opacity(0.14))
                )
                .padding(.horizontal, 24)

            Button("Add") {
                let fallback = initialValue.map { NSDecimalNumber(value: $0).decimalValue } ?? Decimal(1)
                let parsed = ValueInputParser.parse(valueString, context: inputContext) ?? fallback
                onConfirm(ValueInputParser.sanitizeForStorage(parsed, context: inputContext))
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.14))
            )
        }
        .padding(.top, 28)
        .padding(.bottom, 24)
        .presentationDetents([.height(220)])
    }
}
