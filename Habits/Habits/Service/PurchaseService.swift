//
//  PurchaseService.swift
//  Habits
//
//  Created by Matt Adams on 14/03/2026.
//


import Foundation
import StoreKit
import Combine

enum PremiumStatus: Equatable {
    case unknown
    case free
    case premium
}

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
    private enum Keys {
        static let cachedPremiumUnlocked = "purchase.cachedPremiumUnlocked"
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private let productLoader: ([String]) async throws -> [StoreCatalogProduct]
    private let currentEntitlementsLoader: () async -> [any PremiumEntitlementTransaction]
    private let premiumStatusStore: any SettingsKeyValueStore
    private var updatesTask: Task<Void, Never>?

    @Published var products: [StoreCatalogProduct] = []
    @Published var premiumStatus: PremiumStatus = .unknown {
        didSet {
            persistPremiumStatus(premiumStatus)
        }
    }
    @Published var isLoadingProducts: Bool = false
    @Published var hasLoadedProducts: Bool = false
    @Published var productLoadError: String?

    var isPremiumUnlocked: Bool {
        premiumStatus == .premium
    }

    var premiumProduct: StoreCatalogProduct? {
        products.first { $0.id == StoreProduct.premiumLifetime.id }
    }

    init(
        productLoader: (([String]) async throws -> [StoreCatalogProduct])? = nil,
        currentEntitlementsLoader: (() async -> [any PremiumEntitlementTransaction])? = nil,
        premiumStatusStore: (any SettingsKeyValueStore)? = nil,
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
        self.premiumStatusStore = premiumStatusStore ?? UserDefaultsSettingsStore()
        self.premiumStatus = Self.bootstrapPremiumStatus(from: self.premiumStatusStore)

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

private extension PurchaseService {
    static func bootstrapPremiumStatus(from store: any SettingsKeyValueStore) -> PremiumStatus {
        (store.bool(forKey: Keys.cachedPremiumUnlocked) ?? false) ? .premium : .free
    }

    func persistPremiumStatus(_ status: PremiumStatus) {
        switch status {
        case .premium:
            premiumStatusStore.set(true, forKey: Keys.cachedPremiumUnlocked)
        case .free:
            premiumStatusStore.set(false, forKey: Keys.cachedPremiumUnlocked)
        case .unknown:
            break
        }
    }
}

extension PurchaseService {

    func loadProducts() async {

        isLoadingProducts = true
        productLoadError = nil

        let ids = StoreProduct.allCases.map(\.id)

        print("Bundle ID:", Bundle.main.bundleIdentifier ?? "nil")
        print("Requesting product IDs:", ids)

        do {
            let loadedProducts = try await productLoader(ids)

            products = loadedProducts

            print("Loaded products count:", loadedProducts.count)

            if loadedProducts.isEmpty {
                productLoadError = "No products returned from App Store Connect"
            }

        } catch {
            print("Failed to fetch products:", error)
            products = []
            productLoadError = error.localizedDescription
        }

        hasLoadedProducts = true
        isLoadingProducts = false

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
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateCurrentEntitlements()
            
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
        premiumStatus = .premium
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

                await transaction.finish()
                await updateCurrentEntitlements()

            } catch {
                print(error)
            }

        }

    }

}

extension PurchaseService {

    func unlockPremium() {
        premiumStatus = .premium
    }

}

extension PurchaseService {

    func updateCurrentEntitlements() async {
        print("Checking entitlements...")
        let entitlements = await currentEntitlementsLoader()

        print("Entitlements count:", entitlements.count)

        var resolvedStatus: PremiumStatus = .free
        for transaction in entitlements {
            print("Transaction:", transaction.productID)
            if transaction.productID == StoreProduct.premiumLifetime.id {
                resolvedStatus = .premium
            }
        }
        premiumStatus = resolvedStatus
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
        if premiumStatus == .premium {
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

        case .multipleReminders:
            return false
        }
    }
}
