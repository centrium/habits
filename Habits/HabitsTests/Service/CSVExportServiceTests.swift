import XCTest
@testable import Habits

final class CSVExportServiceTests: BaseTestCase {
    func testExportProducesUserFriendlyCSVFiles() throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar

        let meditate = Habit(
            name: "Meditate",
            colorHex: "#4A8F3A",
            hasStreakGoal: true,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: TestDateFactory.date(2026, 2, 1, hour: 9, minute: 0, second: 0),
            orderIndex: 0
        )
        meditate.logs.append(
            HabitLog(
                timestamp: TestDateFactory.date(2026, 3, 10, hour: 7, minute: 0, second: 0),
                value: 1,
                calendar: calendar
            )
        )
        meditate.logs.append(
            HabitLog(
                day: TestDateFactory.date(2026, 3, 11, hour: 12, minute: 0, second: 0),
                count: 2,
                calendar: calendar
            )
        )

        let walk = Habit(
            name: "Walk",
            colorHex: "#0A7E8C",
            hasStreakGoal: true,
            goalPeriod: .daily,
            goalType: .cumulative,
            targetValue: 5000,
            unit: "steps",
            allowsDecimals: false,
            createdAt: TestDateFactory.date(2026, 2, 5, hour: 10, minute: 10, second: 0),
            orderIndex: 1
        )
        walk.logs.append(
            HabitLog(
                timestamp: TestDateFactory.date(2026, 3, 11, hour: 12, minute: 0, second: 0),
                value: 3200,
                calendar: calendar
            )
        )

        let openHabit = Habit(
            name: "Read, Reflect",
            colorHex: "#662E9B",
            hasStreakGoal: false,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: TestDateFactory.date(2026, 2, 7, hour: 8, minute: 0, second: 0),
            orderIndex: 2
        )
        openHabit.logs.append(
            HabitLog(
                timestamp: TestDateFactory.date(2026, 3, 11, hour: 21, minute: 30, second: 0),
                value: 0.3333333333,
                calendar: calendar
            )
        )

        persistence.insert(meditate)
        persistence.insert(walk)
        persistence.insert(openHabit)
        try persistence.save()

        let service = CSVExportService(modelContext: persistence.context)
        let urls = try service.export()

        XCTAssertEqual(urls.count, 2)

        let expectedDate = Self.utcDateString(Date())
        let expectedHabitName = "habits-export-\(expectedDate).csv"
        let expectedLogsName = "habit-logs-export-\(expectedDate).csv"

        let habitsURL = try XCTUnwrap(urls.first { $0.lastPathComponent == expectedHabitName })
        let logsURL = try XCTUnwrap(urls.first { $0.lastPathComponent == expectedLogsName })

        defer {
            try? FileManager.default.removeItem(at: habitsURL)
            try? FileManager.default.removeItem(at: logsURL)
        }

        let habitsCSV = try String(contentsOf: habitsURL, encoding: .utf8)
        let logsCSV = try String(contentsOf: logsURL, encoding: .utf8)

        let habitLines = habitsCSV.split(separator: "\n").map(String.init)
        XCTAssertEqual(habitLines.first, "name,goal_type,goal_target,created_at,order")
        XCTAssertEqual(habitLines.count, 4)
        XCTAssertTrue(habitLines[1].contains("Meditate,frequency,1,2026-02-01T09:00:00Z,0"))
        XCTAssertTrue(habitLines[2].contains("Walk,cumulative,5000,2026-02-05T10:10:00Z,1"))
        XCTAssertTrue(habitLines[3].contains("\"Read, Reflect\",open,,2026-02-07T08:00:00Z,2"))

        let logLines = logsCSV.split(separator: "\n").map(String.init)
        XCTAssertEqual(logLines.first, "habit,date,value")
        XCTAssertEqual(logLines.count, 5)
        XCTAssertTrue(logLines[1].contains("Meditate,2026-03-10T07:00:00Z,1"))
        XCTAssertTrue(logLines[2].contains("Meditate,2026-03-11T00:00:00Z,2"))
        XCTAssertTrue(logLines[3].contains("Walk,2026-03-11T12:00:00Z,3200"))
        XCTAssertTrue(logLines[4].contains("\"Read, Reflect\",2026-03-11T21:30:00Z,0.33"))

        // User-facing export should not include internal UUIDs.
        XCTAssertFalse(habitsCSV.contains(meditate.id.uuidString))
        XCTAssertFalse(habitsCSV.contains(walk.id.uuidString))
        XCTAssertFalse(habitsCSV.contains(openHabit.id.uuidString))
    }

    private static func utcDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

final class CSVBuilderTests: BaseTestCase {
    func testMakeCSVEscapesCommasQuotesAndNewlines() {
        let csv = CSVBuilder().makeCSV(
            headers: ["name", "note"],
            rows: [["Walk, daily", "He said \"go\"\nnow"]]
        )

        XCTAssertEqual(
            csv,
            "name,note\n\"Walk, daily\",\"He said \"\"go\"\"\nnow\""
        )
    }
}
