import XCTest
@testable import Habits

final class HabitsListTitleTests: BaseTestCase {
    func testListBaseTitleIsCadence() {
        XCTAssertEqual(HabitsListTitleCopy.baseTitle, "Cadence")
    }
}
