import Foundation

/// Pulls the live price catalog from GitHub Pages, finds price hikes, and
/// produces `PriceAlert` records when a user-held subscription matches a hiked
/// entry.
enum PriceMonitor {
    struct RemotePrice: Decodable, Hashable {
        let id: String
        let name: String
        let priceMonthly: Double
        let category: String
        let prevPrice: Double?
        let hikedAt: String?
    }

    struct PricesResponse: Decodable {
        let prices: [RemotePrice]
        let count: Int?
        let updatedAt: String
    }

    /// A catalog hike that applies to one of the user's subs.
    struct HikeMatch: Equatable {
        let subId: String
        let subName: String
        let entryId: String
        let previous: Double
        let current: Double
        let hikedAt: Date?
    }

    static func fetchKnown() async throws -> [RemotePrice] {
        // Fetch the static JSON file hosted on GitHub Pages — no backend required.
        guard let url = URL(string: AppConfig.priceCatalogURL) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let r = try decoder.decode(PricesResponse.self, from: data)
        return r.prices
    }

    static func refresh() async throws -> [RemotePrice] {
        // Same source — GitHub Pages JSON is the live catalog.
        try await fetchKnown()
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Find the catalog entry that describes a sub. Entries are per tier
    /// ("netflix-standard", "netflix-premium"); when several share the name,
    /// the one whose pre- or post-hike price is closest to what the user
    /// actually pays wins — so a Standard subscriber isn't told about a
    /// Premium-only hike.
    static func match(_ sub: Subscription, in catalog: [RemotePrice]) -> RemotePrice? {
        let target = sub.name.lowercased()
        let brand = sub.brandId.lowercased()
        guard target.count >= 3 else { return nil }
        let candidates = catalog.filter { entry in
            let n = entry.name.lowercased()
            // Require a meaningful token on BOTH sides before the substring
            // test — otherwise a blank/very-short catalog name matches EVERY
            // sub (Swift's `"x".contains("")` is true).
            guard n.count >= 3 else { return false }
            if entry.id == brand || entry.id.hasPrefix(brand + "-") { return true }
            return target.contains(n) || n.contains(target)
        }
        guard !candidates.isEmpty else { return nil }
        let monthly = sub.monthlyAmount
        func distance(_ e: RemotePrice) -> Double {
            let d1 = abs(e.priceMonthly - monthly)
            let d2 = e.prevPrice.map { abs($0 - monthly) } ?? .greatestFiniteMagnitude
            return min(d1, d2)
        }
        return candidates.min { distance($0) < distance($1) }
    }

    static func matches(in subs: [Subscription], catalog: [RemotePrice]) -> [HikeMatch] {
        var out: [HikeMatch] = []
        for sub in subs {
            guard let hit = match(sub, in: catalog),
                  let prev = hit.prevPrice, hit.priceMonthly > prev + 0.01 else { continue }
            // Only report a hike for the tier the user is plausibly on: what
            // they pay must be near the old or the new price (25% covers tax).
            let monthly = sub.monthlyAmount
            let near = min(abs(monthly - prev) / prev, abs(monthly - hit.priceMonthly) / hit.priceMonthly)
            guard near <= 0.25 else { continue }
            out.append(HikeMatch(
                subId: sub.id, subName: sub.name, entryId: hit.id,
                previous: prev, current: hit.priceMonthly,
                hikedAt: hit.hikedAt.flatMap { dayFormatter.date(from: $0) }
            ))
        }
        return out
    }

    static func alert(for m: HikeMatch, now: Date = Date()) -> PriceAlert {
        let diff = m.current - m.previous
        let yearly = diff * 12
        return PriceAlert(
            id: "hike-\(m.entryId)-\(Int((m.hikedAt ?? now).timeIntervalSince1970))",
            subscriptionId: m.subId,
            type: .hike,
            title: "\(m.subName) is raising prices",
            message: String(format: "$%.2f → $%.2f / month. That's +$%.0f / year.", m.previous, m.current, yearly),
            createdAt: now,
            read: false
        )
    }

    /// Build alerts for a user's subscriptions when matching catalog entries have hiked.
    static func detectHikes(in subs: [Subscription], catalog: [RemotePrice]) -> [PriceAlert] {
        matches(in: subs, catalog: catalog).map { alert(for: $0) }
    }
}
