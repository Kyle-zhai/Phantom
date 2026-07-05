import XCTest
@testable import Phantom

/// Guards the fix for the review's #1 finding: before, EVERY imported sub scored
/// 38 ("keep") because usage/overlap/rating/market were all empty and the two
/// usage factors were pinned at neutral 50 (capping the max at 70). These tests
/// pin the corrected behavior — a lone sub stays "keep", but duplicates and
/// low-rated subs can now actually reach the "zombie" tier.
final class ZombieScoreTests: XCTestCase {

    func testLoneUnratedImportStaysKeep() {
        // No overlap, no rating, no market, no usage data — nothing to flag.
        let s = makeSub()
        let score = ZombieScore.compute(s).score
        XCTAssertLessThan(score, 50, "A lone, unrated import must not be false-flagged")
        XCTAssertEqual(ZombieScore.tier(for: score), .keep)
    }

    func testDuplicatesPlusLowRatingReachZombie() {
        // Three same-category subs → this one overlaps two peers; user rates it 1★.
        let s = makeSub(userRating: 1, hasOverlapWith: ["hulu", "disney-plus"])
        let score = ZombieScore.compute(s).score
        XCTAssertGreaterThanOrEqual(score, 80, "Duplicate + low rating should be a zombie")
        XCTAssertEqual(ZombieScore.tier(for: score), .zombie)
    }

    func testDuplicatesAloneAreReviewNotZombie() {
        // Overlap without any corroborating signal should surface as "review",
        // not auto-condemn every member of a category to "zombie".
        let s = makeSub(hasOverlapWith: ["hulu", "disney-plus"])
        let score = ZombieScore.compute(s).score
        XCTAssertEqual(ZombieScore.tier(for: score), .review)
    }

    func testKnownUsagePathUsesFullPRDWeights() {
        // When real usage data exists we must keep the exact PRD §3.2 weighting.
        // recency=100 (120d unused), usageVsPrice=100 (0 sessions), overlap=0,
        // rating=50 (unrated), market=0 → 100·.35 + 100·.25 + 0 + 50·.15 + 0 = 67.5.
        let s = makeSub(
            amount: 40,
            lastUsedAt: Date().addingTimeInterval(-120 * 86_400),
            sessionsLast30d: 0
        )
        XCTAssertEqual(ZombieScore.compute(s).score, 68) // 67.5 rounded
    }

    func testKnownUsageBadSubReachesZombie() {
        // Long-unused, low-rated, duplicated → unambiguous zombie under full weights.
        let s = makeSub(
            amount: 40,
            lastUsedAt: Date().addingTimeInterval(-120 * 86_400),
            sessionsLast30d: 0,
            userRating: 1,
            hasOverlapWith: ["hulu", "disney-plus"]
        )
        XCTAssertGreaterThanOrEqual(ZombieScore.compute(s).score, 80)
    }

    func testScoreAlwaysClampedToRange() {
        for rating in [1, 3, 5] {
            let s = makeSub(userRating: rating, hasOverlapWith: ["a", "b", "c"])
            let score = ZombieScore.compute(s).score
            XCTAssert((0...100).contains(score), "score \(score) out of range")
        }
    }
}
