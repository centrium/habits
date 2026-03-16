import XCTest
import StoreKit
@testable import Habits

final class PurchaseServiceTests: XCTestCase {
    private let premiumProductID = "com.yourapp.habits.premium.lifetime"

    func testUnlockPremium_setsPremiumFlag() async {
        let service = await makeService()

        await MainActor.run {
            service.unlockPremium()
        }

        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        XCTAssertTrue(isPremiumUnlocked)
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

        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        XCTAssertTrue(isPremiumUnlocked)
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

        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        XCTAssertFalse(isPremiumUnlocked)
    }

    func testUpdateCurrentEntitlements_unlocksPremiumForVerifiedTransaction() async {
        let service = await makeService(
            currentEntitlementsLoader: {
                [TestTransaction(productID: self.premiumProductID)]
            }
        )

        await service.updateCurrentEntitlements()

        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        XCTAssertTrue(isPremiumUnlocked)
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

        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        XCTAssertTrue(didFinishTransaction)
        XCTAssertEqual(entitlementRefreshCount, 1)
        XCTAssertTrue(isPremiumUnlocked)
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
