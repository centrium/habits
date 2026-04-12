//
//  GoalProgressButton.swift
//  Habits
//
//  Created by Codex on 28/02/2026.
//

import SwiftUI

struct GoalProgressButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @GestureState private var isPressing = false

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
        guard isPressing else { return idleForegroundTint }
        return .white
    }

    private var idleForegroundTint: Color {
        CadenceTokens.Color.Text.secondary.opacity(colorScheme == .dark ? 0.88 : 0.78)
    }

    private var innerFill: Color {
        guard isPressing else { return idleInnerFill }
        return accent
    }

    private var idleInnerFill: Color {
        Color(uiColor: .secondarySystemFill).opacity(colorScheme == .dark ? 0.54 : 0.4)
    }

    private var idleAccentWash: Color {
        accent.opacity(colorScheme == .dark ? 0.12 : 0.1)
    }

    private var buttonBorderTint: Color {
        if isPressing {
            return accent.opacity(colorScheme == .dark ? 0.46 : 0.4)
        }

        return Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.14)
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

                Circle()
                    .fill(idleAccentWash)
                    .opacity(isPressing ? 0 : 1)
                    .frame(width: iconSize - 2, height: iconSize - 2)

                Image(systemName: symbolName)
                    .opacity(incompleteOpacity)

                Image(systemName: symbolName)
                    .opacity(completeOpacity)
            }
            .font(.system(size: isSecondaryEmphasis ? 16 : 18, weight: .semibold))
            .foregroundStyle(foregroundTint)
            .frame(width: iconSize, height: iconSize)
            .overlay {
                Circle()
                    .stroke(buttonBorderTint, lineWidth: 0.8)
            }
            .scaleEffect((isPressing ? 0.97 : 1) * pulseScale)
            .contentShape(Circle())
            .padding(tapPadding)
            .animation(.easeOut(duration: 0.14), value: isPressing)
        }
        .buttonStyle(TactileButtonStyle(pressedScale: 1, pressedOpacity: 1))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isComplete ? [.isSelected] : [])
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0, maximumDistance: .infinity)
                .updating($isPressing) { value, state, _ in
                    state = value
                }
        )
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
        .onChange(of: isPressing) { oldValue, newValue in
            guard !oldValue, newValue else { return }
            Haptics.impactLight()
        }
    }

    @ViewBuilder
    private var ringLayer: some View {
        if hasGoal {
            Circle()
                .stroke(idleRingTint, lineWidth: ringLineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    progressRingTint,
                    style: StrokeStyle(
                        lineWidth: ringLineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
        }
    }

    private var idleRingTint: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.1)
    }

    private var progressRingTint: Color {
        guard isPressing else {
            return Color.primary.opacity(colorScheme == .dark ? 0.36 : 0.26)
        }
        return Color.white.opacity(0.92)
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
