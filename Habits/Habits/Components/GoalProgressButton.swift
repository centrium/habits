//
//  GoalProgressButton.swift
//  Habits
//
//  Created by Codex on 28/02/2026.
//

import SwiftUI

struct GoalProgressButton: View {
    let accent: Color
    let hasGoal: Bool
    let progressFraction: Double
    let isComplete: Bool
    let accessibilityLabel: String
    let action: () -> Void
    let longPressAction: (() -> Void)?
    @State private var pulseScale: CGFloat = 1

    private enum Metrics {
        static let iconSize: CGFloat = 32
        static let tapPadding: CGFloat = 6
        static let ringLineWidth: CGFloat = 3.5
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

    var body: some View {
        Button {
            Haptics.impactLight()
            action()
        } label: {
            ZStack {
                ringLayer

                Image(systemName: "plus.circle.fill")
                    .opacity(incompleteOpacity)

                Image(systemName: "plus.circle.fill")
                    .opacity(completeOpacity)
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: Metrics.iconSize, height: Metrics.iconSize)
            .scaleEffect(pulseScale)
            .contentShape(Circle())
            .padding(Metrics.tapPadding)
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
        .animation(AppMotion.quickFade, value: clampedProgress)
        .animation(AppMotion.quickFade, value: isComplete)
        .onChange(of: isComplete) { oldValue, newValue in
            guard !oldValue, newValue else { return }
            Haptics.success()
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
                .stroke(accent.opacity(0.18), lineWidth: Metrics.ringLineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    accent,
                    style: StrokeStyle(
                        lineWidth: Metrics.ringLineWidth,
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
        accessibilityLabel: "Log Read for Mar 1, 2026",
        action: {},
        longPressAction: nil
    )
}
