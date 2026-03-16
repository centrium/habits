import XCTest
@testable import Habits

final class PremiumHistoryGateTests: XCTestCase {
    private var calendar: Calendar {
        TestDateFactory.utcCalendar
    }

    func testFreeUserLocksDatesOlderThanNinetyDays() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let lockedDate = calendar.date(byAdding: .day, value: -91, to: now)!

        // WHEN
        let isLocked = PremiumHistoryGate.isLocked(
            date: lockedDate,
            premiumStatus: .free,
            calendar: calendar,
            now: now
        )

        // THEN
        XCTAssertTrue(isLocked)
    }

    func testFreeUserAllowsDatesWithinLastNinetyDays() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let allowedDate = calendar.date(byAdding: .day, value: -30, to: now)!

        // WHEN
        let isLocked = PremiumHistoryGate.isLocked(
            date: allowedDate,
            premiumStatus: .free,
            calendar: calendar,
            now: now
        )

        // THEN
        XCTAssertFalse(isLocked)
    }

    func testPremiumUserUnlocksAllDates() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let historicalDate = calendar.date(byAdding: .day, value: -300, to: now)!

        // WHEN
        let isLocked = PremiumHistoryGate.isLocked(
            date: historicalDate,
            premiumStatus: .premium,
            calendar: calendar,
            now: now
        )

        // THEN
        XCTAssertFalse(isLocked)
    }

    func testLockedCellsHideActivityIntensity() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let lockedDate = calendar.date(byAdding: .day, value: -91, to: now)!
        let gate = PremiumHistoryGate.Context(
            calendar: calendar,
            premiumStatus: .free,
            now: now
        )
        let rawIntensity = 0.85

        // WHEN
        let visibleIntensity = gate.visibleIntensity(for: rawIntensity, on: lockedDate)

        // THEN
        XCTAssertEqual(visibleIntensity, 0)
    }

    func testAccessibleCellsKeepActivityIntensity() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let visibleDate = calendar.date(byAdding: .day, value: -30, to: now)!
        let gate = PremiumHistoryGate.Context(
            calendar: calendar,
            premiumStatus: .free,
            now: now
        )
        let rawIntensity = 0.55

        // WHEN
        let visibleIntensity = gate.visibleIntensity(for: rawIntensity, on: visibleDate)

        // THEN
        XCTAssertEqual(visibleIntensity, rawIntensity)
    }

    func testPremiumUsersSeeFullIntensityHistory() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let historicalDate = calendar.date(byAdding: .day, value: -300, to: now)!
        let gate = PremiumHistoryGate.Context(
            calendar: calendar,
            premiumStatus: .premium,
            now: now
        )
        let rawIntensity = 0.62

        // WHEN
        let visibleIntensity = gate.visibleIntensity(for: rawIntensity, on: historicalDate)

        // THEN
        XCTAssertEqual(visibleIntensity, rawIntensity)
    }

    func testLockedCellsUseLockedStyle() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let lockedDate = calendar.date(byAdding: .day, value: -91, to: now)!
        let gate = PremiumHistoryGate.Context(
            calendar: calendar,
            premiumStatus: .free,
            now: now
        )

        // WHEN
        let usesLockedStyle = gate.usesLockedStyle(on: lockedDate)

        // THEN
        XCTAssertTrue(usesLockedStyle)
    }
}
