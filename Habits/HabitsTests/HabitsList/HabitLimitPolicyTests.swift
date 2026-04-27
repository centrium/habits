import XCTest
@testable import Habits

@MainActor
final class HabitLimitPolicyTests: BaseTestCase {
    func testFreeUserCanCreateHabitsBelowLimit() {
        // GIVEN
        let policy = HabitLimitPolicy(
            habitCount: 2,
            hasUnlimitedHabitsAccess: false
        )

        // WHEN
        let destination = policy.addHabitDestination

        // THEN
        XCTAssertEqual(destination, .addHabitSheet)
    }

    func testFreeUserBlockedAtFourthHabit() {
        // GIVEN
        let policy = HabitLimitPolicy(
            habitCount: 3,
            hasUnlimitedHabitsAccess: false
        )

        // WHEN
        let destination = policy.addHabitDestination

        // THEN
        XCTAssertNotEqual(destination, .addHabitSheet)
        XCTAssertEqual(destination, .paywall(feature: .unlimitedHabits))
    }

    func testPremiumUserHasUnlimitedHabits() {
        // GIVEN
        let policy = HabitLimitPolicy(
            habitCount: 3,
            hasUnlimitedHabitsAccess: true
        )

        // WHEN
        let destination = policy.addHabitDestination

        // THEN
        XCTAssertEqual(destination, .addHabitSheet)
    }

    func testUpgradeHintLogic() {
        // GIVEN
        let policy = HabitLimitPolicy(
            habitCount: 2,
            hasUnlimitedHabitsAccess: false
        )

        // WHEN
        let isHintVisible = policy.showsUpgradeHint

        // THEN
        XCTAssertTrue(isHintVisible)
    }

    func testLockedSlotVisibility() {
        // GIVEN
        let policy = HabitLimitPolicy(
            habitCount: 3,
            hasUnlimitedHabitsAccess: false
        )

        // WHEN
        let showsLockedSlot = policy.showsLockedSlot

        // THEN
        XCTAssertTrue(showsLockedSlot)
    }

    func testLockedSlotHiddenForPremium() {
        // GIVEN
        let policy = HabitLimitPolicy(
            habitCount: 3,
            hasUnlimitedHabitsAccess: true
        )

        // WHEN
        let showsLockedSlot = policy.showsLockedSlot

        // THEN
        XCTAssertFalse(showsLockedSlot)
    }
}
