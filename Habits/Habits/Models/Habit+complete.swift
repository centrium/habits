//
//  Habit+isCurrentPeriodComplete.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {

    func isCurrentPeriodComplete(today: Date = .now) -> Bool {
        guard hasStreakGoal else { return false }
        let interval = periodRange(for: today)
        return hasHitTarget(in: interval)
    }
    
    func isComplete(for date: Date = .now) -> Bool {
        progress(for: date) == 1.0
    }
}
