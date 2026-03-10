import Foundation
import UserNotifications
@testable import Habits

final class MockNotificationCenter: NotificationCenterProtocol {
    enum MockError: Error {
        case addFailed
    }

    enum Call: Equatable {
        case add(String)
        case removePending([String])
        case removeDelivered([String])
    }

    var scheduledRequests: [UNNotificationRequest] = []
    var removedPendingIdentifiers: [[String]] = []
    var removedDeliveredIdentifiers: [[String]] = []
    var registeredCategories: Set<UNNotificationCategory> = []
    var calls: [Call] = []

    var authorizationStatus: UNAuthorizationStatus = .authorized
    var requestAuthorizationResult = true
    var requestAuthorizationCallCount = 0
    var shouldFailAdd = false

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        registeredCategories = categories
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        return requestAuthorizationResult
    }

    func notificationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        if shouldFailAdd {
            throw MockError.addFailed
        }

        scheduledRequests.append(request)
        calls.append(.add(request.identifier))
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(identifiers)
        calls.append(.removePending(identifiers))
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(identifiers)
        calls.append(.removeDelivered(identifiers))
    }
}
