import XCTest
@testable import Habits

final class DeepLinkManagerTests: BaseTestCase {
    func testHabitIDParsesValidHabitURL() async throws {
        let expectedID = UUID()
        let url = try XCTUnwrap(URL(string: "habits://habit/\(expectedID.uuidString)"))

        let parsedID = await MainActor.run { DeepLinkManager.habitID(from: url) }

        XCTAssertEqual(parsedID, expectedID)
    }

    func testHabitIDRejectsNonHabitURL() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/habit/123"))

        let parsedID = await MainActor.run { DeepLinkManager.habitID(from: url) }
        XCTAssertNil(parsedID)
    }

    func testHandleSetsPendingHabitID() async throws {
        let expectedID = UUID()
        let url = try XCTUnwrap(URL(string: "habits://habit/\(expectedID.uuidString)"))

        await MainActor.run {
            let manager = DeepLinkManager()
            manager.handle(url: url)
            XCTAssertEqual(manager.pendingHabitID, expectedID)
            XCTAssertNil(manager.selectedHabitID)
        }
    }

    func testProcessingPendingHabitMovesItToSelected() async {
        let expectedID = UUID()

        await MainActor.run {
            let manager = DeepLinkManager()
            manager.pendingHabitID = expectedID
            manager.processPendingHabitIfNeeded()
            XCTAssertNil(manager.pendingHabitID)
            XCTAssertEqual(manager.selectedHabitID, expectedID)
        }
    }

    func testClearSelectedHabitClearsMatchingIDOnly() async {
        await MainActor.run {
            let manager = DeepLinkManager()
            let selectedID = UUID()
            manager.selectedHabitID = selectedID

            manager.clearSelectedHabit(UUID())
            XCTAssertEqual(manager.selectedHabitID, selectedID)

            manager.clearSelectedHabit(selectedID)
            XCTAssertNil(manager.selectedHabitID)
        }
    }
}
