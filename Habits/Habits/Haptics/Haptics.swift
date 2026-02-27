//
//  Haptics.swift
//  Habits
//
//  Created by Matt Adams on 25/02/2026.
//


import UIKit

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()

    static func warmUp() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notify.prepare()
    }

    static func impactLight() {
        light.prepare()
        light.impactOccurred()
    }

    static func impactMedium() {
        medium.prepare()
        medium.impactOccurred()
    }

    static func impactHeavy() {
        heavy.prepare()
        heavy.impactOccurred()
    }

    static func success() {
        notify.prepare()
        notify.notificationOccurred(.success)
    }
}
