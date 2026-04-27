import XCTest
@testable import Habits

final class HeatmapTimelineTests: BaseTestCase {
    private var calendar: Calendar {
        TestDateFactory.utcCalendar
    }

    func testTimelineContains365Days() {
        let endDate = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let timeline = HeatmapTimelineBuilder.yearTimeline(endingAt: endDate, calendar: calendar)
        let mappedDays = timeline.weeks.flatMap { $0.days.compactMap { $0 } }

        XCTAssertEqual(mappedDays.count, 365)
        XCTAssertEqual(mappedDays.first, timeline.startDate)
        XCTAssertEqual(mappedDays.last, timeline.endDate)
        XCTAssertEqual(timeline.endDate, calendar.startOfDay(for: endDate))
    }

    func testWeeksContainSevenCells() {
        let endDate = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let timeline = HeatmapTimelineBuilder.yearTimeline(endingAt: endDate, calendar: calendar)

        XCTAssertFalse(timeline.weeks.isEmpty)
        XCTAssertTrue(timeline.weeks.allSatisfy { $0.days.count == 7 })
    }

    func testWeekGroupingRespectsCalendarFirstWeekday() {
        let endDate = TestDateFactory.date(2026, 3, 11, calendar: calendar)

        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let mondayTimeline = HeatmapTimelineBuilder.yearTimeline(endingAt: endDate, calendar: mondayCalendar)

        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        let sundayTimeline = HeatmapTimelineBuilder.yearTimeline(endingAt: endDate, calendar: sundayCalendar)

        let mondayLeadingNilCount = mondayTimeline.weeks.first?.days.prefix(while: { $0 == nil }).count
        let sundayLeadingNilCount = sundayTimeline.weeks.first?.days.prefix(while: { $0 == nil }).count

        XCTAssertEqual(mondayLeadingNilCount, 2)
        XCTAssertEqual(sundayLeadingNilCount, 3)
    }

    func testDateMapsToCorrectCell() {
        let endDate = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let timeline = HeatmapTimelineBuilder.yearTimeline(endingAt: endDate, calendar: calendar)
        let provider = CalendarProvider(calendar: calendar)

        for week in timeline.weeks {
            for (dayIndex, value) in week.days.enumerated() {
                guard let date = value else { continue }
                XCTAssertEqual(dayIndex, provider.rowIndex(for: date))
            }
        }
    }

    func testMonthBoundaryDetection() {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2

        let endDate = TestDateFactory.date(2026, 3, 11, calendar: mondayCalendar)
        let timeline = HeatmapTimelineBuilder.yearTimeline(endingAt: endDate, calendar: mondayCalendar)
        let marchFirst = mondayCalendar.startOfDay(
            for: TestDateFactory.date(2026, 3, 1, calendar: mondayCalendar)
        )

        guard let marchWeekIndex = timeline.weeks.firstIndex(where: { week in
            week.days.contains(where: { $0 == marchFirst })
        }) else {
            return XCTFail("Expected to find a week containing March 1st")
        }

        XCTAssertEqual(timeline.weeks[marchWeekIndex].month, 2)
        XCTAssertLessThan(marchWeekIndex + 1, timeline.weeks.count)
        XCTAssertEqual(timeline.weeks[marchWeekIndex + 1].month, 3)
    }
}
