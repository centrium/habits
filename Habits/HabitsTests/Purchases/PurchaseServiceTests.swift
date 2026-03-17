import XCTest
import StoreKit
@testable import Habits

@MainActor
final class PurchaseServiceTests: XCTestCase {
    private let premiumProductID = "com.yourapp.habits.premium.lifetime"

    func testUnlockPremium_setsPremiumFlag() async {
        let service = await makeService()

        await MainActor.run {
            service.unlockPremium()
        }

        let premiumStatus = await MainActor.run {
            service.premiumStatus
        }

        XCTAssertEqual(premiumStatus, .premium)
    }

    func testLoadProducts_populatesProductsArray() async {
        var requestedIDs: [String] = []
        let service = await makeService { ids in
            requestedIDs = ids
            return await MainActor.run {
                [StoreCatalogProduct(id: self.premiumProductID)]
            }
        }

        await service.loadProducts()

        let loadedProductIDs = await MainActor.run {
            service.products.map(\.id)
        }

        XCTAssertEqual(requestedIDs, [premiumProductID])
        XCTAssertEqual(loadedProductIDs, [premiumProductID])
    }

    func testTransactionVerification_unlocksPremium() async throws {
        let service = await makeService()
        let result: VerificationResult<TestTransaction> = .verified(
            TestTransaction(productID: premiumProductID)
        )

        let transaction = try await MainActor.run {
            try service.checkVerified(result)
        }

        await MainActor.run {
            service.unlockPremiumIfNeeded(for: transaction)
        }

        let premiumStatus = await MainActor.run {
            service.premiumStatus
        }

        XCTAssertEqual(premiumStatus, .premium)
    }

    func testTransactionVerification_throwsErrorWhenUnverified() async {
        let service = await makeService()
        let result: VerificationResult<TestTransaction> = .unverified(
            TestTransaction(productID: premiumProductID),
            .invalidEncoding
        )

        do {
            _ = try await MainActor.run {
                try service.checkVerified(result)
            }
            XCTFail("Expected failed verification error")
        } catch {
            XCTAssertEqual(error as? StoreError, .failedVerification)
        }
    }

    func testUpdateCurrentEntitlements_resetsPremiumWhenNoTransactions() async {
        let service = await makeService(currentEntitlementsLoader: { [] })

        await MainActor.run {
            service.unlockPremium()
        }

        await service.updateCurrentEntitlements()

        let premiumStatus = await MainActor.run {
            service.premiumStatus
        }

        XCTAssertEqual(premiumStatus, .free)
    }

    func testUpdateCurrentEntitlements_unlocksPremiumForVerifiedTransaction() async {
        let service = await makeService(
            currentEntitlementsLoader: {
                [TestTransaction(productID: self.premiumProductID)]
            }
        )

        await service.updateCurrentEntitlements()

        let premiumStatus = await MainActor.run {
            service.premiumStatus
        }

        XCTAssertEqual(premiumStatus, .premium)
    }

    func testPurchasePremium_updatesEntitlementsAfterSuccessfulPurchase() async throws {
        var didFinishTransaction = false
        var entitlementRefreshCount = 0
        let service = await makeService(
            currentEntitlementsLoader: {
                entitlementRefreshCount += 1
                return [TestTransaction(productID: self.premiumProductID)]
            }
        )
        let verification: VerificationResult<TestTransaction> = .verified(
            TestTransaction(productID: premiumProductID)
        )

        try await service.completePurchase(verification) { _ in
            didFinishTransaction = true
        }

        let premiumStatus = await MainActor.run {
            service.premiumStatus
        }

        XCTAssertTrue(didFinishTransaction)
        XCTAssertEqual(entitlementRefreshCount, 1)
        XCTAssertEqual(premiumStatus, .premium)
    }

    func testPremiumStatusStartsUnknownBeforeEntitlementsLoad() async {
        let service = await makeService()

        let premiumStatus = await MainActor.run {
            service.premiumStatus
        }

        XCTAssertEqual(premiumStatus, .unknown)
    }

    func testFreeUserCanOnlyAddOneReminder() {
        let canAddFirstReminder = ReminderEntitlementPolicy.canAddReminder(
            reminderCount: 0,
            isPremiumUnlocked: false
        )
        let canAddSecondReminder = ReminderEntitlementPolicy.canAddReminder(
            reminderCount: 1,
            isPremiumUnlocked: false
        )

        XCTAssertTrue(canAddFirstReminder)
        XCTAssertFalse(canAddSecondReminder)
    }

    func testPremiumUserCanAddMultipleReminders() {
        let canAddReminder = ReminderEntitlementPolicy.canAddReminder(
            reminderCount: 3,
            isPremiumUnlocked: true
        )

        XCTAssertTrue(canAddReminder)
    }

    private func makeService(
        productLoader: @escaping ([String]) async throws -> [StoreCatalogProduct] = { _ in [] },
        currentEntitlementsLoader: @escaping () async -> [any PremiumEntitlementTransaction] = { [] }
    ) async -> PurchaseService {
        await MainActor.run {
            PurchaseService(
                productLoader: productLoader,
                currentEntitlementsLoader: currentEntitlementsLoader,
                shouldStartBackgroundTasks: false
            )
        }
    }
}

private struct TestTransaction: PremiumEntitlementTransaction {
    let productID: String
}
