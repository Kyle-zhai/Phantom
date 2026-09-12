import XCTest
@testable import Phantom

/// Pins the score's two regimes. Usage-known keeps the exact PRD §3.2 weights;
/// usage-unknown (every real import) renormalizes over overlap, rating,
/// bundle coverage, price gap, and recent hikes. See ZombieScore.compute.
final class ZombieScoreTests: XCTestCase {

    // MARK: Existing calibration (unchanged behaviour)

    func testLoneUnratedImportStaysKeep() {
        let s = makeSub()
        let score = ZombieScore.compute(s).score
        XCTAssertLessThan(score, 50, "A lone, unrated import must not be false-flagged")
        XCTAssertEqual(ZombieScore.tier(for: score), .keep)
    }

    func testDuplicatesPlusLowRatingReachZombie() {
        let s = makeSub(userRating: 1, hasOverlapWith: ["hulu", "disney-plus"])
        let score = ZombieScore.compute(s).score
        XCTAssertGreaterThanOrEqual(score, 80, "Duplicate + low rating should be a zombie")
        XCTAssertEqual(ZombieScore.tier(for: score), .zombie)
    }

    func testDuplicatesAloneAreReviewNotZombie() {
        let s = makeSub(hasOverlapWith: ["hulu", "disney-plus"])
        let score = ZombieScore.compute(s).score
        XCTAssertEqual(ZombieScore.tier(for: score), .review)
    }

    func testKnownUsagePathUsesFullPRDWeights() {
        // recency=100 (120d unused), usageVsPrice=100 (0 sessions), overlap=0,
        // rating=50 (unrated), market=0 → 100·.35 + 100·.25 + 0 + 50·.15 + 0 = 67.5.
        let s = makeSub(amount: 40, lastUsedAt: Date().addingTimeInterval(-120 * 86_400), sessionsLast30d: 0)
        let b = ZombieScore.compute(s)
        XCTAssertEqual(b.score, 68)
        XCTAssertTrue(b.usageKnown)
        XCTAssertEqual(b.weight(.recency), 0.35, accuracy: 0.001)
        XCTAssertEqual(b.weight(.usage), 0.25, accuracy: 0.001)
    }

    func testKnownUsageBadSubReachesZombie() {
        let s = makeSub(amount: 40, lastUsedAt: Date().addingTimeInterval(-120 * 86_400),
                        sessionsLast30d: 0, userRating: 1, hasOverlapWith: ["hulu", "disney-plus"])
        XCTAssertGreaterThanOrEqual(ZombieScore.compute(s).score, 80)
    }

    func testScoreAlwaysClampedToRange() {
        for rating in [1, 3, 5] {
            let s = makeSub(userRating: rating, hasOverlapWith: ["a", "b", "c"])
            let score = ZombieScore.compute(s).score
            XCTAssert((0...100).contains(score), "score \(score) out of range")
        }
    }

    // MARK: New signals

    func testWeightsAlwaysSumToOne() {
        let cases: [(Subscription, ScoreContext)] = [
            (makeSub(), .none),
            (makeSub(userRating: 2, hasOverlapWith: ["hulu"]), ScoreContext(coverage: .included, cheapestTierMonthly: 8.99, kindMedianMonthly: 12)),
            (makeSub(lastUsedAt: daysAgo(3), sessionsLast30d: 10), .none),
            (makeSub(hasPriceHike: PriceHike(from: 15.49, to: 17.99, effective: daysAgo(10))), .none),
        ]
        for (sub, ctx) in cases {
            let sum = ZombieScore.compute(sub, context: ctx).weights.values.reduce(0, +)
            XCTAssertEqual(sum, 1, accuracy: 0.0001)
        }
    }

    func testRatedOneStarAloneIsWorthAReview() {
        // "I never use it" is the strongest on-device signal; before it was
        // diluted to "keep" (43) when nothing else corroborated it.
        let b = ZombieScore.compute(makeSub(userRating: 1))
        XCTAssertEqual(ZombieScore.tier(for: b.score), .review)
    }

    func testFiveStarsWithDuplicatesStaysKeep() {
        let b = ZombieScore.compute(makeSub(userRating: 5, hasOverlapWith: ["hulu", "peacock"]))
        XCTAssertEqual(ZombieScore.tier(for: b.score), .keep, "loving it beats owning a duplicate")
    }

    func testCoveredByOwnedBundleIsReview() {
        // Paying separately for something a bundle you hold includes.
        let b = ZombieScore.compute(makeSub(), context: ScoreContext(coverage: .included))
        XCTAssertEqual(ZombieScore.tier(for: b.score), .review)
        XCTAssertEqual(b.coverage, 100)
        XCTAssertGreaterThan(b.weight(.coverage), 0)
        XCTAssertEqual(b.overlap, 50, "the bundle counts as one duplicate")
    }

    func testCoveredPlusOneStarIsZombie() {
        let b = ZombieScore.compute(makeSub(userRating: 1), context: ScoreContext(coverage: .included))
        XCTAssertGreaterThanOrEqual(b.score, 80)
    }

    func testCreditAndDiscountAreWeakerThanIncluded() {
        let inc = ZombieScore.compute(makeSub(), context: ScoreContext(coverage: .included)).score
        let cre = ZombieScore.compute(makeSub(), context: ScoreContext(coverage: .credit)).score
        let dis = ZombieScore.compute(makeSub(), context: ScoreContext(coverage: .discounted)).score
        XCTAssertGreaterThan(inc, cre)
        XCTAssertGreaterThan(cre, dis)
        XCTAssertGreaterThan(dis, ZombieScore.compute(makeSub()).score)
    }

    func testCheaperTierGapIsAPriceSignalButNotAZombieOnItsOwn() {
        // Netflix Premium $26.99 while the ads tier is $8.99.
        let b = ZombieScore.compute(makeSub(amount: 26.99, userRating: 3), context: ScoreContext(cheapestTierMonthly: 8.99))
        XCTAssertEqual(b.priceVsMarket, 100)
        XCTAssertGreaterThan(b.weight(.price), 0)
        XCTAssertEqual(ZombieScore.tier(for: b.score), .keep, "overpaying is a downgrade tip, not a zombie")
        // Already on the cheapest tier → price factor present but zero.
        let c = ZombieScore.compute(makeSub(amount: 8.99), context: ScoreContext(cheapestTierMonthly: 8.99))
        XCTAssertEqual(c.priceVsMarket, 0)
    }

    func testKindMedianIsTheFallbackMarketComparison() {
        let b = ZombieScore.compute(makeSub(amount: 24), context: ScoreContext(kindMedianMonthly: 12))
        XCTAssertEqual(b.priceVsMarket, 100)
        let cheap = ZombieScore.compute(makeSub(amount: 8), context: ScoreContext(kindMedianMonthly: 12))
        XCTAssertEqual(cheap.priceVsMarket, 0)
    }

    func testRecentHikeCountsAndOldHikeDoesNot() {
        let recent = makeSub(hasPriceHike: PriceHike(from: 15.49, to: 17.99, effective: daysAgo(10)))
        let b = ZombieScore.compute(recent)
        XCTAssertGreaterThan(b.weight(.hike), 0)
        XCTAssertEqual(b.priceHike, 65, "16% hike × 4 → 65")
        let old = makeSub(hasPriceHike: PriceHike(from: 15.49, to: 17.99, effective: daysAgo(300)))
        XCTAssertEqual(ZombieScore.compute(old).weight(.hike), 0)
        let announced = makeSub(hasPriceHike: PriceHike(from: 15.49, to: 17.99, effective: daysAgo(-7)))
        XCTAssertGreaterThan(ZombieScore.compute(announced).weight(.hike), 0)
    }

    func testFullWeightsIgnoreCoverageWeightButCountItAsAPeer() {
        let s = makeSub(amount: 40, lastUsedAt: daysAgo(120), sessionsLast30d: 0)
        let b = ZombieScore.compute(s, context: ScoreContext(coverage: .included))
        XCTAssertEqual(b.weight(.coverage), 0)
        XCTAssertEqual(b.overlap, 50)
        XCTAssertEqual(b.weight(.overlap), 0.20, accuracy: 0.001)
    }

    func testBillingCycleMath() {
        XCTAssertEqual(makeSub(amount: 30, cycle: .quarterly).monthlyAmount, 10, accuracy: 0.001)
        XCTAssertEqual(makeSub(amount: 30, cycle: .quarterly).yearlyAmount, 120, accuracy: 0.001)
        XCTAssertEqual(makeSub(amount: 20, cycle: .biweekly).yearlyAmount, 520, accuracy: 0.001)
        XCTAssertEqual(makeSub(amount: 120, cycle: .yearly).monthlyAmount, 10, accuracy: 0.001)
        XCTAssertEqual(makeSub(amount: 10, cycle: .weekly).monthlyAmount, 43.33, accuracy: 0.01)
    }
}
