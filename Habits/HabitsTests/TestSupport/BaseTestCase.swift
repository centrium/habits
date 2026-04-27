import XCTest
import SwiftData
@testable import Habits

@MainActor
class BaseTestCase: XCTestCase {
    var testEnvironment: TestEnvironment!

    var modelContext: ModelContext { testEnvironment.modelContext }
    var uiStateStore: HabitUIStateStore { testEnvironment.habitUIStateStore }
    var habitLogService: HabitLogService { testEnvironment.habitLogService }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        await TestEnvironment.resetAll()
        testEnvironment = try TestEnvironment()
    }

    override func tearDown() async throws {
        if let testEnvironment {
            await testEnvironment.tearDown()
        }
        testEnvironment = nil
        await TestEnvironment.resetAll()
        try await super.tearDown()
    }

    @discardableResult
    func trackTask(_ task: Task<Void, Never>) -> Task<Void, Never> {
        testEnvironment.track(task)
    }
}
