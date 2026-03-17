//
//  PremiumFeature.swift
//  Habits
//
//  Created by Matt Adams on 15/03/2026.
//


enum PremiumFeature: Equatable, Hashable, Identifiable {
    case unlimitedHabits
    case advancedInsights
    case fullHeatmapHistory
    case dataExport
    case multipleReminders

    var id: Self { self }
}
