import Foundation

struct ScoreBreakdown {
    let score: Int
    let recencyOfLastUse: Int
    let usageVsPrice: Int
    let overlap: Int
    let userRating: Int
    let priceVsMarket: Int
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

    static func compute(_ sub: Subscription, now: Date = Date()) -> ScoreBreakdown {
        let days = Double(daysSince(sub.lastUsedAt, now: now))
        let recencyOfLastUse = clamp((days / 60.0) * 100.0)

        let monthly = sub.monthlyAmount
        let ratio = monthly > 0 ? Double(sub.sessionsLast30d) / monthly : 0
        let usageVsPrice = clamp(100.0 - clamp(ratio / 2.0 * 100.0))

        let overlapCount = Double(sub.hasOverlapWith.count)
        let overlap = clamp(overlapCount * 50.0)

        let userRating: Double = {
            guard let r = sub.userRating else { return 50 }
            return clamp(Double(5 - r) * 25.0)
        }()

        let premium: Double = sub.marketAverage > 0
            ? (monthly - sub.marketAverage) / sub.marketAverage
            : 0
        let priceVsMarket = clamp(premium * 200.0)

        let score = (recencyOfLastUse * 0.35)
            + (usageVsPrice * 0.25)
            + (overlap * 0.20)
            + (userRating * 0.15)
            + (priceVsMarket * 0.05)

        return ScoreBreakdown(
            score: Int(clamp(score.rounded())),
            recencyOfLastUse: Int(recencyOfLastUse.rounded()),
            usageVsPrice: Int(usageVsPrice.rounded()),
            overlap: Int(overlap.rounded()),
            userRating: Int(userRating.rounded()),
            priceVsMarket: Int(priceVsMarket.rounded())
        )
    }

    static func tier(for score: Int) -> Tier {
        if score >= 80 { return .zombie }
        if score >= 50 { return .review }
        return .keep
    }
}
