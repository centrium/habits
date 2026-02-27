//
//  Habit+progrss.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {

    func progress(for date: Date = .now, calendar: Calendar = .current) -> Double? {
        guard hasStreakGoal else { return nil }
        guard streakTarget > 0 else { return nil }

        let interval = periodRange(for: date, calendar: calendar)
        let total = totalCount(in: interval)

        let rawProgress = Double(total) / Double(streakTarget)

        return min(rawProgress, 1.0)
    }
    
    func progressDetails(for date: Date = .now, calendar: Calendar = .current) -> (current: Int, target: Int)? {
          guard hasStreakGoal else { return nil }

          let interval = periodRange(for: date, calendar: calendar)
          let total = totalCount(in: interval)

          return (total, streakTarget)
      }
}
