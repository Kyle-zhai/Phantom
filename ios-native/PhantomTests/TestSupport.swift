import Foundation
@testable import Phantom

/// Builds a `Subscription` with sensible defaults so tests only specify the
/// fields they care about. Defaults mirror a fresh OCR/manual import: no usage
/// data, no rating, no overlap, no market comparison.
func makeSub(
    id: String = "netflix",
    name: String = "Netflix",
    // Qualified: bare `Category` is ambiguous with ObjectiveC.Category in the
    // test module (the app module resolves it same-module, tests can't).
    category: Phantom.Category = .entertainment,
    amount: Double = 15.99,
    cycle: BillingCycle = .monthly,
    lastUsedAt: Date? = nil,
    sessionsLast30d: Int = 0,
    userRating: Int? = nil,
    marketAverage: Double = 0,
    hasOverlapWith: [String] = []
) -> Subscription {
    Subscription(
        id: id, name: name, vendor: name, rawDescriptor: nil, brandHex: "000000",
        category: category, amount: amount, cycle: cycle,
        nextBilling: Date().addingTimeInterval(30 * 86_400),
        startedAt: Date().addingTimeInterval(-90 * 86_400),
        lastUsedAt: lastUsedAt, sessionsLast30d: sessionsLast30d,
        userRating: userRating, marketAverage: marketAverage,
        trialEndsAt: nil, hasPriceHike: nil, hasOverlapWith: hasOverlapWith, notes: nil
    )
}
