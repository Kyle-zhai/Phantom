import Foundation

struct ScoreBreakdown {
    let score: Int
    let recencyOfLastUse: Int
    let usageVsPrice: Int
    let overlap: Int
    let userRating: Int
    let priceVsMarket: Int
    /// True when the score is degraded because we don't have user-provided
    /// usage or rating data yet. The UI should prompt for input.
    let hasUnknowns: Bool
}

enum Tier: String {
    case zombie, review, keep

    var label: String {
        switch self {
        case .zombie: return "Zombie"
        case .review: return "Review"
        case .keep:   return "Keep"
        }
    }
}

enum ZombieScore {
    static func clamp(_ value: Double, lo: Double = 0, hi: Double = 100) -> Double {
        max(lo, min(hi, value))
    }

    static func daysSince(_ date: Date?, now: Date = Date()) -> Int {
        guard let date else { return 9999 }
        let secs = now.timeIntervalSince(date)
        return max(0, Int(secs / 86_400))
    }

    /// Compute the zombie score with graceful degradation when usage data is
    /// unknown. For a real OCR-imported sub the user hasn't yet provided
    /// "last opened" or "personal rating" — penalizing those as if the user
    /// said "never" would over-flag every imported sub as a zombie.
    ///
    /// New rules:
    ///   - `lastUsedAt == nil` AND `sessionsLast30d == 0` → unknown,
    ///     use NEUTRAL 50 for recency + usage factors (instead of 100)
    ///   - `userRating == nil` → already neutral 50 (unchanged)
    ///   - `hasUnknowns` flags the *rating* specifically — it's the one signal
    ///     the detail view can still collect (imported usage data is never
    ///     available on-device), so the UI shows an "approximate" nudge until
    ///     the user rates, then stops.
    static func compute(_ sub: Subscription, now: Date = Date()) -> ScoreBreakdown {
        let usageUnknown = sub.lastUsedAt == nil && sub.sessionsLast30d == 0
        let ratingUnknown = sub.userRating == nil
        let hasUnknowns = ratingUnknown

        // Recency factor: 0 days → 0 (keep), 60+ days → 100 (zombie).
        // If we don't know, use 50 (neutral) so we don't false-flag.
        let recencyOfLastUse: Double
        if usageUnknown {
            recencyOfLastUse = 50
        } else {
            let days = Double(daysSince(sub.lastUsedAt, now: now))
            recencyOfLastUse = clamp((days / 60.0) * 100.0)
        }

        // Usage-vs-price: <0.05 sessions/$ → 100, >2 → 0.
        // Neutral 50 when usage is unknown.
        let monthly = sub.monthlyAmount
        let usageVsPrice: Double
        if usageUnknown {
            usageVsPrice = 50
        } else {
            let ratio = monthly > 0 ? Double(sub.sessionsLast30d) / monthly : 0
            usageVsPrice = clamp(100.0 - clamp(ratio / 2.0 * 100.0))
        }

        let overlapCount = Double(sub.hasOverlapWith.count)
        let overlap = clamp(overlapCount * 50.0)

        let userRating: Double = ratingUnknown
            ? 50
            : clamp(Double(5 - (sub.userRating ?? 3)) * 25.0)

        let premium: Double = sub.marketAverage > 0
            ? (monthly - sub.marketAverage) / sub.marketAverage
            : 0
        let priceVsMarket = clamp(premium * 200.0)

        // Adaptive weighting. When real usage data exists (demo/rated subs) we use
        // the full PRD §3.2 weights unchanged. But for an OCR/manually-imported sub
        // the two usage factors (60% of the weight) carry no signal — pinning them
        // at neutral 50 caps the max score at 70, so NO imported sub could ever
        // cross the 80 "zombie" line and the whole product looked empty. Instead,
        // renormalize over the factors we actually have signal for (overlap, your
        // rating, and price-vs-market when known). A lone, unrated sub still scores
        // low, so we don't false-flag; duplicates and low-rated subs can surface.
        var terms: [(value: Double, weight: Double)] = [
            (overlap, 0.20),
            (userRating, 0.15),
        ]
        if usageUnknown {
            if sub.marketAverage > 0 { terms.append((priceVsMarket, 0.05)) }
        } else {
            terms.append((recencyOfLastUse, 0.35))
            terms.append((usageVsPrice, 0.25))
            terms.append((priceVsMarket, 0.05))
        }
        let weightSum = terms.reduce(0) { $0 + $1.weight }
        let score = weightSum > 0
            ? terms.reduce(0) { $0 + $1.value * $1.weight } / weightSum
            : 50

        return ScoreBreakdown(
            score: Int(clamp(score.rounded())),
            recencyOfLastUse: Int(recencyOfLastUse.rounded()),
            usageVsPrice: Int(usageVsPrice.rounded()),
            overlap: Int(overlap.rounded()),
            userRating: Int(userRating.rounded()),
            priceVsMarket: Int(priceVsMarket.rounded()),
            hasUnknowns: hasUnknowns
        )
    }

    static func tier(for score: Int) -> Tier {
        if score >= 80 { return .zombie }
        if score >= 50 { return .review }
        return .keep
    }
}
