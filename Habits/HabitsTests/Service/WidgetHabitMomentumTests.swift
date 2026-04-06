import XCTest
@testable import Habits

@MainActor
final class WidgetHabitIdentityFallbackTests: XCTestCase {
    func testMissingIdentityStateDefaultsToStarting() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000199",
          "name": "Read",
          "isCompleteToday": false,
          "streak": 0,
          "goalType": "binary"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WidgetHabit.self, from: json)
        XCTAssertEqual(decoded.identityState, .gettingStarted)
    }
}
