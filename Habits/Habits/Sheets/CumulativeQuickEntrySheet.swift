//
//  CumulativeQuickEntrySheet.swift
//  Habits
//
//  Created by Codex on 01/03/2026.
//

import SwiftUI
import UIKit

struct CumulativeQuickEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let goalName: String
    let unitLabel: String?
    let initialValue: Double?
    let todayTotal: Double?
    let targetValue: Double?
    let formattingContext: ValueFormattingContext
    let inputContext: ValueInputContext
    let onConfirm: (Double) -> Void
    let onClearDay: (() -> Void)?

    @State private var value: Double
    @State private var showClearConfirmation = false

    init(
        goalName: String,
        unitLabel: String?,
        initialValue: Double?,
        todayTotal: Double? = nil,
        targetValue: Double? = nil,
        formattingContext: ValueFormattingContext,
        inputContext: ValueInputContext,
        onConfirm: @escaping (Double) -> Void,
        onClearDay: (() -> Void)? = nil
    ) {
        self.goalName = goalName
        self.unitLabel = unitLabel
        self.initialValue = initialValue
        self.todayTotal = todayTotal
        self.targetValue = targetValue
        self.formattingContext = formattingContext
        self.inputContext = inputContext
        self.onConfirm = onConfirm
        self.onClearDay = onClearDay
        let fallbackValue = max(0, initialValue ?? 1)
        _value = State(initialValue: fallbackValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(goalName)
                    .font(.headline)

                if let todayTotal, let targetValue {
                    Text("\(formatted(todayTotal)) / \(formatted(targetValue))\(displayUnitSuffix)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let unitLabel, !unitLabel.isEmpty {
                    Text(unitLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let extraTodayText {
                    Text(extraTodayText)
                        .font(.caption)
                        .foregroundStyle(Color.systemAccent)
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 24) {
                    Button {
                        value = max(0, sanitized(value - step))
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Text(valueLineText)
                        .font(.system(size: 46, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(minWidth: 150)
                        .contentTransition(.numericText())

                    Button {
                        value = sanitized(value + step)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.systemAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                )
                .animation(.easeInOut(duration: 0.15), value: value)

                if let todayTotal {
                    Text("This will take you to \(formatted(todayTotal + value))\(displayUnitSuffix) today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)

            Button {
                onConfirm(sanitized(value))
                dismiss()
            } label: {
                Text(ctaText)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(Color.systemAccent)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isConfirmDisabled)
            .opacity(isConfirmDisabled ? 0.5 : 1)
            .padding(.horizontal, 16)

            if onClearDay != nil {
                Button {
                    showClearConfirmation = true
                } label: {
                    Text("Clear today")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 20)
        .padding(.horizontal, 8)
        .confirmationDialog("Clear today's entries?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear today", role: .destructive) {
                onClearDay?()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all values logged for today.")
        }
    }

    private var step: Double {
        if !inputContext.allowsDecimals {
            return 1
        }
        return inputContext.metricKind == .currency ? 0.5 : 0.5
    }

    private var isConfirmDisabled: Bool {
        value <= 0
    }

    private var displayUnitSuffix: String {
        guard let unitLabel, !unitLabel.isEmpty else { return "" }
        return " \(unitLabel)"
    }

    private var ctaText: String {
        "Add \(formatted(value))\(displayUnitSuffix)"
    }

    private var valueLineText: String {
        "\(formatted(value))\(displayUnitSuffix)"
    }

    private var extraTodayText: String? {
        guard let todayTotal, let targetValue else { return nil }
        let extra = todayTotal - targetValue
        guard extra > 0 else { return nil }
        return "+\(formatted(extra)) extra today"
    }

    private func formatted(_ value: Double) -> String {
        HabitValueFormatter.string(for: value, context: formattingContext)
    }

    private func sanitized(_ value: Double) -> Double {
        let decimal = NSDecimalNumber(value: max(0, value)).decimalValue
        return ValueInputParser.sanitizeForStorage(decimal, context: inputContext)
    }
}
