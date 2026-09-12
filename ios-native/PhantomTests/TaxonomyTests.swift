import XCTest
@testable import Phantom

/// The kind list is the spine of overlap, coverage, the cheaper-plan finder and
/// the For-you page. These guard the invariants that are easy to break when a
/// new vertical is added.
final class TaxonomyTests: XCTestCase {

    func testEveryKindHasAUniqueHumanLabel() {
        var seen = Set<String>()
        for k in Kind.allCases {
            let l = k.label
            XCTAssertFalse(l.isEmpty, "\(k.rawValue) has no label")
            XCTAssertTrue(seen.insert(l).inserted, "duplicate label \(l)")
        }
    }

    func testHeterogeneousKindsNeverFlagDuplicates() {
        // Two creators, X Premium vs LinkedIn Premium, therapy vs a prescription
        // service, a car wash vs connected-car data, two kids' apps — none of
        // these are substitutes, so they must never raise a zombie score.
        for k in [Kind.creatorSupport, .socialMedia, .health, .auto, .kids,
                  .telecom, .platformBilled, .other, .devTools] {
            XCTAssertFalse(k.participatesInOverlap, "\(k.rawValue) should not overlap")
        }
        for k in [Kind.video, .sports, .dating, .finance, .security, .mealKit,
                  .homeSecurity, .webHosting, .email, .podcasts] {
            XCTAssertTrue(k.participatesInOverlap, "\(k.rawValue) should overlap")
        }
    }

    func testCategoryIsDerivedFromKindForBrandsWithNoHandMapping() {
        // A brand added to knownKinds but not to knownCategories must still land
        // in a sensible coarse bucket rather than "Other".
        for (brand, expected) in [("netflix", Category.entertainment), ("icloud", .tools)] {
            XCTAssertEqual(BrandRegistry.category(for: brand), expected)
        }
        XCTAssertEqual(Kind.sports.category, .entertainment)
        XCTAssertEqual(Kind.finance.category, .tools)
        XCTAssertEqual(Kind.mealKit.category, .shopping)
        XCTAssertEqual(Kind.health.category, .health)
        XCTAssertEqual(BrandRegistry.category(for: "definitely-not-a-brand"), .other)
    }

    func testCatalogAndRegistryAgreeOnEveryServiceKind() throws {
        let c = try XCTUnwrap(AlternativesCatalogLoader.bundled())
        for svc in c.services {
            let registry = BrandRegistry.kind(for: svc.brandId)
            XCTAssertEqual(registry, svc.kindValue,
                           "\(svc.brandId): catalog says \(svc.kind), registry says \(registry.rawValue)")
            XCTAssertNotNil(BrandRegistry.displayName(for: svc.brandId),
                            "\(svc.brandId) has no display name — it would render as a letter avatar")
        }
    }

    func testEveryCatalogAlternativeIsNameableAndTagged() throws {
        let c = try XCTUnwrap(AlternativesCatalogLoader.bundled())
        for svc in c.services {
            for alt in svc.alternatives ?? [] {
                XCTAssertNotEqual(alt.brandId, svc.brandId, "\(svc.brandId) recommends itself")
                XCTAssertNotNil(alt.edgeValue, "\(svc.brandId) → \(alt.brandId) has no usable edge")
                XCTAssertFalse(alt.name.isEmpty)
            }
        }
    }
}
