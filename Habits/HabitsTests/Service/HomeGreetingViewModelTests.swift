import XCTest
@testable import Habits

final class HomeGreetingViewModelTests: XCTestCase {
    func testDisplayText_includesNameWithCommaWhenNameExists() {
        let text = HomeGreetingViewModel.displayText(
            greeting: "Good morning",
            firstName: "Matt"
        )

        XCTAssertEqual(text, "Good morning, Matt")
    }

    func testDisplayText_omitsCommaWhenNameIsNil() {
        let text = HomeGreetingViewModel.displayText(
            greeting: "Good morning",
            firstName: nil
        )

        XCTAssertEqual(text, "Good morning")
    }

    func testDisplayText_omitsCommaWhenNameIsEmpty() {
        let text = HomeGreetingViewModel.displayText(
            greeting: "Good morning",
            firstName: "   "
        )

        XCTAssertEqual(text, "Good morning")
    }
}
