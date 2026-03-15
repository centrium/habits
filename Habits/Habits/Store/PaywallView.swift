import SwiftUI
import StoreKit

struct PaywallView: View {

    let feature: PremiumFeature?

    @EnvironmentObject private var purchaseService: PurchaseService
    @Environment(\.dismiss) private var dismiss

    var purchaseButtonTitle: String {
        Self.purchaseButtonTitle(price: purchaseService.premiumProduct?.displayPrice)
    }

    static func purchaseButtonTitle(price: String?) -> String {
        guard let price, !price.isEmpty else {
            return "Unlock Premium"
        }

        return "Unlock Premium - \(price)"
    }

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 32) {

                    heroSection

                    benefitsSection

                    purchaseSection

                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)

            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension PaywallView {

    // MARK: Hero

    var heroSection: some View {

        VStack(spacing: 16) {

            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color(red: 0.82, green: 0.68, blue: 0.42))

            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

        }
        .padding(.top, 8)
    }

    // MARK: Benefits

    var benefitsSection: some View {

        VStack(spacing: 16) {

            benefitRow(
                icon: "infinity",
                title: "Unlimited Habits",
                description: "Track as many habits as you like."
            )

            benefitRow(
                icon: "sparkles",
                title: "Advanced Insights",
                description: "Understand momentum, risk, and habit strength."
            )

            benefitRow(
                icon: "calendar",
                title: "Full Heatmap History",
                description: "Scroll through your entire 365-day journey."
            )

            benefitRow(
                icon: "square.and.arrow.up",
                title: "Data Export",
                description: "Export your habit data whenever you need."
            )

        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: Purchase

    var purchaseSection: some View {

        VStack(spacing: 16) {

            Button {

                Task {
                    try? await purchaseService.purchasePremium()
                    dismiss()
                }

            } label: {

                Text(purchaseButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)

            }

            Button("Restore Purchases") {

                Task {
                    await purchaseService.restorePurchases()
                }

            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

        }
    }

    // MARK: Benefit Row

    func benefitRow(
        icon: String,
        title: String,
        description: String
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

            }

            Spacer()
        }
    }

    // MARK: Title

    var title: String {

        switch feature {

        case .advancedInsights:
            return "Unlock Advanced Insights"

        case .unlimitedHabits:
            return "Track Unlimited Habits"

        case .fullHeatmapHistory:
            return "Unlock Full Heatmap History"

        case .dataExport:
            return "Export Your Habit Data"

        case nil:
            return "Upgrade to Premium"
        }
    }

    // MARK: Description

    var description: String {

        switch feature {

        case .advancedInsights:
            return "See deeper behavioural analytics about your habits."

        case .unlimitedHabits:
            return "Remove the 3-habit limit and track as many habits as you want."

        case .fullHeatmapHistory:
            return "View your complete 365-day heatmap history."

        case .dataExport:
            return "Export your habit data for backup or analysis."

        case nil:
            return "Unlock the full power of Habits with premium features."
        }
    }
}
