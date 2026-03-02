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
    let allowsDecimals: Bool
    let unitLabel: String?
    let onSave: (Double) -> Void

    @State private var valueString: String
    @FocusState private var isFocused: Bool

    init(
        title: String,
        initialValue: Double,
        allowsDecimals: Bool,
        unitLabel: String? = nil,
        onSave: @escaping (Double) -> Void
    ) {
        self.title = title
        self.initialValue = initialValue
        self.allowsDecimals = allowsDecimals
        self.unitLabel = unitLabel
        self.onSave = onSave
        _valueString = State(initialValue: Self.format(initialValue, allowsDecimals: allowsDecimals))
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.headline)

            VStack(spacing: 10) {
                TextField("", text: $valueString)
                    .keyboardType(allowsDecimals ? .decimalPad : .numberPad)
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
                    let parsed = Self.parse(valueString, allowsDecimals: allowsDecimals) ?? initialValue
                    onSave(parsed)
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

    private static func format(_ value: Double, allowsDecimals: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = allowsDecimals ? 2 : 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func parse(_ text: String, allowsDecimals: Bool) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if allowsDecimals {
            return Double(trimmed.replacingOccurrences(of: ",", with: "."))
        }

        guard let intValue = Int(trimmed) else { return nil }
        return Double(intValue)
    }
}
