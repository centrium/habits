import XCTest
@testable import Habits

final class PaywallViewTests: XCTestCase {
    func testPaywallDisplaysCorrectHeadlineForFeature() async {
        let titles = await MainActor.run {
            [
                PaywallView.title(for: .advancedInsights),
                PaywallView.title(for: .unlimitedHabits),
                PaywallView.title(for: .fullHeatmapHistory),
                PaywallView.title(for: .dataExport),
                PaywallView.title(for: nil)
            ]
        }

        XCTAssertEqual(titles[0], "Unlock Advanced Insights")
        XCTAssertEqual(titles[1], "Track Unlimited Habits")
        XCTAssertEqual(titles[2], "Unlock Your Full Habit History")
        XCTAssertEqual(titles[3], "Export Your Habit Data")
        XCTAssertEqual(titles[4], "Upgrade to Premium")
    }

    func testTriggeredFeatureAppearsFirstInBenefits() async {
        let features = await MainActor.run {
            PaywallView.benefits(for: .advancedInsights).map(\.feature)
        }

        XCTAssertEqual(
            features,
            [.advancedInsights, .unlimitedHabits, .fullHeatmapHistory, .dataExport]
        )
    }

    func testPaywallDisplaysFeatureAnchoredPriceWhenProductAvailable() async {
        let title = await MainActor.run {
            PaywallView.purchaseButtonTitle(feature: .advancedInsights, price: "£9.99")
        }

        XCTAssertEqual(title, "Unlock Advanced Insights – £9.99")
    }

    func testPaywallDisplaysGenericPriceWhenNoFeatureProvided() async {
        let title = await MainActor.run {
            PaywallView.purchaseButtonTitle(price: "£9.99")
        }

        XCTAssertEqual(title, "Unlock Premium – £9.99")
    }

    func testPaywallPreviewMatchesFeature() async {
        let previewDetails = await MainActor.run {
            [
                (
                    PaywallView.preview(for: .advancedInsights)?.kind,
                    PaywallView.preview(for: .advancedInsights)?.rows
                ),
                (
                    PaywallView.preview(for: .unlimitedHabits)?.kind,
                    PaywallView.preview(for: .unlimitedHabits)?.rows
                ),
                (
                    PaywallView.preview(for: .fullHeatmapHistory)?.kind,
                    PaywallView.preview(for: .fullHeatmapHistory)?.rows
                ),
                (
                    PaywallView.preview(for: .dataExport)?.kind,
                    PaywallView.preview(for: .dataExport)?.rows
                )
            ]
        }

        XCTAssertEqual(previewDetails[0].0, .advancedInsights)
        XCTAssertEqual(previewDetails[0].1, ["Momentum Score", "Habit Strength", "Risk Indicator"])
        XCTAssertEqual(previewDetails[1].0, .unlimitedHabits)
        XCTAssertEqual(previewDetails[1].1, ["Habit 4", "Habit 5", "Habit 6"])
        XCTAssertEqual(previewDetails[2].0, .fullHeatmapHistory)
        XCTAssertEqual(previewDetails[3].0, .dataExport)
        XCTAssertEqual(previewDetails[3].1, ["CSV Export", "Last Export: -"])
    }

    func testPaywallShowsNoPreviewWhenFeatureIsNil() async {
        let preview = await MainActor.run {
            PaywallView.preview(for: nil)
        }

        XCTAssertNil(preview)
    }
}
