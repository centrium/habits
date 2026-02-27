//
//  CloseButton.swift
//  Habits
//
//  Created by Matt Adams on 26/02/2026.
//


import SwiftUI

struct CloseButton: View {
    var action: () -> Void
    var size: CGFloat = 32
    var iconSize: CGFloat = 14

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CloseButton {
            dismiss()
        }
    }
}
