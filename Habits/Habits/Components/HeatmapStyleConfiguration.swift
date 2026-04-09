//
//  HeatmapStyleConfiguration.swift
//  Habits
//
//  Created by Codex on 02/03/2026.
//

import SwiftUI

struct HeatmapStyleConfiguration {
    let cellSize: CGFloat
    let cornerRadius: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let monthLabelHeight: CGFloat
    let dayLabelWidth: CGFloat
    let titleToGridSpacing: CGFloat
    let monthLabelToGridSpacing: CGFloat
    let rowLabelLeadingPadding: CGFloat
    let inactiveStrokeOpacity: Double
    let inactiveStrokeColor: Color
    let inactiveFillOpacity: Double
    let selectedStrokeOpacity: Double
    let selectedStrokeWidth: CGFloat
    let todayStrokeOpacity: Double
    let todayStrokeWidth: CGFloat
    let monthLabelOpacity: Double
    let monthLabelTracking: CGFloat
    let rowLabelOpacity: Double
    let rightEdgeFadeWidth: CGFloat
    let animationStyle: Animation
    let intensityFadeDuration: Double
    let activationSpring: Animation

    static let premiumDefault = HeatmapStyleConfiguration(
        cellSize: 10,
        cornerRadius: 3.2,
        horizontalSpacing: 4,
        verticalSpacing: 6,
        monthLabelHeight: 14,
        dayLabelWidth: 14,
        titleToGridSpacing: 9,
        monthLabelToGridSpacing: 9,
        rowLabelLeadingPadding: 7,
        inactiveStrokeOpacity: 0.080,
        inactiveStrokeColor: Color(red: 0.63, green: 0.70, blue: 0.79),
        inactiveFillOpacity: 0.060,
        selectedStrokeOpacity: 0.40,
        selectedStrokeWidth: 1.5,
        todayStrokeOpacity: 0.28,
        todayStrokeWidth: 1,
        monthLabelOpacity: 0.72,
        monthLabelTracking: 0.8,
        rowLabelOpacity: 0.60,
        rightEdgeFadeWidth: 10,
        animationStyle: AppMotion.feedback,
        intensityFadeDuration: 0.18,
        activationSpring: AppMotion.press
    )
}
