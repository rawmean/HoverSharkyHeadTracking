//
//  StoreManager.swift
//  HoverSharky
//
//  StoreKit2 manager for in-app purchases
//

import StoreKit
import Observation

@MainActor
@Observable
class StoreManager {
    static let shared = StoreManager()
    
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isUnlimitedUnlocked = false
    
    private let productID = "Sharkey_ID"
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        // Load initial state from Keychain
        isUnlimitedUnlocked = KeychainHelper.shared.loadBool(forKey: "is_unlimited_unlocked") ?? false
        
        // Start listening for transactions
        updates = observeTransactionUpdates()
        
        Task {
            await fetchProducts()
            await updatePurchasedProducts()
        }
    }
    
    // MARK: - Fetch Products
    
    func fetchProducts() async {
        do {
            products = try await Product.products(for: [productID])
            print("StoreManager: Fetched \(products.count) products")
        } catch {
            print("StoreManager: Failed to fetch products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase() async throws {
        guard let product = products.first(where: { $0.id == productID }) else {
            print("StoreManager: Product not found")
            return
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            print("StoreManager: Purchase successful")
        case .userCancelled:
            print("StoreManager: User cancelled purchase")
        case .pending:
            print("StoreManager: Purchase pending")
        @unknown default:
            break
        }
    }
    
    // MARK: - Update Purchased Products
    
    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == productID {
                    isUnlimitedUnlocked = true
                    KeychainHelper.shared.save(true, forKey: "is_unlimited_unlocked")
                    print("StoreManager: Unlimited unlocked!")
                }
                purchasedProductIDs.insert(transaction.productID)
            } catch {
                print("StoreManager: Failed to verify transaction: \(error)")
            }
        }
    }
    
    // MARK: - Transaction Observer
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await _ in Transaction.updates {
                await self?.updatePurchasedProducts()
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Store Error

enum StoreError: Error {
    case failedVerification
}
