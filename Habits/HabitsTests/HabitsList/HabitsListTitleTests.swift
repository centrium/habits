import XCTest
@testable import Habits

final class HabitsListTitleTests: XCTestCase {
    func testListBaseTitleIsCadence() {
        XCTAssertEqual(HabitsListTitleCopy.baseTitle, "Cadence")
    }
}
