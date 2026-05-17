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
    /// Renewal / expiration date for the active subscription, if any. Read from
    /// the current StoreKit entitlement so the UI can show the actual date the
    /// user's auto-renew next charges, not a guessed "next year".
    private(set) var activeExpirationDate: Date?
    private(set) var isLoading = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?

    /// Debug-only: when set, refresh() skips overwriting purchasedProductIds.
    private var fakeProActive = false

    init() {
        // Debug-only: pretend the user has a live subscription so the
        // Settings "Pro active" + "Switch to Annual" cards can be visually
        // verified without going through a real StoreKit purchase. Set
        // BEFORE refresh() and guarded so the async entitlement scan
        // doesn't immediately overwrite the fake set.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--fake-pro-monthly") {
            fakeProActive = true
            purchasedProductIds = [AppConfig.proMonthlyProductId]
            activeExpirationDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        } else if args.contains("--fake-pro-yearly") {
            fakeProActive = true
            purchasedProductIds = [AppConfig.proYearlyProductId]
            activeExpirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        }
        updatesTask = Self.listenForTransactions(receiver: self)
        Task { await refresh() }
    }

    var isPro: Bool {
        !purchasedProductIds.isDisjoint(with: [
            AppConfig.proMonthlyProductId,
            AppConfig.proYearlyProductId,
        ])
    }

    /// Which plan the user is currently subscribed to, if any. Yearly takes
    /// precedence over monthly when both are present (StoreKit allows
    /// crossgrade-in-flight where both entitlements transiently exist).
    enum ActivePlan { case monthly, yearly }
    var activePlan: ActivePlan? {
        if purchasedProductIds.contains(AppConfig.proYearlyProductId)  { return .yearly  }
        if purchasedProductIds.contains(AppConfig.proMonthlyProductId) { return .monthly }
        return nil
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
        if fakeProActive { return }
        var owned: Set<String> = []
        var nextRenewal: Date?
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
                if let exp = transaction.expirationDate {
                    // Keep the LATER of the two (covers yearly when both
                    // monthly + yearly are temporarily present mid-crossgrade).
                    nextRenewal = max(nextRenewal ?? exp, exp)
                }
            }
        }
        purchasedProductIds = owned
        activeExpirationDate = nextRenewal
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
