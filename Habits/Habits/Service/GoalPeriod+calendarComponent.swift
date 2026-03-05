//
//  GoalPeriod+calendarComponent.swift
//  Habits
//
//  Created by Matt Adams on 05/03/2026.
//

import Foundation

extension GoalPeriod {

    var calendarComponent: Calendar.Component {
        switch self {
        case .daily:
            return .day
        case .weekly:
            return .weekOfYear
        case .monthly:
            return .month
        case .yearly:
            return .year
        }
    }
}
