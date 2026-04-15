import XCTest
@testable import Habits

final class GreetingServiceTests: XCTestCase {
    func testCurrentGreeting_usesMorningBucket() {
        let service = GreetingService(calendar: TestDateFactory.utcCalendar)
        let date = TestDateFactory.date(2026, 4, 15, hour: 5, minute: 0)

        XCTAssertEqual(service.currentGreeting(date: date), "Good morning")
    }

    func testCurrentGreeting_usesAfternoonBucket() {
        let service = GreetingService(calendar: TestDateFactory.utcCalendar)
        let date = TestDateFactory.date(2026, 4, 15, hour: 16, minute: 59)

        XCTAssertEqual(service.currentGreeting(date: date), "Good afternoon")
    }

    func testCurrentGreeting_usesEveningBucket() {
        let service = GreetingService(calendar: TestDateFactory.utcCalendar)
        let date = TestDateFactory.date(2026, 4, 15, hour: 21, minute: 59)

        XCTAssertEqual(service.currentGreeting(date: date), "Good evening")
    }

    func testCurrentGreeting_usesHelloBucketAtNight() {
        let service = GreetingService(calendar: TestDateFactory.utcCalendar)
        let lateDate = TestDateFactory.date(2026, 4, 15, hour: 22, minute: 0)
        let earlyDate = TestDateFactory.date(2026, 4, 15, hour: 4, minute: 59)

        XCTAssertEqual(service.currentGreeting(date: lateDate), "Hello")
        XCTAssertEqual(service.currentGreeting(date: earlyDate), "Hello")
    }

    func testSessionGreeting_cachesFirstComputedValue() {
        let service = GreetingService(calendar: TestDateFactory.utcCalendar)
        let morningDate = TestDateFactory.date(2026, 4, 15, hour: 6, minute: 0)
        let eveningDate = TestDateFactory.date(2026, 4, 15, hour: 18, minute: 0)

        XCTAssertEqual(service.sessionGreeting(date: morningDate), "Good morning")
        XCTAssertEqual(service.sessionGreeting(date: eveningDate), "Good morning")
    }
}
