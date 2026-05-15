import Foundation
import StoreKit
import Observation

/// Real StoreKit 2 purchase flow.
///
/// Wiring:
///   - `Phantom.storekit` describes the Pro Monthly & Pro Annual auto-renewing subs.
///   - In the Xcode scheme this file is set as the StoreKit Configuration so purchases
///     work in the simulator without App Store Connect.
///   - On a real device / production, the same product IDs must exist in App Store Connect.
@MainActor
@Observable
final class PurchaseService {
    static let shared = PurchaseService()

    private(set) var products: [Product] = []
    private(set) var purchasedProductIds: Set<String> = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Self.listenForTransactions(receiver: self)
        Task { await refresh() }
    }

    var isPro: Bool {
        !purchasedProductIds.isDisjoint(with: [
            AppConfig.proMonthlyProductId,
            AppConfig.proYearlyProductId,
        ])
    }

    var monthly: Product? {
        products.first { $0.id == AppConfig.proMonthlyProductId }
    }

    var yearly: Product? {
        products.first { $0.id == AppConfig.proYearlyProductId }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let ids: Set<String> = [AppConfig.proMonthlyProductId, AppConfig.proYearlyProductId]
            let fetched = try await Product.products(for: ids)
            products = fetched.sorted { $0.price < $1.price }
            await refreshEntitlements()
        } catch {
            lastError = "Load failed: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    purchasedProductIds.insert(transaction.productID)
                    await transaction.finish()
                    return true
                } else {
                    lastError = "Receipt could not be verified."
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                lastError = "Purchase pending (parental approval or SCA)."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        purchasedProductIds = owned
    }

    private static func listenForTransactions(receiver: PurchaseService) -> Task<Void, Never> {
        Task.detached { @Sendable [weak receiver] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    let id = transaction.productID
                    await MainActor.run {
                        receiver?.purchasedProductIds.insert(id)
                    }
                    await transaction.finish()
                }
            }
        }
    }
}
