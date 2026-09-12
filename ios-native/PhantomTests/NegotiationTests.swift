import XCTest
@testable import Phantom

/// Guards the retention playbooks the Negotiate tab ships. `tools/check_recipe_coverage.swift`
/// asserts the same coverage rules from the command line; these run in
/// `xcodebuild test` so a silently unreachable recipe fails the build.
final class NegotiationTests: XCTestCase {

    /// The universe a coverage decision is owed for: brands with a logo entry
    /// plus every mock id. Deliberately narrower than every id the taxonomy
    /// recognises — the generic script is a legitimate answer for the long tail.
    private var auditedIds: Set<String> {
        Set(BrandRegistry.byId.keys).union(MockData.subscriptions.map(\.id))
    }

    /// Every id a real subscription can actually carry.
    private var reachableIds: Set<String> {
        Set(BrandRegistry.byId.keys)
            .union(BrandRegistry.knownBrandIds)
            .union(MerchantNormalizer.brandAliases.map { $0.2 })
            .union(MockData.subscriptions.map(\.id))
    }

    /// Ids added in the 2026-09-12 community sweep. Hard-coded so deleting one
    /// by accident fails here instead of silently downgrading users to the
    /// generic script.
    private let communitySweepIds = [
        "hellofresh", "ring-home", "tinder", "apple-tv", "amc-plus", "sling",
        "youtube-tv", "tidal", "pandora", "walmart-plus", "kindle-unlimited",
        "grubhub-plus", "lovable", "att", "verizon", "proton", "runway",
    ]

    // MARK: - Coverage

    func testEveryAuditedIdHasARecipeOrAResearchedFallback() {
        let uncovered = auditedIds.filter {
            !Negotiation.hasBrandSpecificRecipe(for: $0)
                && !Negotiation.researchedGenericFallbackIds.contains($0)
        }
        XCTAssertTrue(
            uncovered.isEmpty,
            "Branded ids with neither a recipe nor a researched fallback decision: \(uncovered.sorted())"
        )
    }

    func testResearchedFallbackListDoesNotDrift() {
        let stale = Negotiation.researchedGenericFallbackIds.filter {
            !auditedIds.contains($0) || Negotiation.hasBrandSpecificRecipe(for: $0)
        }
        XCTAssertTrue(
            stale.isEmpty,
            "Fallback ids that no longer exist or now have a recipe: \(stale.sorted())"
        )
    }

    func testEveryRecipeIdIsReachableFromARealSubscriptionId() {
        let stranded = Negotiation.brandSpecificRecipeIds.subtracting(reachableIds)
        XCTAssertTrue(
            stranded.isEmpty,
            "Recipe ids no import or mock can ever produce (typo or dead entry): \(stranded.sorted())"
        )
    }

    func testEveryMockSubscriptionIdCarriesAnExplicitCoverageDecision() {
        // The bug this guards: a mock id that no recipe key matches (MockData
        // said "sirius", the recipe was keyed "sirius-xm") silently demoted the
        // demo stack to the generic script. Mister Car Wash is the intended
        // exception — it is a researched fallback, and the sample stack keeps it
        // so reviewers see a vertical with no known retention offer.
        for sub in MockData.subscriptions {
            XCTAssertTrue(
                reachableIds.contains(sub.id),
                "Mock sub \(sub.id) is not a brand id the app can produce"
            )
            XCTAssertTrue(
                Negotiation.hasBrandSpecificRecipe(for: sub.id)
                    || Negotiation.researchedGenericFallbackIds.contains(sub.id),
                "Mock sub \(sub.id) falls through to the generic script by accident"
            )
        }
    }

    // MARK: - Aliases

    func testBillingDescriptorAliasesResolveToTheCanonicalPlaybook() {
        let pairs = [
            ("adobe", "adobe-cc"),
            ("anthropic", "claude"),
            ("openai", "chatgpt"),
            ("paramount-plus", "paramount"),
            ("proton-vpn", "proton"),
        ]
        for (aliasId, canonicalId) in pairs {
            let alias = Negotiation.offer(for: makeSub(id: aliasId, name: "Alias", amount: 19.99))
            let canonical = Negotiation.offer(for: makeSub(id: canonicalId, name: "Canonical", amount: 19.99))
            XCTAssertNotNil(canonical, "\(canonicalId) has no recipe to alias")
            XCTAssertEqual(alias?.expectedDiscount, canonical?.expectedDiscount, aliasId)
            XCTAssertEqual(alias?.script, canonical?.script, aliasId)
            XCTAssertEqual(alias?.yearlySaving, canonical?.yearlySaving, aliasId)
            XCTAssertEqual(alias?.tips, canonical?.tips, aliasId)
            XCTAssertEqual(alias?.successRate, canonical?.successRate, aliasId)
        }
    }

    func testNoIdIsClaimedByBothTables() {
        // An id in both tables means we shipped a playbook and also recorded
        // that no playbook exists. Whichever is stale, the reader is misled.
        let contested = Negotiation.brandSpecificRecipeIds
            .intersection(Negotiation.researchedGenericFallbackIds)
        XCTAssertTrue(contested.isEmpty, "Ids claimed by both tables: \(contested.sorted())")
    }

    // MARK: - Playbook quality

    func testCommunitySweepRecipesAreLabelledEstimatedAndCarryACitation() {
        for id in communitySweepIds {
            guard let offer = Negotiation.offer(for: makeSub(id: id, name: id, amount: 19.99)) else {
                XCTFail("\(id) produced no offer")
                continue
            }
            XCTAssertTrue(
                Negotiation.hasBrandSpecificRecipe(for: id),
                "\(id) lost its recipe and now gets the generic script"
            )
            XCTAssertTrue(
                offer.successRateEstimated,
                "\(id) is sourced from public reports, so the rate must be flagged as an estimate"
            )
            XCTAssertTrue(
                offer.tips.contains(where: isCited),
                "\(id) needs at least one tip citing its source"
            )
        }
    }

    func testNoPlaybookPromisesMoreThanAYearOfTheSubscriptionsOwnCost() {
        for id in Negotiation.brandSpecificRecipeIds {
            let sub = makeSub(id: id, name: id, amount: 19.99)
            guard let offer = Negotiation.offer(for: sub) else { continue }
            XCTAssertGreaterThanOrEqual(offer.yearlySaving, 0, id)
            XCTAssertLessThanOrEqual(
                offer.yearlySaving,
                sub.monthlyAmount * 12,
                "\(id) claims more than the subscription costs in a year"
            )
        }
    }

    func testConditionalOffersAreDiscountedRatherThanClaimedInFull() {
        // Grubhub+ only disappears for someone who already pays for Prime, and
        // the Lovable Lite plan rests on a single public report. Neither may
        // claim the full-year figure an unconditional downgrade earns.
        let sub = makeSub(id: "grubhub-plus", name: "Grubhub+", amount: 9.99)
        let grubhub = Negotiation.offer(for: sub)
        XCTAssertLessThan(grubhub?.yearlySaving ?? .infinity, sub.monthlyAmount * 12)

        let lovableSub = makeSub(id: "lovable", name: "Lovable", amount: 25)
        let lovable = Negotiation.offer(for: lovableSub)
        XCTAssertLessThan(lovable?.yearlySaving ?? .infinity, lovableSub.monthlyAmount * 12 * 0.5)
    }

    func testUnknownBrandFallsBackToTheGenericOffer() {
        let sub = makeSub(id: "some-unknown-merchant", name: "Some Merchant", amount: 10)
        let offer = Negotiation.offer(for: sub)
        XCTAssertEqual(offer?.successRate, 35)
        XCTAssertEqual(offer?.successRateEstimated, true)
        XCTAssertEqual(offer?.yearlySaving, 3.0, "generic estimate is 10% off three months")
        XCTAssertEqual(offer?.channel, .chat)
        XCTAssertTrue(offer?.tips.isEmpty == false)
    }

    // MARK: - Helpers

    /// True when a tip carries a source reference, e.g. "(reddit.com/r/Ring/…)".
    private func isCited(_ tip: String) -> Bool {
        tip.range(of: "[a-z0-9-]+\\.[a-z]{2,5}/", options: .regularExpression) != nil
    }
}
