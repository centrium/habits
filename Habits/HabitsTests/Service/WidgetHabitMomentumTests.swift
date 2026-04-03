import XCTest
@testable import Habits

final class WidgetHabitMomentumTests: XCTestCase {
    func testLegacyMomentumPayloadDecodesToIdentityState() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000199",
          "name": "Read",
          "isCompleteToday": false,
          "streak": 0,
          "goalType": "binary",
          "momentumScore": 55
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WidgetHabit.self, from: json)
        XCTAssertEqual(decoded.identityState, .building)
    }
}
