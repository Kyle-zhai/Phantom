import Foundation

/// How strongly something the user already pays for covers this subscription.
enum CoverageLevel: Int, Comparable, Codable {
    case none = 0
    /// A perk you own makes it cheaper (carrier $10 add-on, member price).
    case discounted
    /// A card statement credit reimburses part or all of it.
    case credit
    /// It is literally included in a bundle you already pay for.
    case included

    static func < (a: CoverageLevel, b: CoverageLevel) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .none: return "Not covered"
        case .discounted: return "Cheaper through a perk you have"
        case .credit: return "Reimbursed by a card credit"
        case .included: return "Already included in something you pay for"
        }
    }
}

/// Signals the store knows about a sub that the sub itself doesn't carry:
/// bundle coverage and catalog prices. Tests and previews pass `.none`.
struct ScoreContext {
    var coverage: CoverageLevel = .none
    /// Cheapest paid tier of the SAME service (e.g. Netflix with ads). When the
    /// user pays well above it, they're overpaying for features they may not use.
    var cheapestTierMonthly: Double? = nil
    /// Median price of same-kind services in the catalog — fallback market
    /// comparison when the service has no tier data.
    var kindMedianMonthly: Double? = nil

    static let none = ScoreContext()
}

enum ScoreFactor: String, CaseIterable, Hashable {
    case recency, usage, overlap, rating, price, coverage, hike

    var label: String {
        switch self {
        case .recency: return "Last opened"
        case .usage: return "Use vs price"
        case .overlap: return "Overlap"
        case .rating: return "Your rating"
        case .price: return "Vs cheaper plan"
        case .coverage: return "Already covered"
        case .hike: return "Recent price hike"
        }
    }
}

struct ScoreBreakdown {
    let score: Int
    let recencyOfLastUse: Int
    let usageVsPrice: Int
    let overlap: Int
    let userRating: Int
    let priceVsMarket: Int
    let coverage: Int
    let priceHike: Int
    /// True when the score is degraded because we don't have the user's rating
    /// yet. The UI should prompt for input.
    let hasUnknowns: Bool
    /// True when real usage data exists (demo / future integrations) and the
    /// full PRD §3.2 weights apply.
    let usageKnown: Bool
    /// Effective (renormalized) weight of every factor that carried signal.
    /// Sums to 1. Factors absent from the map contributed nothing.
    let weights: [ScoreFactor: Double]

    func weight(_ factor: ScoreFactor) -> Double { weights[factor] ?? 0 }

    func value(_ factor: ScoreFactor) -> Int {
        switch factor {
        case .recency: return recencyOfLastUse
        case .usage: return usageVsPrice
        case .overlap: return overlap
        case .rating: return userRating
        case .price: return priceVsMarket
        case .coverage: return coverage
        case .hike: return priceHike
        }
    }
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

    /// A hike counts while it is recent enough that the user may not have
    /// reacted yet: announced up to 30 days ahead, or effective within 180 days.
    static func hikeIsRelevant(_ hike: PriceHike, now: Date) -> Bool {
        let delta = hike.effective.timeIntervalSince(now) / 86_400
        return delta <= 30 && delta >= -180 && hike.to > hike.from
    }

    /// Compute the zombie score.
    ///
    /// Two regimes:
    ///   - **Usage known** (demo data / future integrations): the full PRD §3.2
    ///     weights, unchanged — recency 35, use-vs-price 25, overlap 20, rating
    ///     15, price 5.
    ///   - **Usage unknown** (every real import — iOS gives an app no usage data
    ///     for other apps): renormalize over the signals we actually have.
    ///     Overlap (same-kind duplicates) and the user's rating are always in;
    ///     a neutral 50 stands in for an unrated sub so a lone unrated import
    ///     stays "keep". Bundle coverage ("you already pay for this"), the gap
    ///     to the service's cheapest tier, and a recent hike join only when
    ///     present. Weights when everything is present: overlap 25, coverage 30,
    ///     rating 35, price 10, hike 5.
    ///
    /// Calibration points (usage unknown): lone unrated → keep; two same-kind
    /// duplicates → review; duplicates + rated 1★ → zombie; rated 1★ alone →
    /// review; covered by an owned bundle → review; covered + 1★ → zombie;
    /// rated 5★ stays keep even with duplicates.
    static func compute(_ sub: Subscription, context: ScoreContext = .none, now: Date = Date()) -> ScoreBreakdown {
        let usageUnknown = sub.lastUsedAt == nil && sub.sessionsLast30d == 0
        let ratingUnknown = sub.userRating == nil
        let monthly = sub.monthlyAmount

        // Recency factor: 0 days → 0 (keep), 60+ days → 100 (zombie).
        let recencyOfLastUse: Double
        if usageUnknown {
            recencyOfLastUse = 50
        } else {
            let days = Double(daysSince(sub.lastUsedAt, now: now))
            recencyOfLastUse = clamp((days / 60.0) * 100.0)
        }

        // Usage-vs-price: <0.05 sessions/$ → 100, >2 → 0.
        let usageVsPrice: Double
        if usageUnknown {
            usageVsPrice = 50
        } else {
            let ratio = monthly > 0 ? Double(sub.sessionsLast30d) / monthly : 0
            usageVsPrice = clamp(100.0 - clamp(ratio / 2.0 * 100.0))
        }

        // Overlap: each same-kind duplicate adds 50. A bundle that already
        // includes this sub counts as one more duplicate — you hold it twice.
        let peerCount = Double(sub.hasOverlapWith.count) + (context.coverage == .included ? 1 : 0)
        let overlap = clamp(peerCount * 50.0)

        let userRating: Double = ratingUnknown
            ? 50
            : clamp(Double(5 - (sub.userRating ?? 3)) * 25.0)

        // Price: prefer the gap to the same service's cheapest paid tier; fall
        // back to the legacy market-average premium, then to the kind median.
        var priceVsMarket: Double = 0
        var priceHasSignal = false
        if let cheapest = context.cheapestTierMonthly, cheapest > 0, monthly > cheapest + 0.5 {
            priceVsMarket = clamp((monthly - cheapest) / monthly * 150.0)
            priceHasSignal = true
        } else if context.cheapestTierMonthly != nil && context.cheapestTierMonthly! > 0 {
            priceVsMarket = 0
            priceHasSignal = true
        } else if sub.marketAverage > 0 {
            priceVsMarket = clamp((monthly - sub.marketAverage) / sub.marketAverage * 200.0)
            priceHasSignal = true
        } else if let median = context.kindMedianMonthly, median > 0 {
            priceVsMarket = clamp((monthly - median) / median * 200.0)
            priceHasSignal = true
        }

        let coverage: Double
        switch context.coverage {
        case .none: coverage = 0
        case .discounted: coverage = 40
        case .credit: coverage = 70
        case .included: coverage = 100
        }

        var priceHike: Double = 0
        var hikeHasSignal = false
        if let hike = sub.hasPriceHike, hikeIsRelevant(hike, now: now), hike.from > 0 {
            priceHike = clamp((hike.to - hike.from) / hike.from * 400.0)
            hikeHasSignal = true
        }

        var terms: [(factor: ScoreFactor, value: Double, weight: Double)] = []
        if usageUnknown {
            terms.append((.overlap, overlap, 0.25))
            if context.coverage != .none { terms.append((.coverage, coverage, 0.30)) }
            terms.append((.rating, userRating, 0.35))
            if priceHasSignal { terms.append((.price, priceVsMarket, 0.10)) }
            if hikeHasSignal { terms.append((.hike, priceHike, 0.05)) }
        } else {
            terms.append((.recency, recencyOfLastUse, 0.35))
            terms.append((.usage, usageVsPrice, 0.25))
            terms.append((.overlap, overlap, 0.20))
            terms.append((.rating, userRating, 0.15))
            terms.append((.price, priceVsMarket, 0.05))
        }
        let weightSum = terms.reduce(0) { $0 + $1.weight }
        let score = weightSum > 0
            ? terms.reduce(0) { $0 + $1.value * $1.weight } / weightSum
            : 50
        var weights: [ScoreFactor: Double] = [:]
        for t in terms { weights[t.factor] = weightSum > 0 ? t.weight / weightSum : 0 }

        return ScoreBreakdown(
            score: Int(clamp(score.rounded())),
            recencyOfLastUse: Int(recencyOfLastUse.rounded()),
            usageVsPrice: Int(usageVsPrice.rounded()),
            overlap: Int(overlap.rounded()),
            userRating: Int(userRating.rounded()),
            priceVsMarket: Int(priceVsMarket.rounded()),
            coverage: Int(coverage.rounded()),
            priceHike: Int(priceHike.rounded()),
            hasUnknowns: ratingUnknown,
            usageKnown: !usageUnknown,
            weights: weights
        )
    }

    static func tier(for score: Int) -> Tier {
        if score >= 80 { return .zombie }
        if score >= 50 { return .review }
        return .keep
    }
}
