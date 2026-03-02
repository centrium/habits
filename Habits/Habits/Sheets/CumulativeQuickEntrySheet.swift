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
    let allowsDecimals: Bool
    let onConfirm: (Double) -> Void

    @State private var valueString: String

    init(
        goalName: String,
        unitLabel: String?,
        initialValue: Double?,
        allowsDecimals: Bool,
        onConfirm: @escaping (Double) -> Void
    ) {
        self.goalName = goalName
        self.unitLabel = unitLabel
        self.initialValue = initialValue
        self.allowsDecimals = allowsDecimals
        self.onConfirm = onConfirm
        _valueString = State(initialValue: initialValue.map { Self.format($0, allowsDecimals: allowsDecimals) } ?? "")
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
                .keyboardType(allowsDecimals ? .decimalPad : .numberPad)
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
                let fallback = initialValue ?? (allowsDecimals ? 1.0 : 1.0)
                let parsed = Self.parse(valueString, allowsDecimals: allowsDecimals) ?? fallback
                onConfirm(parsed)
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
