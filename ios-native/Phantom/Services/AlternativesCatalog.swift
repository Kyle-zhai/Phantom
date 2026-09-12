import Foundation

/// Static, hand-curated catalog of subscription tiers, pause rules, like-for-
/// like alternatives, and bundles / card perks that include other services.
/// Ships inside the app (`Resources/alternatives.json`) and is refreshed from
/// GitHub Pages (`docs/data/alternatives.json`) so prices can be corrected
/// without an App Store release. Nothing about the user is ever sent — the
/// fetch is an anonymous GET of a public JSON file.
struct AlternativesCatalog: Codable, Equatable {
    struct Tier: Codable, Hashable {
        let name: String
        let priceMonthly: Double
        let priceYearly: Double?
        let note: String?
    }

    struct Pause: Codable, Hashable {
        let supported: Bool
        let note: String?
    }

    struct Alternative: Codable, Hashable {
        let brandId: String
        let name: String
        let priceMonthly: Double?
        let why: String?
        /// "free" | "cheaper" | "better" | "bundle" — what this option wins on.
        var edge: String? = nil
        var priceNote: String? = nil
        var url: String? = nil
        var appStoreURL: String? = nil

        var edgeValue: Edge { Edge(rawValue: edge ?? "") ?? .similar }

        enum Edge: String, CaseIterable {
            case free, cheaper, bundle, better, similar

            /// Sort order on the page: free first, "similar" last.
            var rank: Int {
                switch self {
                case .free: return 0
                case .cheaper: return 1
                case .bundle: return 2
                case .better: return 3
                case .similar: return 4
                }
            }

            var label: String {
                switch self {
                case .free: return "Free"
                case .cheaper: return "Cheaper"
                case .bundle: return "Already in a bundle"
                case .better: return "Better"
                case .similar: return "Similar"
                }
            }
        }
    }

    /// An app the user probably needs given what they already pay for.
    struct SuggestedApp: Codable, Hashable {
        let brandId: String
        let name: String
        let priceMonthly: Double?
        let priceNote: String?
        let url: String?
        let appStoreURL: String?
        let why: String?

        /// "phantom-…" ids route inside the app instead of opening a URL.
        var isInternal: Bool { brandId.hasPrefix("phantom-") }
    }

    struct SuggestionTrigger: Codable, Hashable {
        var anyKinds: [String]? = nil
        var anyBrands: [String]? = nil
        var minSubs: Int? = nil
        var notKinds: [String]? = nil
        var notBrands: [String]? = nil
    }

    struct Suggestion: Codable, Hashable, Identifiable {
        let id: String
        let title: String
        let reason: String
        let when: SuggestionTrigger
        let apps: [SuggestedApp]
        let confidence: String?
    }

    struct Service: Codable, Hashable {
        let brandId: String
        let name: String
        let kind: String
        let tiers: [Tier]
        let pause: Pause?
        let alternatives: [Alternative]?
        let confidence: String?

        var kindValue: Kind { Kind(rawValue: kind) ?? .other }
        /// Paid tiers, cheapest first.
        var paidTiers: [Tier] {
            tiers.filter { $0.priceMonthly > 0 }.sorted { $0.priceMonthly < $1.priceMonthly }
        }
    }

    struct Inclusion: Codable, Hashable {
        let brandId: String
        let level: String
        let note: String?
        let valueMonthly: Double?

        var coverageLevel: CoverageLevel {
            switch level {
            case "included": return .included
            case "credit": return .credit
            case "discounted": return .discounted
            default: return .none
            }
        }
    }

    struct Bundle: Codable, Hashable {
        let id: String
        let name: String
        let type: String
        let priceMonthly: Double?
        let note: String?
        let includes: [Inclusion]
        let confidence: String?
    }

    let updatedAt: String
    let services: [Service]
    let bundles: [Bundle]
    /// Complementary-app rules ("you might also need"). Optional so older
    /// catalog files still decode.
    var suggestions: [Suggestion]? = nil

    var allSuggestions: [Suggestion] { suggestions ?? [] }

    static let empty = AlternativesCatalog(updatedAt: "", services: [], bundles: [])

    /// Decode a catalog file. Entries the curator marked `"confidence": "low"`
    /// are dropped — a wrong price is worse than no tip.
    static func decode(_ data: Data) throws -> AlternativesCatalog {
        let raw = try JSONDecoder().decode(AlternativesCatalog.self, from: data)
        var out = AlternativesCatalog(
            updatedAt: raw.updatedAt,
            services: raw.services.filter { $0.confidence != "low" },
            bundles: raw.bundles.filter { $0.confidence != "low" }
        )
        out.suggestions = raw.allSuggestions.filter { $0.confidence != "low" }
        return out
    }

    /// Brand ids the pipeline emits that the catalog files under another id.
    static let canonicalIds: [String: String] = [
        "paramount-plus": "paramount",
        "openai": "chatgpt",
        "anthropic": "claude",
    ]

    static func canonical(_ brandId: String) -> String {
        canonicalIds[brandId] ?? brandId
    }

    /// Kinds whose tiers are feature levels of the same product (ads vs no ads,
    /// 1080p vs 4K). Storage / seat-count tiers (iCloud 50GB vs 2TB) aren't a
    /// like-for-like downgrade, so those kinds never get a "cheaper plan" tip.
    static let downgradeEligibleKinds: Set<Kind> = [
        .video, .liveTV, .sports, .music, .news, .audiobooks, .podcasts,
        .aiAssistant, .aiCoding, .webHosting, .productivity, .creative,
        .learning, .kids, .fitness, .meditation, .health, .delivery,
        .mealKit, .dating, .socialMedia, .security, .email, .finance,
        .homeSecurity, .gaming,
    ]

    // MARK: - Lookups

    private var serviceIndex: [String: Service] {
        Dictionary(services.map { ($0.brandId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func service(for brandId: String) -> Service? {
        serviceIndex[Self.canonical(brandId)]
    }

    func bundle(id: String) -> Bundle? {
        bundles.first { $0.id == id }
    }

    func bundles(including brandId: String) -> [Bundle] {
        let target = Self.canonical(brandId)
        return bundles.filter { $0.includes.contains { Self.canonical($0.brandId) == target } }
    }

    /// The tier the user is most likely on: the paid tier whose price is
    /// closest to what they pay, within 25% (sales tax and rounding).
    func currentTier(for sub: Subscription) -> Tier? {
        guard let svc = service(for: sub.brandId) else { return nil }
        let monthly = sub.monthlyAmount
        guard monthly > 0 else { return nil }
        var best: (tier: Tier, diff: Double)? = nil
        for t in svc.paidTiers {
            let diff = abs(t.priceMonthly - monthly) / t.priceMonthly
            if diff <= 0.25, best == nil || diff < best!.diff {
                best = (t, diff)
            }
        }
        return best?.tier
    }

    /// The cheapest paid tier below what the user is on, when tiers are
    /// feature levels (not storage size). Nil when there is nothing cheaper.
    func downgrade(for sub: Subscription) -> Downgrade? {
        guard let svc = service(for: sub.brandId),
              Self.downgradeEligibleKinds.contains(svc.kindValue),
              let current = currentTier(for: sub),
              let cheaper = svc.paidTiers.first(where: { $0.priceMonthly < current.priceMonthly - 0.5 })
        else { return nil }
        return Downgrade(current: current, cheaper: cheaper)
    }

    func cheapestPaidTierMonthly(for brandId: String) -> Double? {
        guard let svc = service(for: brandId),
              Self.downgradeEligibleKinds.contains(svc.kindValue)
        else { return nil }
        return svc.paidTiers.first?.priceMonthly
    }

    /// Median of the typical (median-tier) price across services of a kind.
    func kindMedianMonthly(_ kind: Kind) -> Double? {
        let typical = services
            .filter { $0.kindValue == kind }
            .compactMap { svc -> Double? in
                let prices = svc.paidTiers.map(\.priceMonthly)
                guard !prices.isEmpty else { return nil }
                return prices[prices.count / 2]
            }
        guard typical.count >= 2 else { return nil }
        let sorted = typical.sorted()
        return sorted[sorted.count / 2]
    }

    func alternatives(for sub: Subscription) -> [Alternative] {
        guard let svc = service(for: sub.brandId) else { return [] }
        let own = Self.canonical(sub.brandId)
        return (svc.alternatives ?? []).filter { Self.canonical($0.brandId) != own }
    }

    func pause(for sub: Subscription) -> Pause? {
        service(for: sub.brandId)?.pause
    }
}

struct Downgrade: Hashable {
    let current: AlternativesCatalog.Tier
    let cheaper: AlternativesCatalog.Tier

    var savesMonthly: Double { current.priceMonthly - cheaper.priceMonthly }
    var savesYearly: Double { savesMonthly * 12 }
}

/// Bundled → cached → remote. The newest `updatedAt` wins (ISO dates sort
/// lexically). Remote refresh is best-effort and silent.
enum AlternativesCatalogLoader {
    static var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Phantom", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("alternatives.json")
    }

    static func bundled() -> AlternativesCatalog? {
        guard let url = Bundle.main.url(forResource: "alternatives", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? AlternativesCatalog.decode(data)
    }

    static func cached() -> AlternativesCatalog? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? AlternativesCatalog.decode(data)
    }

    static func best() -> AlternativesCatalog {
        let candidates = [bundled(), cached()].compactMap { $0 }
        return candidates.max { $0.updatedAt < $1.updatedAt } ?? .empty
    }

    /// Fetch the public catalog; on success cache it and return the newest of
    /// (remote, current). Never throws to the caller.
    static func refresh(current: AlternativesCatalog) async -> AlternativesCatalog {
        guard let url = URL(string: AppConfig.alternativesCatalogURL) else { return current }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let remote = try? AlternativesCatalog.decode(data)
        else { return current }
        if remote.updatedAt > current.updatedAt {
            try? data.write(to: cacheURL, options: [.atomic])
            return remote
        }
        return current
    }
}
