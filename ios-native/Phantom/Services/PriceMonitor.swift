import Foundation

/// Pulls the live price catalog from the backend, finds price hikes, and produces
/// `PriceAlert` records when a user-held subscription matches a hiked entry.
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

    /// Build alerts for a user's subscriptions when matching catalog entries have hiked.
    static func detectHikes(in subs: [Subscription], catalog: [RemotePrice]) -> [PriceAlert] {
        var alerts: [PriceAlert] = []
        for sub in subs {
            // Loose name match: substring, case-insensitive
            let target = sub.name.lowercased()
            guard let hit = catalog.first(where: {
                let n = $0.name.lowercased()
                return (target.contains(n) || n.contains(target)) && $0.prevPrice != nil
            }) else { continue }
            guard let prev = hit.prevPrice, hit.priceMonthly > prev + 0.01 else { continue }
            let diff = hit.priceMonthly - prev
            let yearly = diff * 12
            alerts.append(
                PriceAlert(
                    id: "hike-\(hit.id)-\(Int(Date().timeIntervalSince1970))",
                    subscriptionId: sub.id,
                    type: .hike,
                    title: "\(sub.name) is raising prices",
                    message: String(format: "$%.2f → $%.2f / month. That's +$%.0f / year.", prev, hit.priceMonthly, yearly),
                    createdAt: Date(),
                    read: false
                )
            )
        }
        return alerts
    }
}
