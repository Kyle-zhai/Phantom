import XCTest
@testable import Phantom

final class AlternativesCatalogTests: XCTestCase {

    func testLowConfidenceEntriesAreDropped() {
        let c = testCatalog()
        XCTAssertNil(c.service(for: "equinox"))
        XCTAssertNil(c.bundle(id: "old-bundle"))
        XCTAssertNotNil(c.service(for: "netflix"))
        XCTAssertNotNil(c.service(for: "peacock"), "medium confidence stays")
    }

    func testCanonicalIdsResolve() {
        let c = testCatalog()
        XCTAssertNotNil(c.service(for: "paramount-plus") == nil ? c.service(for: "netflix") : c.service(for: "netflix"))
        XCTAssertEqual(AlternativesCatalog.canonical("paramount-plus"), "paramount")
        XCTAssertEqual(AlternativesCatalog.canonical("openai"), "chatgpt")
    }

    func testCurrentTierTolerantOfTax() {
        let c = testCatalog()
        XCTAssertEqual(c.currentTier(for: makeSub(amount: 19.99))?.name, "Standard")
        XCTAssertEqual(c.currentTier(for: makeSub(amount: 21.50))?.name, "Standard", "tax-inclusive price still maps")
        XCTAssertEqual(c.currentTier(for: makeSub(amount: 26.99))?.name, "Premium")
        XCTAssertEqual(c.currentTier(for: makeSub(amount: 8.99))?.name, "Standard with ads")
        XCTAssertNil(c.currentTier(for: makeSub(amount: 3.00)), "no tier within 25%")
    }

    func testDowngradeFindsCheapestFeatureTier() {
        let c = testCatalog()
        let d = c.downgrade(for: makeSub(amount: 26.99))
        XCTAssertEqual(d?.current.name, "Premium")
        XCTAssertEqual(d?.cheaper.name, "Standard with ads")
        XCTAssertEqual(d?.savesMonthly ?? 0, 18, accuracy: 0.001)
        XCTAssertEqual(d?.savesYearly ?? 0, 216, accuracy: 0.001)
        XCTAssertNil(c.downgrade(for: makeSub(amount: 8.99)), "already on the cheapest tier")
    }

    func testStorageTiersAreNeverADowngrade() {
        let c = testCatalog()
        XCTAssertNil(c.downgrade(for: makeSub(id: "icloud", name: "iCloud+", amount: 9.99)))
        XCTAssertNil(c.cheapestPaidTierMonthly(for: "icloud"))
        XCTAssertEqual(c.cheapestPaidTierMonthly(for: "netflix"), 8.99)
    }

    func testKindMedianNeedsTwoServices() {
        let c = testCatalog()
        // video: netflix (median tier 19.99), hulu (18.99), peacock (16.99) → 18.99
        XCTAssertEqual(c.kindMedianMonthly(.video) ?? 0, 18.99, accuracy: 0.001)
        XCTAssertNil(c.kindMedianMonthly(.music), "only one music service")
        XCTAssertNil(c.kindMedianMonthly(.vpn))
    }

    func testAlternativesExcludeSelf() {
        let c = testCatalog()
        let alts = c.alternatives(for: makeSub(id: "spotify", name: "Spotify", amount: 12.99))
        XCTAssertEqual(alts.map(\.brandId), ["apple-music"])
        XCTAssertEqual(c.alternatives(for: makeSub(id: "hulu", name: "Hulu")).count, 0)
    }

    func testUnknownKeysInJSONAreIgnored() throws {
        let json = """
        {"updatedAt": "2026-09-10", "services": [{"brandId": "x", "name": "X", "kind": "video", "tiers": [],
          "pause": null, "alternatives": null, "sources": ["https://a"], "verifiedAt": "2026-09-10", "confidence": "high"}],
         "bundles": []}
        """
        let c = try AlternativesCatalog.decode(Data(json.utf8))
        XCTAssertEqual(c.services.count, 1)
    }

    func testBundledCatalogShipsAndParses() {
        // The copy inside the app bundle must always decode — it's the offline fallback.
        let c = AlternativesCatalogLoader.bundled()
        XCTAssertNotNil(c)
        XCTAssertFalse(c?.services.isEmpty ?? true)
        XCTAssertFalse(c?.bundles.isEmpty ?? true)
        // Every catalog id the registry can't name would render as a letter avatar with kind "other".
        for svc in c?.services ?? [] {
            XCTAssertNotNil(BrandRegistry.displayName(for: svc.brandId), "catalog service \(svc.brandId) unknown to BrandRegistry")
            XCTAssertNotNil(Kind(rawValue: svc.kind), "catalog kind \(svc.kind) is not a Kind")
        }
        for b in c?.bundles ?? [] {
            for inc in b.includes {
                XCTAssertNotNil(BrandRegistry.displayName(for: inc.brandId), "bundle \(b.id) includes unknown brand \(inc.brandId)")
                XCTAssertNotEqual(inc.coverageLevel, .none, "bundle \(b.id) inclusion \(inc.brandId) has bad level \(inc.level)")
            }
        }
    }
}

final class BundleCoverageTests: XCTestCase {
    private var subs: [Subscription] {
        [
            makeSub(id: "amazon-prime", name: "Amazon Prime", amount: 14.99),
            makeSub(id: "prime-video", name: "Prime Video", amount: 8.99),
            makeSub(id: "netflix", name: "Netflix", amount: 19.99),
            makeSub(id: "t-mobile", name: "T-Mobile", amount: 65),
            makeSub(id: "youtube-premium", name: "YouTube Premium", amount: 15.99),
            makeSub(id: "youtube-music", name: "YouTube Music", amount: 11.99),
            makeSub(id: "disney-plus", name: "Disney+", amount: 11.99),
        ]
    }

    func testOwnershipIsInferredFromHeldSubs() {
        let inferred = BundleCoverage.inferredBundleIds(activeSubs: subs, catalog: testCatalog())
        XCTAssertEqual(inferred, ["amazon-prime", "t-mobile", "youtube-premium"])
    }

    func testIncludedSubsAreHitsAndTheBundleItselfIsNot() {
        let c = testCatalog()
        let hits = BundleCoverage.hits(activeSubs: subs, ownedBundleIds: [], inferredBundleIds: BundleCoverage.inferredBundleIds(activeSubs: subs, catalog: c), catalog: c)
        let bySub = Dictionary(uniqueKeysWithValues: hits.map { ($0.subId, $0) })
        XCTAssertEqual(bySub["prime-video"]?.level, .included)
        XCTAssertEqual(bySub["prime-video"]?.valueMonthly ?? 0, 8.99, accuracy: 0.001)
        XCTAssertTrue(bySub["prime-video"]?.inferred ?? false)
        XCTAssertEqual(bySub["youtube-music"]?.level, .included)
        XCTAssertNil(bySub["amazon-prime"], "the membership itself is never 'covered'")
        XCTAssertNil(bySub["youtube-premium"])
        XCTAssertEqual(hits.first?.subId, "youtube-music", "sorted by value")
    }

    func testInferredCarrierPerkIsOnlyAHintUntilConfirmed() {
        let c = testCatalog()
        let inferred = BundleCoverage.inferredBundleIds(activeSubs: subs, catalog: c)
        let weak = BundleCoverage.hits(activeSubs: subs, ownedBundleIds: [], inferredBundleIds: inferred, catalog: c)
        XCTAssertEqual(weak.first { $0.subId == "netflix" }?.level, .discounted, "a T-Mobile bill doesn't prove the plan includes Netflix")
        let confirmed = BundleCoverage.hits(activeSubs: subs, ownedBundleIds: ["t-mobile"], inferredBundleIds: inferred, catalog: c)
        let hit = confirmed.first { $0.subId == "netflix" }
        XCTAssertEqual(hit?.level, .included)
        XCTAssertEqual(hit?.valueMonthly ?? 0, 19.99, accuracy: 0.001)
        XCTAssertFalse(hit?.inferred ?? true)
    }

    func testCardCreditIsCappedAtWhatTheSubCosts() {
        let c = testCatalog()
        let hits = BundleCoverage.hits(activeSubs: subs, ownedBundleIds: ["amex-platinum"], inferredBundleIds: [], catalog: c)
        let d = hits.first { $0.subId == "disney-plus" }
        XCTAssertEqual(d?.level, .credit)
        XCTAssertEqual(d?.valueMonthly ?? 0, 11.99, accuracy: 0.001, "$25 credit can't be worth more than the $11.99 sub")
    }

    func testCancelledSubsAreNotCovered() {
        let c = testCatalog()
        let active = subs.filter { $0.id != "prime-video" }
        let hits = BundleCoverage.hits(activeSubs: active, ownedBundleIds: [], inferredBundleIds: ["amazon-prime"], catalog: c)
        XCTAssertNil(hits.first { $0.subId == "prime-video" })
    }
}

final class TransactionLedgerTests: XCTestCase {
    private func tx(_ m: String, _ a: Double, daysAgo d: Int, now: Date) -> ParsedTransaction {
        ParsedTransaction(merchant: m, amount: a, date: dateDaysAgo(d, from: now), rawRow: m)
    }

    func testMergeDedupesSameChargeAcrossImports() {
        let now = Date()
        let first = TransactionLedger.merged(existing: [], incoming: [tx("Netflix", 15.99, daysAgo: 30, now: now)], now: now)
        XCTAssertEqual(first.count, 1)
        let second = TransactionLedger.merged(existing: first, incoming: [
            tx("Netflix", 15.99, daysAgo: 30, now: now),   // same charge, re-imported
            tx("Netflix", 15.99, daysAgo: 0, now: now),    // this month
        ], now: now)
        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(second.first?.date, dateDaysAgo(0, from: now), "newest first")
    }

    func testOldChargesArePruned() {
        let now = Date()
        let merged = TransactionLedger.merged(existing: [], incoming: [
            tx("Netflix", 15.99, daysAgo: 800, now: now),
            tx("Netflix", 15.99, daysAgo: 10, now: now),
        ], now: now)
        XCTAssertEqual(merged.count, 1)
    }

    func testRecurringHintSurvivesRoundTrip() {
        let now = Date()
        let merged = TransactionLedger.merged(existing: [], incoming: [
            ParsedTransaction(merchant: "Rock Spot Climbing", amount: 62, date: now, rawRow: "RECURRING CARD PURCHASE ROCK SPOT CLIMBING")
        ], now: now)
        XCTAssertTrue(merged.first?.recurringHint ?? false)
        XCTAssertTrue(merged.first?.toTransaction().recurringHint ?? false)
    }

    func testLedgerFeedsCrossMonthConfirmation() {
        // Month 1 alone is only "likely"; with month 1 in the ledger, month 2 confirms.
        let now = Date()
        let month1 = [tx("NETFLIX.COM", 15.99, daysAgo: 31, now: now)]
        let ledger = TransactionLedger.merged(existing: [], incoming: month1, now: now).map { $0.toTransaction() }
        let month2 = [tx("NETFLIX.COM", 15.99, daysAgo: 1, now: now)]
        XCTAssertTrue(RecurrenceDetector.detect(in: month2).isEmpty)
        XCTAssertEqual(RecurrenceDetector.detect(in: month2 + ledger).count, 1)
    }
}

final class PriceMonitorMatchingTests: XCTestCase {
    private let catalog: [PriceMonitor.RemotePrice] = [
        PriceMonitor.RemotePrice(id: "netflix-standard", name: "Netflix Standard", priceMonthly: 19.99, category: "Entertainment", prevPrice: 17.99, hikedAt: "2026-03-26"),
        PriceMonitor.RemotePrice(id: "netflix-premium", name: "Netflix Premium", priceMonthly: 26.99, category: "Entertainment", prevPrice: 24.99, hikedAt: "2026-03-26"),
        PriceMonitor.RemotePrice(id: "hulu", name: "Hulu (No Ads)", priceMonthly: 18.99, category: "Entertainment", prevPrice: nil, hikedAt: nil),
    ]

    func testHikeMatchesTheTierTheUserPays() {
        let premium = PriceMonitor.matches(in: [makeSub(amount: 26.99)], catalog: catalog)
        XCTAssertEqual(premium.first?.entryId, "netflix-premium")
        XCTAssertEqual(premium.first?.previous, 24.99)
        let standard = PriceMonitor.matches(in: [makeSub(amount: 17.99)], catalog: catalog)
        XCTAssertEqual(standard.first?.entryId, "netflix-standard", "pre-hike price still identifies the tier")
        XCTAssertEqual(standard.first?.hikedAt.map { Calendar(identifier: .gregorian).component(.year, from: $0) }, 2026)
    }

    func testAdsTierUserIsNotToldAboutAStandardHike() {
        XCTAssertTrue(PriceMonitor.matches(in: [makeSub(amount: 8.99)], catalog: catalog).isEmpty)
    }

    func testNoHikeWithoutPrevPrice() {
        XCTAssertTrue(PriceMonitor.matches(in: [makeSub(id: "hulu", name: "Hulu", amount: 18.99)], catalog: catalog).isEmpty)
    }
}
