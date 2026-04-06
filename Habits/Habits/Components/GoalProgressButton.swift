//
//  GoalProgressButton.swift
//  Habits
//
//  Created by Codex on 28/02/2026.
//

import SwiftUI

struct GoalProgressButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let accent: Color
    let hasGoal: Bool
    let progressFraction: Double
    let isComplete: Bool
    let symbolName: String
    let isSecondaryEmphasis: Bool
    let accessibilityLabel: String
    let action: () -> Void
    let longPressAction: (() -> Void)?
    @State private var pulseScale: CGFloat = 1

    private enum Metrics {
        static let primaryIconSize: CGFloat = 30
        static let secondaryIconSize: CGFloat = 26
        static let primaryTapPadding: CGFloat = 6
        static let secondaryTapPadding: CGFloat = 5
        static let primaryRingLineWidth: CGFloat = 3.5
        static let secondaryRingLineWidth: CGFloat = 2.8
    }

    private var clampedProgress: Double {
        min(max(progressFraction, 0), 1)
    }

    private var incompleteOpacity: Double {
        isComplete ? 0 : 1
    }

    private var completeOpacity: Double {
        isComplete ? 1 : 0
    }

    private var iconSize: CGFloat {
        isSecondaryEmphasis ? Metrics.secondaryIconSize : Metrics.primaryIconSize
    }

    private var tapPadding: CGFloat {
        isSecondaryEmphasis ? Metrics.secondaryTapPadding : Metrics.primaryTapPadding
    }

    private var ringLineWidth: CGFloat {
        isSecondaryEmphasis ? Metrics.secondaryRingLineWidth : Metrics.primaryRingLineWidth
    }

    private var foregroundTint: Color {
        isSecondaryEmphasis
            ? accent.opacity(colorScheme == .dark ? 0.74 : 0.7)
            : accent.opacity(colorScheme == .dark ? 0.9 : 0.82)
    }

    private var innerFill: Color {
        if isSecondaryEmphasis {
            return Color(uiColor: .secondarySystemFill).opacity(colorScheme == .dark ? 0.36 : 0.3)
        }

        return accent.opacity(colorScheme == .dark ? 0.12 : 0.08)
    }

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                ringLayer

                Circle()
                    .fill(innerFill)
                    .frame(width: iconSize - 1, height: iconSize - 1)

                Image(systemName: symbolName)
                    .opacity(incompleteOpacity)

                Image(systemName: symbolName)
                    .opacity(completeOpacity)
            }
            .font(.system(size: isSecondaryEmphasis ? 16 : 18, weight: .semibold))
            .foregroundStyle(foregroundTint)
            .frame(width: iconSize, height: iconSize)
            .scaleEffect(pulseScale)
            .contentShape(Circle())
            .padding(tapPadding)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isComplete ? [.isSelected] : [])
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    longPressAction?()
                }
        )
        .transaction { transaction in
            transaction.animation = nil
        }
        .onChange(of: isComplete) { oldValue, newValue in
            guard !oldValue, newValue else { return }
            triggerPulse()
        }
        .onChange(of: clampedProgress) { oldValue, newValue in
            guard oldValue == 0, newValue > 0, !isComplete else { return }
            triggerPulse()
        }
    }

    @ViewBuilder
    private var ringLayer: some View {
        if hasGoal {
            Circle()
                .stroke(accent.opacity(isSecondaryEmphasis ? 0.1 : 0.15), lineWidth: ringLineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    accent.opacity(colorScheme == .dark ? 0.9 : 0.86),
                    style: StrokeStyle(
                        lineWidth: ringLineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
        }
    }

    private func triggerPulse() {
        pulseScale = 1.08
        withAnimation(AppMotion.feedback) {
            pulseScale = 1
        }
    }
}

#Preview("Incomplete Goal") {
    GoalProgressButton(
        accent: .green,
        hasGoal: true,
        progressFraction: 0.45,
        isComplete: false,
        symbolName: "plus.circle.fill",
        isSecondaryEmphasis: false,
        accessibilityLabel: "Log Read for Mar 1, 2026",
        action: {},
        longPressAction: nil
    )
}

#Preview("Complete Goal") {
    GoalProgressButton(
        accent: .green,
        hasGoal: true,
        progressFraction: 1,
        isComplete: true,
        symbolName: "plus.circle.fill",
        isSecondaryEmphasis: false,
        accessibilityLabel: "Log Read for Mar 1, 2026",
        action: {},
        longPressAction: nil
    )
}

#Preview("No Goal") {
    GoalProgressButton(
        accent: .green,
        hasGoal: false,
        progressFraction: 0,
        isComplete: false,
        symbolName: "plus.circle.fill",
        isSecondaryEmphasis: false,
        accessibilityLabel: "Log Read for Mar 1, 2026",
        action: {},
        longPressAction: nil
    )
}
