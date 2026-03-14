//
//  PremiumTestView.swift
//  Habits
//
//  Created by Matt Adams on 14/03/2026.
//


import SwiftUI

struct PremiumTestView: View {

    @EnvironmentObject var purchaseService: PurchaseService

    var body: some View {

        VStack(spacing: 24) {

            Text("Premium Test")
                .font(.title)

            Text("Premium unlocked: \(purchaseService.isPremiumUnlocked.description)")

            Button("Load Products") {
                Task {
                    await purchaseService.loadProducts()
                }
            }

            Button("Purchase Premium") {
                Task {
                    try? await purchaseService.purchasePremium()
                }
            }

        }
        .padding()

    }

}