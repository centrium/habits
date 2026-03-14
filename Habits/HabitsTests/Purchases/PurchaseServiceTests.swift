import XCTest
import StoreKit
@testable import Habits

final class PurchaseServiceTests: XCTestCase {
    private let premiumProductID = "com.yourapp.habits.premium.lifetime"
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()

        userDefaults = .standard
        userDefaults.removeObject(forKey: "premium_unlocked")
    }

    override func tearDownWithError() throws {
        userDefaults.removeObject(forKey: "premium_unlocked")
        userDefaults = nil

        try super.tearDownWithError()
    }

    func testUnlockPremium_setsPremiumFlagAndPersistsValue() async {
        // GIVEN
        // a purchase service backed by isolated storage
        let service = await makeService()

        // WHEN
        // premium is unlocked
        await MainActor.run {
            service.unlockPremium()
        }
        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        // THEN
        // the in-memory state and persisted entitlement should both be true
        XCTAssertTrue(isPremiumUnlocked)
        XCTAssertTrue(userDefaults.bool(forKey: "premium_unlocked"))
    }

    func testLoadEntitlement_restoresPremiumStateFromStorage() async {
        // GIVEN
        // stored premium entitlement already exists
        userDefaults.set(true, forKey: "premium_unlocked")
        let service = await makeService()

        // WHEN
        // entitlement is loaded from storage
        await MainActor.run {
            service.loadEntitlement()
        }
        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        // THEN
        // premium should be restored
        XCTAssertTrue(isPremiumUnlocked)
    }

    func testLoadEntitlement_defaultsToFalseWhenNoStoredValue() async {
        // GIVEN
        // no stored premium entitlement exists
        let service = await makeService()

        // WHEN
        // entitlement is loaded from empty storage
        await MainActor.run {
            service.loadEntitlement()
        }
        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        // THEN
        // premium should remain locked
        XCTAssertFalse(isPremiumUnlocked)
    }

    func testLoadProducts_populatesProductsArray() async {
        // GIVEN
        // a purchase service with a mocked premium product loader
        var requestedIDs: [String] = []
        let service = await makeService { ids in
            requestedIDs = ids
            return await MainActor.run {
                [StoreCatalogProduct(id: self.premiumProductID)]
            }
        }

        // WHEN
        // products are loaded
        await service.loadProducts()
        let loadedProductIDs = await MainActor.run {
            service.products.map { $0.id }
        }

        // THEN
        // the premium product should be available in memory
        XCTAssertEqual(requestedIDs, [premiumProductID])
        XCTAssertFalse(loadedProductIDs.isEmpty)
        XCTAssertEqual(loadedProductIDs, [premiumProductID])
    }

    func testTransactionVerification_unlocksPremium() async throws {
        // GIVEN
        // a verified premium transaction result
        let service = await makeService()
        let result: VerificationResult<TestTransaction> = .verified(
            TestTransaction(productID: premiumProductID)
        )

        // WHEN
        // the transaction is verified and applied
        let transaction = try await MainActor.run {
            try service.checkVerified(result)
        }
        await MainActor.run {
            service.unlockPremiumIfNeeded(for: transaction)
        }
        let isPremiumUnlocked = await MainActor.run {
            service.isPremiumUnlocked
        }

        // THEN
        // premium should unlock
        XCTAssertTrue(isPremiumUnlocked)
        XCTAssertTrue(userDefaults.bool(forKey: "premium_unlocked"))
    }

    func testTransactionVerification_throwsErrorWhenUnverified() async {
        // GIVEN
        // an unverified premium transaction result
        let service = await makeService()
        let result: VerificationResult<TestTransaction> = .unverified(
            TestTransaction(productID: premiumProductID),
            .invalidEncoding
        )

        // WHEN
        // verification is checked
        // THEN
        // failed verification should be surfaced
        do {
            _ = try await MainActor.run {
                try service.checkVerified(result)
            }
            XCTFail("Expected failed verification error")
        } catch {
            XCTAssertEqual(error as? StoreError, .failedVerification)
        }
    }

    private func makeService(
        productLoader: @escaping ([String]) async throws -> [StoreCatalogProduct] = { _ in [] }
    ) async -> PurchaseService {
        await MainActor.run {
            PurchaseService(
                userDefaults: userDefaults,
                productLoader: productLoader,
                shouldStartBackgroundTasks: false
            )
        }
    }
}

private struct TestTransaction: PremiumEntitlementTransaction {
    let productID: String
}
