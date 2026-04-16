import SwiftUI
import StoreKit

enum PaywallContext: Equatable, Hashable, Identifiable {
    case multipleReminders
    case dataExport
    case general

    var id: Self { self }
}

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
        let accentPhrase: String?

        var id: PremiumFeature { feature }
    }

    struct PreviewContent: Equatable {
        let kind: PreviewKind
        let title: String
        let rows: [String]
    }

    let feature: PremiumFeature?
    let context: PaywallContext

    @EnvironmentObject private var purchaseService: PurchaseService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var highlightedBenefitVisible = false
    @State private var previewVisible = false

    init(
        feature: PremiumFeature? = nil,
        context: PaywallContext? = nil
    ) {
        self.feature = feature
        self.context = context ?? Self.context(for: feature)
    }

    var purchaseButtonTitle: String {
        Self.purchaseButtonTitle(feature: feature, price: purchaseService.premiumProduct?.displayPrice)
    }

    var benefits: [BenefitContent] {
        if context == .general && feature != nil {
            return Self.benefits(for: feature)
        }

        return Self.benefits(for: context)
    }

    var preview: PreviewContent? {
        Self.preview(for: feature)
    }

    static func context(for feature: PremiumFeature?) -> PaywallContext {
        switch feature {
        case .multipleReminders:
            return .multipleReminders
        case .advancedInsights, .guidanceLayer, .unlimitedHabits, .fullHeatmapHistory, .dataExport, nil:
            return .general
        }
    }

    static func purchaseButtonTitle(feature: PremiumFeature?, price: String?) -> String {
        let title: String

        switch feature {
        case .advancedInsights:
            title = "Unlock Advanced Insights"
        case .guidanceLayer:
            title = "Unlock Premium Guidance"
        case .unlimitedHabits:
            title = "Unlock Unlimited Cadences"
        case .fullHeatmapHistory:
            title = "Unlock Full History"
        case .dataExport:
            title = "Unlock Data Export"
        case .multipleReminders:
            title = "Unlock with Pro"
        case nil:
            title = "Unlock with Pro"
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
            return "See your full pattern"
        case .guidanceLayer:
            return "Get real-time guidance"
        case .unlimitedHabits:
            return "Track Unlimited Cadences"
        case .fullHeatmapHistory:
            return "View your full cadence history"
        case .dataExport:
            return "Export your cadence data"
        case .multipleReminders:
            return title(for: PaywallContext.multipleReminders)
        case nil:
            return "View deeper insights with Pro"
        }
    }

    static func title(for context: PaywallContext) -> String {
        switch context {
        case .multipleReminders:
            return "Stay in rhythm throughout the day"
        case .dataExport:
            return "Export your progress"
        case .general:
            return "View deeper insights with Pro"
        }
    }

    static func benefits(for feature: PremiumFeature?) -> [BenefitContent] {
        let allBenefits = [
            BenefitContent(
                feature: .unlimitedHabits,
                icon: "infinity",
                title: "Unlimited Cadences",
                description: "Track as many cadences as you like.",
                accentPhrase: "as many cadences"
            ),
            BenefitContent(
                feature: .guidanceLayer,
                icon: "waveform.path.ecg.text",
                title: "Premium Guidance",
                description: "Get calm, time-aware prompts that tell you what to do next.",
                accentPhrase: "what to do next"
            ),
            BenefitContent(
                feature: .advancedInsights,
                icon: "sparkles",
                title: "Deeper Insights",
                description: "Understand identity state, risk, and pattern strength.",
                accentPhrase: "pattern strength"
            ),
            BenefitContent(
                feature: .fullHeatmapHistory,
                icon: "calendar",
                title: "Full Heatmap History",
                description: "Review your complete 365-day journey.",
                accentPhrase: "365-day journey"
            ),
            BenefitContent(
                feature: .dataExport,
                icon: "square.and.arrow.up",
                title: "Data Export",
                description: "Keep a portable copy of your cadence data.",
                accentPhrase: "portable copy"
            ),
            BenefitContent(
                feature: .multipleReminders,
                icon: "bell.badge",
                title: "Multiple reminders to stay in rhythm throughout the day",
                description: "Add more than one reminder to reinforce a cadence when it matters.",
                accentPhrase: "when it matters"
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

    static func benefits(for context: PaywallContext) -> [BenefitContent] {
        switch context {
        case .multipleReminders:
            return benefits(for: PremiumFeature.multipleReminders)
        case .dataExport:
            return benefits(for: PremiumFeature.dataExport)
        case .general:
            return benefits(for: nil)
        }
    }

    static func features(for context: PaywallContext) -> [String] {
        benefits(for: context).map(\.title)
    }

    static func preview(for feature: PremiumFeature?) -> PreviewContent? {
        switch feature {
        case .advancedInsights:
            return PreviewContent(
                kind: .advancedInsights,
                title: "Insights Preview",
                rows: ["Identity Signal", "Habit Strength", "Risk Indicator"]
            )
        case .guidanceLayer:
            return PreviewContent(
                kind: .advancedInsights,
                title: "Guidance Preview",
                rows: ["Time-aware prompt", "Pattern-aware prompt", "Identity-aware prompt"]
            )
        case .unlimitedHabits:
            return PreviewContent(
                kind: .unlimitedHabits,
                title: "More Cadences",
                rows: ["Cadence 4", "Cadence 5", "Cadence 6"]
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
        case .multipleReminders:
            return nil
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
                .onChange(of: purchaseService.premiumStatus) { _, status in
                    if status == .premium {
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
    var highlightedFeature: PremiumFeature? {
        switch context {
        case .multipleReminders:
            return .multipleReminders
        case .dataExport:
            return .dataExport
        case .general:
            return feature
        }
    }

    // MARK: Hero

    var heroSection: some View {

        VStack(spacing: 16) {

            CadenceProWordmark(size: .small)
                .frame(maxWidth: .infinity)

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
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)

                    Text("Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? semanticAccent.cadenceAccentPrimary : semanticAccent.cadenceAccentSecondary)
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
                                .fill((colorScheme == .dark ? semanticAccent.cadenceAccentPrimary : semanticAccent.cadenceAccentSecondary).opacity(colorScheme == .dark ? 0.24 : 0.12))
                                .blur(radius: 8)
                        )
                        .background(
                            Circle()
                                .fill(Color.appBackground.opacity(colorScheme == .dark ? 0.82 : 0.92))
                        )
                        .padding(12)
                }
            }
            .padding(20)
            .cadenceSurface(cornerRadius: 18)
            .opacity(previewVisible ? 1 : (colorScheme == .light ? 0.94 : 0.88))
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
                    accentPhrase: benefit.accentPhrase,
                    isRecommended: index == 0 && benefit.feature == highlightedFeature
                )
                .opacity(index == 0 && benefit.feature == highlightedFeature && !highlightedBenefitVisible ? 0.84 : 1)
                .scaleEffect(index == 0 && benefit.feature == highlightedFeature && !highlightedBenefitVisible ? 0.97 : 1)
            }

        }
        .padding(20)
        .cadenceSurface(cornerRadius: 18)
        .onAppear {
            guard highlightedFeature != nil else { return }
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
                    Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04)
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
        .background(colorScheme == .light ? Color.appBackground : Color.clear)
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
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.08) : Color.systemAccent.opacity(0.25),
                radius: colorScheme == .light ? 6 : 10,
                y: 4
            )

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
            Color.appBackground.opacity(colorScheme == .dark ? 0.72 : 1),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.08))
        )
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.03 : 0), radius: colorScheme == .light ? 6 : 0, y: colorScheme == .light ? 2 : 0)
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
                .foregroundStyle(CadenceTokens.Color.Text.primary)

            HStack(spacing: 8) {
                previewSignalPill(label: "Pattern", value: "82")
                previewSignalPill(label: "Risk", value: "Low")
                previewSignalPill(label: "State", value: "Stable")
            }

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    Text(row)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)

                    Spacer()

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(semanticAccent.cadenceAccentSecondary.opacity(colorScheme == .dark ? 0.22 : 0.14))
                            .frame(width: 54, height: 10)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.5 : 0.34))
                            .frame(width: rowSignalWidth(for: row), height: 10)
                    }
                }
            }

            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    semanticAccent.cadenceAccentSecondary.opacity(colorScheme == .dark ? 0.22 : 0.16),
                                    semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.32 : 0.24),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .scaleEffect(x: 1 + (CGFloat(index) * 0.12), y: 1, anchor: .leading)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func previewListCard(rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More Cadences")
                .font(.subheadline.weight(.semibold))

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    Circle()
                        .fill(semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.52 : 0.3))
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
                                    semanticAccent.cadenceAccentSecondary.opacity(
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
                        .fill(Color.appBackground.opacity(colorScheme == .dark ? 0.58 : 0.88))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(semanticAccent.cadenceAccentSecondary.opacity(colorScheme == .dark ? 0.2 : 0.12))
                        }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func benefitRow(
        icon: String,
        title: String,
        description: String,
        accentPhrase: String?,
        isRecommended: Bool
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.98 : 0.78))
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
                                    .fill((colorScheme == .dark ? semanticAccent.cadenceAccentPrimary : semanticAccent.cadenceAccentSecondary).opacity(colorScheme == .dark ? 0.26 : 0.12))
                            )
                            .foregroundStyle(semanticAccent.cadenceAccentPrimary)
                    }
                }

                Text(highlightedDescription(description: description, accentPhrase: accentPhrase))
                    .font(.caption)

            }

            Spacer()
        }
    }

    // MARK: Title

    var title: String {
        if context == .multipleReminders || context == .dataExport || feature == nil {
            return Self.title(for: context)
        }

        return Self.title(for: feature)
    }

    // MARK: Description

    var description: String {
        switch context {
        case .multipleReminders:
            return "Add multiple reminders to reinforce your cadence without missing the moments that matter."
        case .dataExport:
            return "Download your cadence data anytime."
        case .general:
            break
        }

        switch feature {

        case .advancedInsights:
            return "Understand your rhythm with deeper insight signals."

        case .guidanceLayer:
            return "Get calm, real-time guidance that helps you decide what to do next."

        case .unlimitedHabits:
            return "Remove the 3-cadence limit and track as many cadences as you want."

        case .fullHeatmapHistory:
            return "View your complete 365-day heatmap history."

        case .dataExport:
            return "Export your cadence data for backup or analysis."

        case .multipleReminders:
            return "Add multiple reminders to reinforce your cadence without missing the moments that matter."

        case nil:
            return "See your full pattern with premium insight tools."
        }
    }

    private var semanticAccent: CadenceSemanticAccentTokens {
        CadenceTokens.Color.globalSemanticAccent(colorScheme: colorScheme)
    }

    private func rowSignalWidth(for row: String) -> CGFloat {
        switch row {
        case "Identity Signal":
            return 46
        case "Habit Strength":
            return 41
        case "Risk Indicator":
            return 34
        default:
            return 38
        }
    }

    private func previewSignalPill(label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(CadenceTokens.Color.Text.secondary)

            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(semanticAccent.cadenceAccentPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(semanticAccent.cadenceAccentSecondary.opacity(colorScheme == .dark ? 0.14 : 0.09))
        )
    }

    private func highlightedDescription(description: String, accentPhrase: String?) -> AttributedString {
        var attributed = AttributedString(description)
        attributed.foregroundColor = CadenceTokens.Color.Text.secondary

        guard let accentPhrase,
              let stringRange = description.range(of: accentPhrase, options: [.caseInsensitive, .diacriticInsensitive]),
              let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
              let upper = AttributedString.Index(stringRange.upperBound, within: attributed) else {
            return attributed
        }

        let range = lower..<upper
        attributed[range].foregroundColor = colorScheme == .dark
            ? semanticAccent.cadenceAccentPrimary
            : semanticAccent.cadenceAccentSecondary

        return attributed
    }
}
