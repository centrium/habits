//
//  InsightModel.swift
//  Habits
//
//  Created by Matt Adams on 04/03/2026.
//

import SwiftUI

struct DailyProgress {
    let date: Date
    let progress: Double
}

struct HabitInsights {
    let completionRate: Double
    let completionWindowLabel: String
    
    let progressSeries: [DailyProgress]
    
    let averagePerDay: Double
    
    let currentStreak: Int
    let longestStreak: Int
    
    let momentumPercentage: Double
    
    let reinforcementMessage: String
}
