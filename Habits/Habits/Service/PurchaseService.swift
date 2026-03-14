//
//  PurchaseService.swift
//  Habits
//
//  Created by Matt Adams on 14/03/2026.
//


import Foundation
import StoreKit
import Combine

protocol PremiumEntitlementTransaction {
    var productID: String { get }
}

extension Transaction: PremiumEntitlementTransaction {}

struct StoreCatalogProduct {
    let id: String
    private let storeKitProduct: Product?
    private let purchaseAction: (@MainActor () async throws -> Product.PurchaseResult)?

    init(
        id: String,
        purchaseAction: @escaping @MainActor () async throws -> Product.PurchaseResult = { .userCancelled }
    ) {
        self.id = id
        self.storeKitProduct = nil
        self.purchaseAction = purchaseAction
    }

    init(product: Product) {
        self.id = product.id
        self.storeKitProduct = product
        self.purchaseAction = nil
    }

    @MainActor
    func purchase() async throws -> Product.PurchaseResult {
        if let purchaseAction {
            return try await purchaseAction()
        }

        guard let storeKitProduct else {
            return .userCancelled
        }

        return try await storeKitProduct.purchase()
    }
}

@MainActor
final class PurchaseService: ObservableObject {
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private let userDefaults: UserDefaults
    private let productLoader: ([String]) async throws -> [StoreCatalogProduct]

    @Published var products: [StoreCatalogProduct] = []
    @Published var isPremiumUnlocked: Bool = false

    init(
        userDefaults: UserDefaults = .standard,
        productLoader: (([String]) async throws -> [StoreCatalogProduct])? = nil,
        shouldStartBackgroundTasks: Bool = true
    ) {
        self.userDefaults = userDefaults
        self.productLoader = productLoader ?? { ids in
            let products = try await Product.products(for: ids)
            return products.map(StoreCatalogProduct.init(product:))
        }

        guard shouldStartBackgroundTasks, !Self.isRunningTests else {
            return
        }

        Task {
            await self.loadProducts()
            await self.listenForTransactions()
        }
    }

}

extension PurchaseService {

    func loadProducts() async {

        do {
            let ids = StoreProduct.allCases.map { $0.id }

            products = try await productLoader(ids)

        } catch {
            print("Failed to fetch products: \(error)")
        }

    }

}

extension PurchaseService {

    func purchasePremium() async throws {

        guard let product = products.first(where: { $0.id == StoreProduct.premiumLifetime.id }) else {
            return
        }

        let result = try await product.purchase()

        switch result {

        case .success(let verification):

            let transaction = try checkVerified(verification)

            await transaction.finish()

            unlockPremium()

        case .userCancelled:
            break

        case .pending:
            break

        default:
            break
        }

    }

}

extension PurchaseService {
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {

        switch result {

        case .unverified:
            throw StoreError.failedVerification

        case .verified(let safe):
            return safe
        }

    }

}

extension PurchaseService {

    func unlockPremiumIfNeeded<T: PremiumEntitlementTransaction>(for transaction: T) {
        guard transaction.productID == StoreProduct.premiumLifetime.id else {
            return
        }

        unlockPremium()
    }

}

enum StoreError: Error, Equatable {
    case failedVerification
}


extension PurchaseService {

    func listenForTransactions() async {

        for await result in Transaction.updates {

            do {

                let transaction = try checkVerified(result)

                unlockPremiumIfNeeded(for: transaction)

                await transaction.finish()

            } catch {
                print(error)
            }

        }

    }

}

extension PurchaseService {

    func unlockPremium() {

        isPremiumUnlocked = true
        userDefaults.set(true, forKey: "premium_unlocked")

    }

    func loadEntitlement() {

        isPremiumUnlocked = userDefaults.bool(forKey: "premium_unlocked")

    }

}

extension PurchaseService {

    func restorePurchases() async {

        do {
            try await AppStore.sync()
        } catch {
            print(error)
        }

    }

}
