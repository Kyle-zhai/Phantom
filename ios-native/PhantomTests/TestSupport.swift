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
    hasPriceHike: PriceHike? = nil,
    hasOverlapWith: [String] = []
) -> Subscription {
    Subscription(
        id: id, name: name, vendor: name, rawDescriptor: nil, brandHex: "000000",
        category: category, amount: amount, cycle: cycle,
        nextBilling: Date().addingTimeInterval(30 * 86_400),
        startedAt: Date().addingTimeInterval(-90 * 86_400),
        lastUsedAt: lastUsedAt, sessionsLast30d: sessionsLast30d,
        userRating: userRating, marketAverage: marketAverage,
        trialEndsAt: nil, hasPriceHike: hasPriceHike, hasOverlapWith: hasOverlapWith, notes: nil
    )
}

func daysAgo(_ n: Int, from now: Date = Date()) -> Date {
    now.addingTimeInterval(TimeInterval(-n * 86_400))
}

/// Same as `daysAgo`, for call sites where a parameter named `daysAgo` shadows it.
func dateDaysAgo(_ n: Int, from now: Date = Date()) -> Date {
    daysAgo(n, from: now)
}

/// A small but realistic catalog used by the score / coverage / downgrade tests.
let testCatalogJSON = """
{
  "updatedAt": "2026-09-01",
  "services": [
    {"brandId": "netflix", "name": "Netflix", "kind": "video",
     "tiers": [
       {"name": "Standard with ads", "priceMonthly": 8.99, "priceYearly": null, "note": "ads"},
       {"name": "Standard", "priceMonthly": 19.99, "priceYearly": null, "note": "no ads"},
       {"name": "Premium", "priceMonthly": 26.99, "priceYearly": null, "note": "4K"}
     ],
     "pause": {"supported": false, "note": "Cancel and rejoin."},
     "alternatives": [{"brandId": "peacock", "name": "Peacock Premium", "priceMonthly": 10.99, "why": "cheaper"}],
     "confidence": "high"},
    {"brandId": "hulu", "name": "Hulu", "kind": "video",
     "tiers": [{"name": "With ads", "priceMonthly": 9.99, "priceYearly": null, "note": null},
               {"name": "No ads", "priceMonthly": 18.99, "priceYearly": null, "note": null}],
     "pause": {"supported": true, "note": "Pause up to 12 weeks."}, "alternatives": [], "confidence": "high"},
    {"brandId": "peacock", "name": "Peacock", "kind": "video",
     "tiers": [{"name": "Premium", "priceMonthly": 10.99, "priceYearly": null, "note": null},
               {"name": "Premium Plus", "priceMonthly": 16.99, "priceYearly": null, "note": null}],
     "pause": null, "alternatives": [], "confidence": "medium"},
    {"brandId": "icloud", "name": "iCloud+", "kind": "cloudStorage",
     "tiers": [{"name": "50GB", "priceMonthly": 0.99, "priceYearly": null, "note": null},
               {"name": "2TB", "priceMonthly": 9.99, "priceYearly": null, "note": null}],
     "pause": null, "alternatives": [{"brandId": "google-one", "name": "Google One 2TB", "priceMonthly": 9.99, "why": "same price"}],
     "confidence": "high"},
    {"brandId": "spotify", "name": "Spotify", "kind": "music",
     "tiers": [{"name": "Premium", "priceMonthly": 12.99, "priceYearly": null, "note": null}],
     "pause": null,
     "alternatives": [{"brandId": "apple-music", "name": "Apple Music", "priceMonthly": 10.99, "why": "$2 less"},
                      {"brandId": "spotify", "name": "Spotify", "priceMonthly": 12.99, "why": "self"}],
     "confidence": "high"},
    {"brandId": "equinox", "name": "Equinox", "kind": "fitness",
     "tiers": [{"name": "Club", "priceMonthly": 300, "priceYearly": null, "note": null}],
     "pause": null, "alternatives": [], "confidence": "low"}
  ],
  "bundles": [
    {"id": "amazon-prime", "name": "Amazon Prime", "type": "membership", "priceMonthly": 14.99, "note": null,
     "includes": [{"brandId": "prime-video", "level": "included", "note": "Prime Video with ads", "valueMonthly": 8.99}],
     "confidence": "high"},
    {"id": "youtube-premium", "name": "YouTube Premium", "type": "membership", "priceMonthly": 15.99, "note": null,
     "includes": [{"brandId": "youtube-music", "level": "included", "note": "YouTube Music included", "valueMonthly": 11.99}],
     "confidence": "high"},
    {"id": "t-mobile", "name": "T-Mobile plan perks", "type": "telecom", "priceMonthly": null, "note": "Go5G Plus and above",
     "includes": [{"brandId": "netflix", "level": "included", "note": "Netflix Standard with ads on Go5G Plus", "valueMonthly": 8.99}],
     "confidence": "high"},
    {"id": "amex-platinum", "name": "Amex Platinum", "type": "card", "priceMonthly": null, "note": "$895/yr, enrollment required",
     "includes": [{"brandId": "disney-plus", "level": "credit", "note": "Digital entertainment credit", "valueMonthly": 25}],
     "confidence": "high"},
    {"id": "old-bundle", "name": "Old", "type": "membership", "priceMonthly": null, "note": null,
     "includes": [{"brandId": "hulu", "level": "included", "note": null, "valueMonthly": null}], "confidence": "low"}
  ]
}
"""

func testCatalog() -> AlternativesCatalog {
    try! AlternativesCatalog.decode(Data(testCatalogJSON.utf8))
}
