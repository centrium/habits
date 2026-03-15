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
    private let fallbackDisplayPrice: String?
    private let purchaseAction: (@MainActor () async throws -> Product.PurchaseResult)?

    init(
        id: String,
        displayPrice: String? = nil,
        purchaseAction: @escaping @MainActor () async throws -> Product.PurchaseResult = { .userCancelled }
    ) {
        self.id = id
        self.storeKitProduct = nil
        self.fallbackDisplayPrice = displayPrice
        self.purchaseAction = purchaseAction
    }

    init(product: Product) {
        self.id = product.id
        self.storeKitProduct = product
        self.fallbackDisplayPrice = nil
        self.purchaseAction = nil
    }

    var displayPrice: String? {
        storeKitProduct?.displayPrice ?? fallbackDisplayPrice
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

    private let productLoader: ([String]) async throws -> [StoreCatalogProduct]
    private let currentEntitlementsLoader: () async -> [any PremiumEntitlementTransaction]
    private var updatesTask: Task<Void, Never>?

    @Published var products: [StoreCatalogProduct] = []
    @Published var isPremiumUnlocked: Bool = false

    var premiumProduct: StoreCatalogProduct? {
        products.first { $0.id == StoreProduct.premiumLifetime.id }
    }

    init(
        productLoader: (([String]) async throws -> [StoreCatalogProduct])? = nil,
        currentEntitlementsLoader: (() async -> [any PremiumEntitlementTransaction])? = nil,
        shouldStartBackgroundTasks: Bool = true
    ) {
        self.productLoader = productLoader ?? { ids in
            let products = try await Product.products(for: ids)
            return products.map(StoreCatalogProduct.init(product:))
        }
        self.currentEntitlementsLoader = currentEntitlementsLoader ?? {
            var entitlements: [any PremiumEntitlementTransaction] = []

            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else {
                    continue
                }

                entitlements.append(transaction)
            }

            return entitlements
        }

        guard shouldStartBackgroundTasks, !Self.isRunningTests else {
            return
        }

        updatesTask = Task {
            await self.listenForTransactions()
        }

        Task {
            await self.loadProducts()
            await self.updateCurrentEntitlements()
        }
    }
    
    deinit {
        updatesTask?.cancel()
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

        guard let product = premiumProduct else {
            return
        }

        let result = try await product.purchase()

        switch result {

        case .success(let verification):
            try await completePurchase(verification) { transaction in
                await transaction.finish()
            }

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

    func completePurchase<T: PremiumEntitlementTransaction>(
        _ verification: VerificationResult<T>,
        finish: (T) async -> Void
    ) async throws {
        let transaction = try checkVerified(verification)
        await finish(transaction)
        await updateCurrentEntitlements()
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

    func unlockPremiumIfNeeded(for transaction: any PremiumEntitlementTransaction) {
        guard transaction.productID == StoreProduct.premiumLifetime.id else { return }
        isPremiumUnlocked = true
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

    }

}

extension PurchaseService {

    func updateCurrentEntitlements() async {
        isPremiumUnlocked = false

        let entitlements = await currentEntitlementsLoader()
        for transaction in entitlements {
            unlockPremiumIfNeeded(for: transaction)
        }
    }

}

extension PurchaseService {

    func restorePurchases() async {

        do {
            try await AppStore.sync()
            await updateCurrentEntitlements()
        } catch {
            print(error)
        }

    }

}

extension PurchaseService {

    func hasAccess(to feature: PremiumFeature) -> Bool {

        if isPremiumUnlocked {
            return true
        }

        switch feature {

        case .unlimitedHabits:
            return false

        case .advancedInsights:
            return false

        case .fullHeatmapHistory:
            return false

        case .dataExport:
            return false
        }
    }
}
