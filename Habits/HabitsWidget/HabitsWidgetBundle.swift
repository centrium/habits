//
//  HabitsWidgetBundle.swift
//  HabitsWidget
//
//  Created by Matt Adams on 20/03/2026.
//

import WidgetKit
import SwiftUI

@main
struct HabitsWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitsWidget()
        HabitIdentityStateWidget()
        HabitFocusWidget()
        HabitConsistencyWidget()
        HabitsWidgetControl()
    }
}
