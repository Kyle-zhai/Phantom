import Foundation

/// Merges the two views of an App Store-billed subscription:
///   - the bank statement, which only shows "APPLE.COM/BILL $19.99"
///     (`apple-services-1999c`, product unknown), and
///   - the Apple subscriptions list, which names it ("Netflix · $19.99/month").
/// Same amount ⇒ same money. The named record wins; the anonymous one is
/// dropped so the user never sees the charge twice, and the bank's earliest
/// date + any rating the user already gave carry over.
enum AppleReconciler {
    struct Outcome: Equatable {
        var incoming: [Subscription]
        var removeExistingIds: Set<String>
    }

    static func sameAmount(_ a: Subscription, _ b: Subscription) -> Bool {
        abs(a.amount - b.amount) < 0.011
    }

    static func isAnonymousAppleCharge(_ s: Subscription) -> Bool {
        s.brandId == "apple-services"
    }

    static func reconcile(existing: [Subscription], incoming: [Subscription]) -> Outcome {
        var remove = Set<String>()
        var out: [Subscription] = []

        let incomingNamed = incoming.filter { $0.billedVia == .apple && !isAnonymousAppleCharge($0) }
        let existingNamed = existing.filter { $0.billedVia == .apple && !isAnonymousAppleCharge($0) }
        let existingAnonymous = existing.filter(isAnonymousAppleCharge)

        for sub in incoming {
            if isAnonymousAppleCharge(sub) {
                // Bank row for an Apple charge. Is it already named?
                if let named = (incomingNamed + existingNamed).first(where: { sameAmount($0, sub) }) {
                    if let idx = out.firstIndex(where: { $0.id == named.id }) {
                        out[idx] = absorb(named: out[idx], anonymous: sub)
                    } else if !incomingNamed.contains(where: { $0.id == named.id }) {
                        // Existing named sub — send an updated copy through the merge.
                        out.append(absorb(named: named, anonymous: sub))
                    }
                    continue
                }
                out.append(sub)
            } else if sub.billedVia == .apple {
                var named = sub
                for anon in existingAnonymous where sameAmount(anon, sub) {
                    named = absorb(named: named, anonymous: anon)
                    remove.insert(anon.id)
                }
                out.append(named)
            } else {
                out.append(sub)
            }
        }
        return Outcome(incoming: out, removeExistingIds: remove)
    }

    /// Named record keeps its identity; the anonymous bank row contributes the
    /// earliest charge date, the user's rating, and the statement descriptor.
    static func absorb(named: Subscription, anonymous: Subscription) -> Subscription {
        let descriptor: String? = {
            guard let raw = anonymous.rawDescriptor, !raw.isEmpty else { return named.rawDescriptor }
            guard let mine = named.rawDescriptor, !mine.contains(raw) else { return named.rawDescriptor }
            return mine + " · on your statement: " + raw
        }()
        return Subscription(
            id: named.id, name: named.name, vendor: named.vendor, rawDescriptor: descriptor,
            brandHex: named.brandHex, category: named.category, amount: named.amount, cycle: named.cycle,
            nextBilling: named.nextBilling, startedAt: min(named.startedAt, anonymous.startedAt),
            lastUsedAt: named.lastUsedAt ?? anonymous.lastUsedAt,
            sessionsLast30d: max(named.sessionsLast30d, anonymous.sessionsLast30d),
            userRating: named.userRating ?? anonymous.userRating,
            marketAverage: named.marketAverage, trialEndsAt: named.trialEndsAt,
            hasPriceHike: named.hasPriceHike ?? anonymous.hasPriceHike,
            hasOverlapWith: named.hasOverlapWith, notes: named.notes, billedVia: .apple
        )
    }
}
