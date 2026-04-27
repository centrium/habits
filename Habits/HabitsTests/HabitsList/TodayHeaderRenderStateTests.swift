import XCTest
@testable import Habits

final class TodayHeaderRenderStateTests: BaseTestCase {
    func testGreetingPlaceholderIsVisibleBeforeCoachingResolves() {
        let state = TodayHeaderRenderState(
            hasVisibleHabits: true,
            isIntroExpanded: true,
            hasResolvedInitialCoachingInsight: false,
            hasResolvedInitialTodayInsight: false,
            coachingParagraph: nil,
            growthPlanLines: []
        )

        XCTAssertTrue(state.showsGreetingBlock)
        XCTAssertTrue(state.showsGreetingPlaceholder)
    }

    func testGreetingUsesFallbackAfterCoachingResolvesWithoutParagraph() {
        let state = TodayHeaderRenderState(
            hasVisibleHabits: true,
            isIntroExpanded: true,
            hasResolvedInitialCoachingInsight: true,
            hasResolvedInitialTodayInsight: false,
            coachingParagraph: nil,
            growthPlanLines: []
        )

        XCTAssertFalse(state.showsGreetingPlaceholder)
        XCTAssertEqual(
            String(state.resolvedGreetingParagraph.characters),
            TodayHeaderRenderState.fallbackGreetingMessage
        )
    }

    func testGrowthPlanLinesAreCappedAtTwo() {
        let lines: [AttributedString] = [
            AttributedString("First"),
            AttributedString("Second"),
            AttributedString("Third")
        ]
        let state = TodayHeaderRenderState(
            hasVisibleHabits: true,
            isIntroExpanded: true,
            hasResolvedInitialCoachingInsight: true,
            hasResolvedInitialTodayInsight: true,
            coachingParagraph: AttributedString("Paragraph"),
            growthPlanLines: lines
        )

        XCTAssertEqual(state.resolvedGrowthPlanLines.count, TodayHeaderRenderState.growthPlanLineCount)
        XCTAssertEqual(String(state.resolvedGrowthPlanLines[0].characters), "First")
        XCTAssertEqual(String(state.resolvedGrowthPlanLines[1].characters), "Second")
    }

    func testGrowthPlanUsesFallbackWhenNoResolvedLines() {
        let state = TodayHeaderRenderState(
            hasVisibleHabits: true,
            isIntroExpanded: true,
            hasResolvedInitialCoachingInsight: true,
            hasResolvedInitialTodayInsight: true,
            coachingParagraph: AttributedString("Paragraph"),
            growthPlanLines: []
        )

        XCTAssertEqual(state.resolvedGrowthPlanLines.count, 1)
        XCTAssertEqual(
            String(state.resolvedGrowthPlanLines[0].characters),
            TodayHeaderRenderState.fallbackGrowthPlanMessage
        )
    }
}
