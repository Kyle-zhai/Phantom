import Foundation

private func daysAgo(_ n: Int) -> Date {
    Date().addingTimeInterval(TimeInterval(-n * 86_400))
}

private func daysAhead(_ n: Int) -> Date {
    Date().addingTimeInterval(TimeInterval(n * 86_400))
}

/// Curated **sample** dataset representing a typical American household's
/// subscription stack. The companies and prices are real and current; the
/// usage/rating fields are illustrative.
///
/// Surfaced to the user only via an **explicit opt-in** ("Browse with sample
/// data" button on the Connect screen and the empty Radar state). Never
/// auto-loaded. The Settings screen shows a "Sample data mode" banner whenever
/// it's active, with a one-tap Clear button.
///
/// This is the path App Store reviewers take to see the full feature set
/// without needing to import their own screenshots.
enum MockData {
    static let subscriptions: [Subscription] = [
        Subscription(
            id: "netflix", name: "Netflix", vendor: "Netflix, Inc.",
            brandHex: "E50914", category: .entertainment,
            amount: 22.99, cycle: .monthly,
            nextBilling: daysAhead(8), startedAt: daysAgo(820),
            lastUsedAt: daysAgo(3), sessionsLast30d: 18, userRating: 4,
            marketAverage: 18.0, trialEndsAt: nil,
            hasPriceHike: PriceHike(from: 15.49, to: 22.99, effective: daysAgo(60)),
            hasOverlapWith: [], notes: nil
        ),
        Subscription(
            id: "hulu", name: "Hulu", vendor: "Hulu, LLC",
            brandHex: "1CE783", category: .entertainment,
            amount: 17.99, cycle: .monthly,
            nextBilling: daysAhead(11), startedAt: daysAgo(600),
            lastUsedAt: daysAgo(58), sessionsLast30d: 1, userRating: 2,
            marketAverage: 14.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: ["netflix", "peacock", "paramount"], notes: nil
        ),
        Subscription(
            id: "spotify", name: "Spotify", vendor: "Spotify USA Inc.",
            brandHex: "1DB954", category: .entertainment,
            amount: 11.99, cycle: .monthly,
            nextBilling: daysAhead(2), startedAt: daysAgo(1200),
            lastUsedAt: daysAgo(1), sessionsLast30d: 47, userRating: 5,
            marketAverage: 11.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [], notes: nil
        ),
        Subscription(
            id: "adobe-cc", name: "Adobe Creative Cloud", vendor: "Adobe Inc.",
            brandHex: "FF0000", category: .tools,
            amount: 59.99, cycle: .monthly,
            nextBilling: daysAhead(14), startedAt: daysAgo(420),
            lastUsedAt: daysAgo(74), sessionsLast30d: 0, userRating: 3,
            marketAverage: 32.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [], notes: nil
        ),
        Subscription(
            id: "planet-fitness", name: "Planet Fitness Black Card", vendor: "Planet Fitness",
            brandHex: "7E22CE", category: .health,
            amount: 24.99, cycle: .monthly,
            nextBilling: daysAhead(18), startedAt: daysAgo(950),
            lastUsedAt: daysAgo(180), sessionsLast30d: 0, userRating: 1,
            marketAverage: 22.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [],
            notes: "Last visit 6 months ago. $150 already paid this year."
        ),
        Subscription(
            id: "nyt", name: "The New York Times", vendor: "The New York Times Company",
            brandHex: "000000", category: .news,
            amount: 17.0, cycle: .monthly,
            nextBilling: daysAhead(5), startedAt: daysAgo(380),
            lastUsedAt: daysAgo(2), sessionsLast30d: 22, userRating: 5,
            marketAverage: 12.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [], notes: nil
        ),
        Subscription(
            id: "peacock", name: "Peacock Premium", vendor: "NBCUniversal",
            brandHex: "000000", category: .entertainment,
            amount: 13.99, cycle: .monthly,
            nextBilling: daysAhead(20), startedAt: daysAgo(220),
            lastUsedAt: daysAgo(91), sessionsLast30d: 0, userRating: 2,
            marketAverage: 11.0, trialEndsAt: nil,
            hasPriceHike: PriceHike(from: 10.99, to: 13.99, effective: daysAhead(7)),
            hasOverlapWith: ["netflix", "hulu", "paramount"], notes: nil
        ),
        Subscription(
            id: "paramount", name: "Paramount+", vendor: "Paramount Streaming",
            brandHex: "0064FF", category: .entertainment,
            amount: 12.99, cycle: .monthly,
            nextBilling: daysAhead(22), startedAt: daysAgo(110),
            lastUsedAt: daysAgo(105), sessionsLast30d: 0, userRating: nil,
            marketAverage: 11.0, trialEndsAt: daysAhead(3), hasPriceHike: nil,
            hasOverlapWith: ["netflix", "hulu", "peacock"], notes: nil
        ),
        Subscription(
            id: "icloud", name: "iCloud+ 2TB", vendor: "Apple Inc.",
            brandHex: "0071E3", category: .tools,
            amount: 9.99, cycle: .monthly,
            nextBilling: daysAhead(15), startedAt: daysAgo(1100),
            lastUsedAt: daysAgo(0), sessionsLast30d: 30, userRating: 5,
            marketAverage: 10.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [], notes: nil
        ),
        Subscription(
            id: "duolingo", name: "Duolingo Super", vendor: "Duolingo Inc.",
            brandHex: "58CC02", category: .tools,
            amount: 83.0, cycle: .yearly,
            nextBilling: daysAhead(200), startedAt: daysAgo(165),
            lastUsedAt: daysAgo(34), sessionsLast30d: 2, userRating: 3,
            marketAverage: 7.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [], notes: nil
        ),
        Subscription(
            id: "masterclass", name: "MasterClass", vendor: "MasterClass",
            brandHex: "000000", category: .tools,
            amount: 180.0, cycle: .yearly,
            nextBilling: daysAhead(330), startedAt: daysAgo(35),
            lastUsedAt: daysAgo(28), sessionsLast30d: 0, userRating: 2,
            marketAverage: 15.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [],
            notes: "Watched first lesson and forgot about it."
        ),
        Subscription(
            id: "audible", name: "Audible Premium", vendor: "Audible, Inc.",
            brandHex: "F8991C", category: .entertainment,
            amount: 14.95, cycle: .monthly,
            nextBilling: daysAhead(9), startedAt: daysAgo(480),
            lastUsedAt: daysAgo(12), sessionsLast30d: 6, userRating: 4,
            marketAverage: 13.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [], notes: nil
        ),
        Subscription(
            id: "amazon-prime", name: "Amazon Prime", vendor: "Amazon.com",
            brandHex: "FF9900", category: .shopping,
            amount: 139.0, cycle: .yearly,
            nextBilling: daysAhead(80), startedAt: daysAgo(1800),
            lastUsedAt: daysAgo(0), sessionsLast30d: 14, userRating: 5,
            marketAverage: 12.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [], notes: nil
        ),
        Subscription(
            id: "sirius", name: "SiriusXM All Access", vendor: "Sirius XM",
            brandHex: "0033A0", category: .entertainment,
            amount: 24.99, cycle: .monthly,
            nextBilling: daysAhead(6), startedAt: daysAgo(720),
            lastUsedAt: daysAgo(45), sessionsLast30d: 1, userRating: 2,
            marketAverage: 18.0, trialEndsAt: nil, hasPriceHike: nil,
            hasOverlapWith: [], notes: nil
        ),
    ]

    static let alerts: [PriceAlert] = [
        PriceAlert(
            id: "a1", subscriptionId: "peacock", type: .hike,
            title: "Peacock is raising prices",
            message: "$10.99 → $13.99 / month in 7 days. That's +$36 / year.",
            createdAt: daysAgo(0), read: false
        ),
        PriceAlert(
            id: "a2", subscriptionId: "paramount", type: .trialEnding,
            title: "Paramount+ trial ends in 3 days",
            message: "You'll be charged $12.99/mo unless you cancel. We can do it for you.",
            createdAt: daysAgo(0), read: false
        ),
        PriceAlert(
            id: "a3", subscriptionId: "planet-fitness", type: .unused,
            title: "180 days since you last used Planet Fitness",
            message: "You've paid $149.94 in that time. Cancel and we'll generate a dispute letter.",
            createdAt: daysAgo(1), read: false
        ),
        PriceAlert(
            id: "a4", subscriptionId: "adobe-cc", type: .unused,
            title: "Adobe Creative Cloud has gone quiet",
            message: "74 days since you last opened any Adobe app. $147.97 paid since.",
            createdAt: daysAgo(2), read: true
        ),
        PriceAlert(
            id: "a5", subscriptionId: "masterclass", type: .newCharge,
            title: "MasterClass charged you $180",
            message: "Annual renewal. You watched 1 lesson in the past year.",
            createdAt: daysAgo(3), read: true
        ),
    ]
}
