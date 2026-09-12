import Foundation

/// A subscription the user pays for separately that something they already
/// own (a membership, carrier plan, Apple One, or a card credit) covers.
struct CoverageHit: Identifiable, Hashable {
    let subId: String
    let bundleId: String
    let bundleName: String
    let level: CoverageLevel
    let note: String?
    /// What the user could stop paying (or get reimbursed) per month.
    let valueMonthly: Double
    /// True when Phantom inferred ownership from the user's own imported subs
    /// (an Amazon Prime charge means they have Prime) rather than a Settings
    /// toggle. Inferred carrier perks are plan-dependent, so they surface as
    /// "check your plan" rather than "included".
    let inferred: Bool

    var id: String { "\(subId)|\(bundleId)" }
    var valueYearly: Double { valueMonthly * 12 }

    /// One-line explanation for rows and cards. An inferred carrier perk is
    /// only a "check your plan" hint until the user confirms the plan.
    var summary: String {
        switch level {
        case .included: return "Included in \(bundleName)"
        case .credit: return "Reimbursed by \(bundleName)"
        case .discounted: return inferred ? "May be included with \(bundleName) — check your plan" : "Cheaper through \(bundleName)"
        case .none: return ""
        }
    }

    func headline(subName: String) -> String {
        switch level {
        case .included: return "\(subName) is included in \(bundleName)"
        case .credit: return "\(bundleName) reimburses \(subName)"
        case .discounted: return inferred ? "\(subName) may already be included with \(bundleName)" : "\(bundleName) gets \(subName) cheaper"
        case .none: return ""
        }
    }
}

enum BundleCoverage {
    /// Holding one of these subscriptions implies owning the catalog bundle.
    static let subToBundle: [String: String] = [
        "amazon-prime": "amazon-prime",
        "walmart-plus": "walmart-plus",
        "youtube-premium": "youtube-premium",
        "spotify": "spotify-premium",
        "gemini": "google-ai-pro",
        "microsoft-365": "microsoft-365",
        "instacart-plus": "instacart-plus",
        "dashpass": "dashpass",
        "t-mobile": "t-mobile",
        "verizon": "verizon",
        "xfinity": "xfinity",
        // Any Apple One tier includes Music, TV, Arcade and iCloud; the
        // statement can't tell tiers apart, so assume the smallest.
        "apple-one": "apple-one-individual",
    ]

    /// Bundle types whose inclusions depend on the specific plan the user is
    /// on. Only trusted at full strength when the user confirmed the bundle.
    static let planDependentTypes: Set<String> = ["telecom"]

    static func inferredBundleIds(activeSubs: [Subscription], catalog: AlternativesCatalog) -> Set<String> {
        let available = Set(catalog.bundles.map(\.id))
        var out = Set<String>()
        for sub in activeSubs {
            let brand = sub.brandId
            if let mapped = subToBundle[brand], available.contains(mapped) {
                out.insert(mapped)
            } else if available.contains(brand) {
                out.insert(brand)
            }
        }
        return out
    }

    /// One hit per covered subscription (the strongest bundle wins), sorted by
    /// monthly value. `ownedBundleIds` are the user's Settings toggles;
    /// inferred bundles come from `inferredBundleIds`.
    static func hits(
        activeSubs: [Subscription],
        ownedBundleIds: Set<String>,
        inferredBundleIds: Set<String>,
        catalog: AlternativesCatalog
    ) -> [CoverageHit] {
        var bestBySub: [String: CoverageHit] = [:]
        let allOwned = ownedBundleIds.union(inferredBundleIds)
        for bundleId in allOwned.sorted() {
            guard let bundle = catalog.bundle(id: bundleId) else { continue }
            let explicit = ownedBundleIds.contains(bundleId)
            let planDependent = planDependentTypes.contains(bundle.type)
            for inclusion in bundle.includes {
                var level = inclusion.coverageLevel
                guard level != .none else { continue }
                if !explicit && planDependent { level = min(level, .discounted) }
                let target = AlternativesCatalog.canonical(inclusion.brandId)
                for sub in activeSubs where AlternativesCatalog.canonical(sub.brandId) == target {
                    // The sub that *is* the bundle can't be covered by itself.
                    if subToBundle[sub.brandId] == bundleId || sub.brandId == bundleId { continue }
                    let value: Double
                    switch level {
                    case .included: value = sub.monthlyAmount
                    case .credit: value = min(inclusion.valueMonthly ?? sub.monthlyAmount, sub.monthlyAmount)
                    case .discounted: value = min(inclusion.valueMonthly ?? 0, sub.monthlyAmount)
                    case .none: value = 0
                    }
                    let hit = CoverageHit(
                        subId: sub.id, bundleId: bundle.id, bundleName: bundle.name,
                        level: level, note: inclusion.note, valueMonthly: value,
                        inferred: !explicit
                    )
                    if let cur = bestBySub[sub.id] {
                        if hit.level > cur.level || (hit.level == cur.level && hit.valueMonthly > cur.valueMonthly) {
                            bestBySub[sub.id] = hit
                        }
                    } else {
                        bestBySub[sub.id] = hit
                    }
                }
            }
        }
        return bestBySub.values.sorted {
            $0.valueMonthly != $1.valueMonthly ? $0.valueMonthly > $1.valueMonthly : $0.subId < $1.subId
        }
    }
}
