import SwiftUI
import StoreKit

struct PaywallView: View {
    enum PreviewKind: Equatable {
        case unlimitedHabits
        case advancedInsights
        case fullHeatmapHistory
        case dataExport
    }

    struct BenefitContent: Equatable, Identifiable {
        let feature: PremiumFeature
        let icon: String
        let title: String
        let description: String

        var id: PremiumFeature { feature }
    }

    struct PreviewContent: Equatable {
        let kind: PreviewKind
        let title: String
        let rows: [String]
    }

    let feature: PremiumFeature?

    @EnvironmentObject private var purchaseService: PurchaseService
    @Environment(\.dismiss) private var dismiss
    @State private var highlightedBenefitVisible = false
    @State private var previewVisible = false

    var purchaseButtonTitle: String {
        Self.purchaseButtonTitle(feature: feature, price: purchaseService.premiumProduct?.displayPrice)
    }

    var benefits: [BenefitContent] {
        Self.benefits(for: feature)
    }

    var preview: PreviewContent? {
        Self.preview(for: feature)
    }

    static func purchaseButtonTitle(feature: PremiumFeature?, price: String?) -> String {
        let title: String

        switch feature {
        case .advancedInsights:
            title = "Unlock Advanced Insights"
        case .unlimitedHabits:
            title = "Unlock Unlimited Habits"
        case .fullHeatmapHistory:
            title = "Unlock Full History"
        case .dataExport:
            title = "Unlock Data Export"
        case nil:
            title = "Unlock Premium"
        }

        guard let price, !price.isEmpty else {
            return title
        }

        return "\(title) – \(price)"
    }

    static func purchaseButtonTitle(price: String?) -> String {
        purchaseButtonTitle(feature: nil, price: price)
    }

    static func title(for feature: PremiumFeature?) -> String {
        switch feature {
        case .advancedInsights:
            return "Unlock Advanced Insights"
        case .unlimitedHabits:
            return "Track Unlimited Habits"
        case .fullHeatmapHistory:
            return "Unlock Your Full Habit History"
        case .dataExport:
            return "Export Your Habit Data"
        case nil:
            return "Upgrade to Premium"
        }
    }

    static func benefits(for feature: PremiumFeature?) -> [BenefitContent] {
        let allBenefits = [
            BenefitContent(
                feature: .unlimitedHabits,
                icon: "infinity",
                title: "Unlimited Habits",
                description: "Track as many habits as you like."
            ),
            BenefitContent(
                feature: .advancedInsights,
                icon: "sparkles",
                title: "Advanced Insights",
                description: "Understand momentum, risk, and habit strength."
            ),
            BenefitContent(
                feature: .fullHeatmapHistory,
                icon: "calendar",
                title: "Full Heatmap History",
                description: "Scroll through your entire 365-day journey."
            ),
            BenefitContent(
                feature: .dataExport,
                icon: "square.and.arrow.up",
                title: "Data Export",
                description: "Export your habit data whenever you need."
            )
        ]

        guard let feature,
              let index = allBenefits.firstIndex(where: { $0.feature == feature }) else {
            return allBenefits
        }

        var orderedBenefits = allBenefits
        let prioritizedBenefit = orderedBenefits.remove(at: index)
        orderedBenefits.insert(prioritizedBenefit, at: 0)
        return orderedBenefits
    }

    static func preview(for feature: PremiumFeature?) -> PreviewContent? {
        switch feature {
        case .advancedInsights:
            return PreviewContent(
                kind: .advancedInsights,
                title: "Insights Preview",
                rows: ["Momentum Score", "Habit Strength", "Risk Indicator"]
            )
        case .unlimitedHabits:
            return PreviewContent(
                kind: .unlimitedHabits,
                title: "More Habits",
                rows: ["Habit 4", "Habit 5", "Habit 6"]
            )
        case .fullHeatmapHistory:
            return PreviewContent(
                kind: .fullHeatmapHistory,
                title: "History Preview",
                rows: ["grid"]
            )
        case .dataExport:
            return PreviewContent(
                kind: .dataExport,
                title: "Export Preview",
                rows: ["CSV Export", "Last Export: -"]
            )
        case nil:
            return nil
        }
    }

    var body: some View {

        NavigationStack {

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection

                    previewSection
                        .padding(.top, 30)

                    benefitsSection
                        .padding(.top, preview == nil ? 30 : 22)

                    Color.clear
                        .frame(height: 18)
                }
                .onChange(of: purchaseService.isPremiumUnlocked) { _, unlocked in
                    if unlocked {
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                stickyFooter
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
        .frame(maxWidth: .infinity)
    }

    // MARK: Benefits

    @ViewBuilder
    var previewSection: some View {
        if let preview {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(preview.title)
                    .font(.subheadline.weight(.semibold))

                ZStack(alignment: .topTrailing) {
                    previewCard(for: preview)
                        .frame(maxHeight: 170)
                        .blur(radius: 4)

                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .blur(radius: 8)
                        )
                        .background(
                            Circle()
                                .fill(Color(.systemBackground).opacity(0.82))
                        )
                        .padding(12)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.05))
            )
            .opacity(previewVisible ? 1 : 0.88)
            .scaleEffect(previewVisible ? 1 : 0.97)
            .onAppear {
                previewVisible = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    previewVisible = true
                }
            }
        }
    }

    var benefitsSection: some View {

        VStack(spacing: 16) {

            ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                benefitRow(
                    icon: benefit.icon,
                    title: benefit.title,
                    description: benefit.description,
                    isRecommended: index == 0 && benefit.feature == feature
                )
                .opacity(index == 0 && benefit.feature == feature && !highlightedBenefitVisible ? 0.84 : 1)
                .scaleEffect(index == 0 && benefit.feature == feature && !highlightedBenefitVisible ? 0.97 : 1)
            }

        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            guard feature != nil else { return }
            highlightedBenefitVisible = false
            withAnimation(.easeInOut(duration: 0.22)) {
                highlightedBenefitVisible = true
            }
        }
    }

    // MARK: Purchase

    var stickyFooter: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .allowsHitTesting(false)

            Divider()

            paywallFooter
                .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    var paywallFooter: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    try? await purchaseService.purchasePremium()
                    dismiss()
                }
            } label: {
                Text(purchaseButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .shadow(color: Color.blue.opacity(0.25), radius: 10, y: 4)

            Text("One-time purchase. No subscription.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Restore Purchases") {
                Task {
                    await purchaseService.restorePurchases()
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            Color(.systemBackground).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06))
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
    }

    // MARK: Benefit Row

    @ViewBuilder
    func previewCard(for preview: PreviewContent) -> some View {
        switch preview.kind {
        case .advancedInsights:
            previewMetricCard(rows: preview.rows)
        case .unlimitedHabits:
            previewListCard(rows: preview.rows)
        case .fullHeatmapHistory:
            previewHeatmapCard()
        case .dataExport:
            previewExportCard(rows: preview.rows)
        }
    }

    func previewMetricCard(rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights Snapshot")
                .font(.subheadline.weight(.semibold))

            ForEach(rows, id: \.self) { row in
                HStack {
                    Text(row)
                        .font(.caption.weight(.medium))

                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.22))
                        .frame(width: 54, height: 10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func previewListCard(rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More Habits")
                .font(.subheadline.weight(.semibold))

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.28))
                        .frame(width: 8, height: 8)

                    Text(row)
                        .font(.caption.weight(.medium))

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func previewHeatmapCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("365-Day View")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<8, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    Color.accentColor.opacity(
                                        0.14 + (Double((row + column) % 4) * 0.08)
                                    )
                                )
                                .frame(height: 16)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func previewExportCard(rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Sheet")
                .font(.subheadline.weight(.semibold))

            ForEach(rows, id: \.self) { row in
                HStack {
                    Text(row)
                        .font(.caption.weight(.medium))

                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground).opacity(0.58))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func benefitRow(
        icon: String,
        title: String,
        description: String,
        isRecommended: Bool
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {

                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    if isRecommended {
                        Text("Recommended")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.14))
                            )
                            .foregroundStyle(.secondary)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

            }

            Spacer()
        }
    }

    // MARK: Title

    var title: String {
        Self.title(for: feature)
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
