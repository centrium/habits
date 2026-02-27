//
//  Item.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
