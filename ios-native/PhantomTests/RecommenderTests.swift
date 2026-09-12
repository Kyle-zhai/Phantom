import XCTest
@testable import Phantom

/// "For you": needs read from the user's subs, like-for-like replacements
/// ordered by edge, and complementary suggestions fired by catalog rules.
final class RecommenderTests: XCTestCase {
    private let catalogJSON = """
    {
      "updatedAt": "2026-09-10",
      "services": [
        {"brandId": "netflix", "name": "Netflix", "kind": "video",
         "tiers": [{"name": "Standard", "priceMonthly": 19.99, "priceYearly": null, "note": null}],
         "pause": null,
         "alternatives": [
           {"brandId": "peacock", "name": "Peacock", "priceMonthly": 8.99, "why": "cheaper", "edge": "cheaper"},
           {"brandId": "tubi", "name": "Tubi", "priceMonthly": 0, "why": "free with ads", "edge": "free", "url": "https://tubitv.com"},
           {"brandId": "hbo-max", "name": "HBO Max", "priceMonthly": 18.49, "why": "stronger catalog", "edge": "better"},
           {"brandId": "hulu", "name": "Hulu", "priceMonthly": 11.99, "why": "held already", "edge": "cheaper"}
         ],
         "confidence": "high"},
        {"brandId": "peloton", "name": "Peloton", "kind": "fitness",
         "tiers": [{"name": "App+", "priceMonthly": 28.99, "priceYearly": null, "note": null}],
         "pause": null, "alternatives": [], "confidence": "high"},
        {"brandId": "audible", "name": "Audible", "kind": "audiobooks",
         "tiers": [{"name": "Premium Plus", "priceMonthly": 14.95, "priceYearly": null, "note": null}],
         "pause": null,
         "alternatives": [{"brandId": "libby", "name": "Libby", "priceMonthly": 0, "why": "library card", "edge": "free"}],
         "confidence": "high"}
      ],
      "bundles": [],
      "suggestions": [
        {"id": "fitness-nutrition", "title": "Track what you eat, too", "reason": "Workout subs pair with a food log.",
         "when": {"anyKinds": ["fitness"], "notBrands": ["myfitnesspal"]},
         "apps": [{"brandId": "myfitnesspal", "name": "MyFitnessPal", "priceMonthly": 0, "priceNote": "Free tier", "url": "https://www.myfitnesspal.com", "appStoreURL": null, "why": "Largest food database"}],
         "confidence": "high"},
        {"id": "video-guide", "title": "Find what's on where", "reason": "Two or more video subs.",
         "when": {"anyKinds": ["video"], "minSubs": 2},
         "apps": [{"brandId": "justwatch", "name": "JustWatch", "priceMonthly": 0, "priceNote": null, "url": "https://www.justwatch.com", "appStoreURL": null, "why": "Search across services"}],
         "confidence": "high"},
        {"id": "many-subs-budget", "title": "See the whole picture", "reason": "Lots of subscriptions.",
         "when": {"minSubs": 4, "anyKinds": []},
         "apps": [{"brandId": "phantom-bundles", "name": "Check your bundles", "priceMonthly": null, "priceNote": null, "url": null, "appStoreURL": null, "why": "Built in"}],
         "confidence": "high"},
        {"id": "low-conf", "title": "Dropped", "reason": "low confidence",
         "when": {"anyKinds": ["video"]},
         "apps": [{"brandId": "x", "name": "X", "priceMonthly": 0, "priceNote": null, "url": null, "appStoreURL": null, "why": null}],
         "confidence": "low"},
        {"id": "suppressed", "title": "Suppressed", "reason": "user already has audiobooks",
         "when": {"anyKinds": ["video"], "notKinds": ["audiobooks"]},
         "apps": [{"brandId": "y", "name": "Y", "priceMonthly": 0, "priceNote": null, "url": null, "appStoreURL": null, "why": null}],
         "confidence": "high"}
      ]
    }
    """

    private func catalog() -> AlternativesCatalog { try! AlternativesCatalog.decode(Data(catalogJSON.utf8)) }

    private var subs: [Subscription] {
        [
            makeSub(id: "netflix", name: "Netflix", amount: 19.99),
            makeSub(id: "hulu", name: "Hulu", amount: 11.99),
            makeSub(id: "peloton", name: "Peloton", amount: 28.99),
            makeSub(id: "audible", name: "Audible", amount: 14.95),
        ]
    }

    func testNeedsGroupByKindHighestSpendFirst() {
        let r = Recommender.build(subs: subs, catalog: catalog())
        XCTAssertEqual(r.needs.map(\.kind), [.video, .fitness, .audiobooks])
        XCTAssertEqual(r.needs.first?.count, 2)
        XCTAssertEqual(r.needs.first?.monthly ?? 0, 31.98, accuracy: 0.001)
        XCTAssertTrue(r.tags.contains("Wellness"))
        XCTAssertTrue(r.tags.contains("Reader & learner"))
        XCTAssertFalse(r.tags.contains("Subscription-heavy"))
    }

    func testReplacementsOrderedByEdgeAndSkipHeldBrands() throws {
        let r = Recommender.build(subs: subs, catalog: catalog())
        let netflix = try XCTUnwrap(r.replacements.first { $0.sub.id == "netflix" })
        XCTAssertEqual(netflix.options.map(\.brandId), ["tubi", "peacock", "hbo-max"], "free → cheaper → better; Hulu is held so it's dropped")
        XCTAssertEqual(netflix.options.first?.edgeValue, .free)
        XCTAssertEqual(netflix.bestSavingMonthly, 19.99, accuracy: 0.001)
        XCTAssertNil(r.replacements.first { $0.sub.id == "peloton" }, "no catalog alternatives → no group")
        XCTAssertEqual(r.replacements.first?.sub.id, "netflix", "biggest saving first")
    }

    func testSuggestionsFireOnKindsMinSubsAndRespectSuppression() {
        let r = Recommender.build(subs: subs, catalog: catalog())
        let ids = r.suggestions.map(\.id)
        XCTAssertTrue(ids.contains("fitness-nutrition"))
        XCTAssertTrue(ids.contains("video-guide"))
        XCTAssertTrue(ids.contains("many-subs-budget"), "4 subs meets minSubs 4")
        XCTAssertFalse(ids.contains("low-conf"), "low-confidence rules are dropped at decode")
        XCTAssertFalse(ids.contains("suppressed"), "notKinds audiobooks suppresses it")
        let fitness = r.suggestions.first { $0.id == "fitness-nutrition" }!
        XCTAssertEqual(fitness.because.map(\.id), ["peloton"])
        XCTAssertEqual(Recommender.becauseText(fitness.because), "Because you pay for Peloton")
        let video = r.suggestions.first { $0.id == "video-guide" }!
        XCTAssertEqual(video.because.map(\.id), ["netflix", "hulu"], "highest spend first")
        XCTAssertEqual(Recommender.becauseText(video.because), "Because you pay for Netflix and Hulu")
        XCTAssertGreaterThanOrEqual(video.score, fitness.score, "two triggering subs outrank one")
    }

    func testHeldSuggestedAppSuppressesTheRule() {
        let withMFP = subs + [makeSub(id: "myfitnesspal", name: "MyFitnessPal", amount: 24.99)]
        let r = Recommender.build(subs: withMFP, catalog: catalog())
        XCTAssertFalse(r.suggestions.contains { $0.id == "fitness-nutrition" })
    }

    func testMinSubsRuleDoesNotFireBelowThreshold() {
        let few = Array(subs.prefix(2))
        let r = Recommender.build(subs: few, catalog: catalog())
        XCTAssertFalse(r.suggestions.contains { $0.id == "many-subs-budget" })
    }

    func testTagsAreCappedAndKeepTheActionableOne() {
        // A deliberately wide library: entertainment, builder, wellness, reader,
        // security, convenience, gaming and enough subs to be "heavy".
        let wide = [
            makeSub(id: "netflix", name: "Netflix", amount: 19.99),
            makeSub(id: "spotify", name: "Spotify", amount: 11.99),
            makeSub(id: "chatgpt", name: "ChatGPT", amount: 20),
            makeSub(id: "peloton", name: "Peloton", amount: 28.99),
            makeSub(id: "nyt", name: "New York Times", amount: 17),
            makeSub(id: "1password", name: "1Password", amount: 4.99),
            makeSub(id: "dashpass", name: "DashPass", amount: 9.99),
            makeSub(id: "apple-arcade", name: "Apple Arcade", amount: 6.99),
            makeSub(id: "icloud", name: "iCloud", amount: 2.99),
        ]
        let tags = Recommender.build(subs: wide, catalog: catalog()).tags
        XCTAssertLessThanOrEqual(tags.count, 5)
        XCTAssertEqual(tags.last, "Subscription-heavy", "the actionable tag must survive the cap")
    }

    func testMinSubsCountsMatchingSubsWhenKindsAreNamed() {
        // One video sub → "2+ video services" rule must not fire.
        let one = [makeSub(id: "netflix", name: "Netflix", amount: 19.99), makeSub(id: "peloton", name: "Peloton", amount: 28.99)]
        XCTAssertFalse(Recommender.build(subs: one, catalog: catalog()).suggestions.contains { $0.id == "video-guide" })
        XCTAssertTrue(Recommender.build(subs: subs, catalog: catalog()).suggestions.contains { $0.id == "video-guide" })
    }

    func testEmptyLibraryYieldsEmptyRecommendations() {
        XCTAssertTrue(Recommender.build(subs: [], catalog: catalog()).isEmpty)
    }

    func testCatalogWithoutSuggestionsStillDecodes() throws {
        let legacy = """
        {"updatedAt": "2026-09-01", "services": [], "bundles": []}
        """
        let c = try AlternativesCatalog.decode(Data(legacy.utf8))
        XCTAssertTrue(c.allSuggestions.isEmpty)
        // Alternatives without an edge read as "similar" and sort last.
        XCTAssertEqual(AlternativesCatalog.Alternative(brandId: "a", name: "A", priceMonthly: nil, why: nil).edgeValue, .similar)
    }

    func testInternalAppIds() {
        let internalApp = AlternativesCatalog.SuggestedApp(brandId: "phantom-negotiate", name: "Negotiate", priceMonthly: nil, priceNote: nil, url: nil, appStoreURL: nil, why: nil)
        XCTAssertTrue(internalApp.isInternal)
    }
}

/// End-to-end against the REAL bundled catalog rather than the test fixture.
/// These are the verticals added on 2026-09-11; if a merge ever drops one, the
/// For-you page silently goes quiet for those users, which is hard to notice.
final class RecommenderCatalogTests: XCTestCase {

    private func real() throws -> AlternativesCatalog {
        try XCTUnwrap(AlternativesCatalogLoader.bundled())
    }

    func testNewVerticalsProduceReplacements() throws {
        let catalog = try real()
        let cases: [(String, String, Double)] = [
            ("tinder", "Tinder", 39.99), ("betterhelp", "BetterHelp", 320),
            ("hellofresh", "HelloFresh", 333), ("ring-home", "Ring Home", 9.99),
            ("x-premium", "X Premium", 8), ("costco", "Costco", 5.42),
            ("abcmouse", "ABCmouse", 12.99), ("mister-car-wash", "Mister Car Wash", 24.99),
            ("shudder", "Shudder", 9.99), ("patreon", "Patreon", 10),
        ]
        for (id, name, price) in cases {
            let subs = [makeSub(id: id, name: name, amount: price)]
            let r = Recommender.build(subs: subs, catalog: catalog)
            XCTAssertFalse(r.replacements.isEmpty, "\(id) has no replacements in the shipped catalog")
            XCTAssertNotEqual(r.needs.first?.kind, .other, "\(id) was not classified into a kind")
        }
    }

    func testEveryCatalogServiceIsReachableFromASubscription() throws {
        // A service the registry can't classify would never be matched to a
        // user's sub, so its alternatives could never be shown.
        let catalog = try real()
        for svc in catalog.services where !(svc.alternatives ?? []).isEmpty {
            let sub = makeSub(id: svc.brandId, name: svc.name, amount: 9.99)
            let r = Recommender.build(subs: [sub], catalog: catalog)
            XCTAssertFalse(r.replacements.isEmpty, "\(svc.brandId) is in the catalog but unreachable")
        }
    }

    func testNewRulesFireOnTheirVertical() throws {
        let catalog = try real()
        let expectations: [(String, String, String)] = [
            ("ring-home", "Ring Home", "homesecurity-no-monthly-fee"),
            ("betterhelp", "BetterHelp", "health-lower-cost-care"),
            ("abcmouse", "ABCmouse", "kids-free-learning"),
            ("hellofresh", "HelloFresh", "mealkit-cheaper-boxes"),
            ("costco", "Costco", "retail-free-tier-first"),
            ("tinder", "Tinder", "dating-free-first"),
        ]
        for (id, name, ruleId) in expectations {
            let r = Recommender.build(subs: [makeSub(id: id, name: name, amount: 19.99)], catalog: catalog)
            XCTAssertTrue(r.suggestions.contains { $0.id == ruleId },
                          "\(ruleId) did not fire for \(id); got \(r.suggestions.map(\.id))")
        }
    }

    func testAHeldAppIsNeverSuggestedBackToTheUser() throws {
        let catalog = try real()
        let subs = [makeSub(id: "hellofresh", name: "HelloFresh", amount: 333),
                    makeSub(id: "everyplate", name: "EveryPlate", amount: 150)]
        let r = Recommender.build(subs: subs, catalog: catalog)
        for match in r.suggestions {
            XCTAssertFalse(match.apps.contains { $0.brandId == "everyplate" },
                           "suggested EveryPlate to someone already paying for it")
        }
        for group in r.replacements {
            XCTAssertFalse(group.options.contains { $0.brandId == "everyplate" },
                           "offered EveryPlate as a replacement to someone who holds it")
        }
    }
}

extension RecommenderCatalogTests {
    /// The money verticals carry the highest-value advice in the catalog: a
    /// credit freeze is free and stops fraud outright, OS protection is already
    /// paid for, and a simple return can be filed for nothing.
    func testMoneyAndSecurityRulesFire() throws {
        let catalog = try XCTUnwrap(AlternativesCatalogLoader.bundled())
        let cases: [(String, String, Double, String)] = [
            ("norton", "Norton 360", 9.99, "security-builtin-protection"),
            ("lifelock", "LifeLock", 14.99, "security-freeze-beats-monitoring"),
            ("ynab", "YNAB", 14.99, "finance-free-dashboards"),
            ("turbotax", "TurboTax", 9.99, "finance-free-tax-filing"),
            ("fastmail", "Fastmail", 5.00, "email-free-and-masked"),
        ]
        for (id, name, price, ruleId) in cases {
            let r = Recommender.build(subs: [makeSub(id: id, name: name, amount: price)], catalog: catalog)
            XCTAssertTrue(r.suggestions.contains { $0.id == ruleId },
                          "\(ruleId) did not fire for \(id); got \(r.suggestions.map(\.id))")
        }
    }
}
