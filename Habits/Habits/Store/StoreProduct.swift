//
//  StoreProduct.swift
//  Habits
//
//  Created by Matt Adams on 14/03/2026.
//


enum StoreProduct: String, CaseIterable {
    case premiumLifetime = "com.cadence.lifetime"

    var id: String { rawValue }
}
