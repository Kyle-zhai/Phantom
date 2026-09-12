import XCTest
@testable import Phantom

/// Brand mapping, recurring hints, and transactional rejection — the layers
/// that decide whether an OCR row becomes a subscription and which one.
final class MerchantNormalizerTests: XCTestCase {

    private func brand(_ raw: String) -> String {
        let normalized = MerchantNormalizer.normalize(raw) ?? raw
        return MerchantNormalizer.brandId(forNormalized: normalized)
    }

    func testMicrosoftIsNoLongerLabelledGitHub() {
        XCTAssertEqual(brand("MICROSOFT*365 PERSONAL"), "microsoft-365")
        XCTAssertEqual(brand("MSFT * E0700ABCDE"), "microsoft-365")
        XCTAssertEqual(BrandRegistry.displayName(for: "microsoft-365"), "Microsoft 365")
    }

    func testAppleBilledChargesAreGenericNotAppleMusic() {
        XCTAssertEqual(brand("APPLE.COM/BILL 866-712-7753 CA"), "apple-services")
        XCTAssertEqual(brand("ITUNES.COM/BILL CORK IE"), "apple-services")
        XCTAssertEqual(brand("APL*ITUNES.COM/BILL"), "apple-services")
        // Named Apple products still resolve to themselves.
        XCTAssertEqual(brand("APL*APPLE MUSIC"), "apple-music")
        XCTAssertEqual(brand("APL*ICLOUD+ STORAGE 200GB"), "icloud")
        XCTAssertEqual(brand("APL*APPLE TV+"), "apple-tv")
        XCTAssertEqual(brand("APL*APPLE ONE FAMILY"), "apple-one")
        XCTAssertEqual(brand("APL*APPLE ARCADE"), "apple-arcade")
        XCTAssertEqual(BrandRegistry.kind(for: "apple-services"), .platformBilled)
    }

    func testGoogleProductsBeforeGenericPlayBiller() {
        XCTAssertEqual(brand("GOOGLE *YouTube Music"), "youtube-music")
        XCTAssertEqual(brand("GOOGLE *YouTube Premium"), "youtube-premium")
        XCTAssertEqual(brand("GOOGLE *YouTube TV"), "youtube-tv")
        XCTAssertEqual(brand("GOOGLE *Gemini Advanced"), "gemini")
        XCTAssertEqual(brand("GOOGLE *Google One"), "google-one")
        XCTAssertEqual(brand("GOOGLE *Workspace"), "google-workspace")
        XCTAssertEqual(brand("GOOGLE *Some Game Studio"), "google-play")
    }

    func testWholeWordAliasesDontFireInsideOtherWords() {
        XCTAssertNotEqual(brand("PINEAPPLE EXPRESS SMOOTHIES"), "apple-services")
        XCTAssertNotEqual(brand("PHILOSOPHY SKINCARE"), "philo")
        XCTAssertNotEqual(brand("CALMART GROCERY"), "calm")
        XCTAssertEqual(brand("CALM.COM"), "calm")
        XCTAssertEqual(brand("MAX.COM"), "hbo-max")
        XCTAssertEqual(brand("PHILO*TV"), "philo")
        XCTAssertEqual(brand("ESPNPLUS.COM"), "espn-plus")
        XCTAssertEqual(brand("RUNWAYML"), "runway")
    }

    func testAIMediaBrandsHaveTheirOwnIds() {
        XCTAssertEqual(brand("MIDJOURNEY INC"), "midjourney")
        XCTAssertEqual(brand("MISTRAL AI"), "mistral")
        XCTAssertEqual(brand("ADOBE *ACROBAT"), "adobe")
        XCTAssertEqual(brand("ADOBE *CREATIVE CLD"), "adobe-cc")
        XCTAssertEqual(brand("ADOBE *PHOTOGRAPHY PLAN"), "adobe-photography")
    }

    func testAmazonDigitalFamily() {
        XCTAssertEqual(brand("AMAZON PRIME VIDEO*AB12C"), "prime-video")
        XCTAssertEqual(brand("AMZN PRIME*RT3JK 866-216-1072"), "amazon-prime")
        XCTAssertEqual(brand("KINDLE UNLTD*2K4J8 AMZN.COM/BILL"), "kindle-unlimited")
        XCTAssertEqual(brand("AMAZON MUSIC*UNLIMITED"), "amazon-music")
        XCTAssertEqual(brand("AMZN DIGITAL*1A2B3"), "amazon-digital")
        XCTAssertTrue(MerchantNormalizer.isLikelyTransactional("Amzn Mktp Us*w2a4qr1"))
        XCTAssertTrue(MerchantNormalizer.isLikelyTransactional("Amazon Mktplace Pmts Amzn.com/bill"))
    }

    func testDeliveryMembershipsSurviveTheDeliveryBlacklist() {
        for raw in ["INSTACART *PLUS", "INSTACART*PLUS MEMBERSHIP", "GRUBHUB*GRUBHUB+", "DOORDASH*DASHPASS SAN FRANCISCO", "UBER *ONE MEMBERSHIP UBER.COM/BILL"] {
            let n = MerchantNormalizer.normalize(raw) ?? raw
            XCTAssertFalse(MerchantNormalizer.isLikelyTransactional(n), raw)
        }
        XCTAssertEqual(brand("INSTACART *PLUS"), "instacart-plus")
        XCTAssertEqual(brand("GRUBHUB*GRUBHUB+"), "grubhub-plus")
        XCTAssertTrue(MerchantNormalizer.isLikelyTransactional("Doordash *mcdonalds"))
        XCTAssertTrue(MerchantNormalizer.isLikelyTransactional("Uber *eats Help.uber.com"))
    }

    func testRecurringHintIsReadFromTheRawRowBeforeStripping() {
        XCTAssertTrue(MerchantNormalizer.hasSubscriptionHint("RECURRING CARD PURCHASE 03/12 ROCK SPOT CLIMBING"))
        XCTAssertTrue(MerchantNormalizer.hasSubscriptionHint("AUDIBLE*MEMBERSHIP"))
        XCTAssertTrue(MerchantNormalizer.hasSubscriptionHint("NFLX*SUBSCRIPTION"))
        XCTAssertTrue(MerchantNormalizer.hasSubscriptionHint("APPLE.COM/BILL 866-712-7753"))
        XCTAssertFalse(MerchantNormalizer.hasSubscriptionHint("STARBUCKS STORE 04521"))
        XCTAssertFalse(MerchantNormalizer.hasSubscriptionHint("MONTHLYS BAR"))
        // Unknown merchant at an odd amount is accepted when the bank said "recurring".
        XCTAssertTrue(MerchantNormalizer.looksLikeSubscription(name: "Rock Spot Climbing", amount: 62.00, recurringHint: true))
        // …but "annual fee" is a card fee, never a subscription.
        XCTAssertFalse(MerchantNormalizer.looksLikeSubscription(name: "Annual Fee", amount: 95, recurringHint: true))
    }

    func testMultiChargeBillerIdRoundTrip() {
        XCTAssertTrue(MerchantNormalizer.isMultiChargeBiller("apple-services"))
        XCTAssertFalse(MerchantNormalizer.isMultiChargeBiller("netflix"))
        XCTAssertEqual(MerchantNormalizer.brandId(fromSubscriptionId: "apple-services-1299c"), "apple-services")
        XCTAssertEqual(MerchantNormalizer.brandId(fromSubscriptionId: "netflix"), "netflix")
        XCTAssertEqual(MerchantNormalizer.brandId(fromSubscriptionId: "1password"), "1password")
    }

    func testFallbackSlugGroupsOCRVariants() {
        XCTAssertEqual(MerchantNormalizer.fallbackSlug("rock spot climbing 401-555"), "rock-spot-climbing")
        XCTAssertEqual(MerchantNormalizer.fallbackSlug("rock spot climbing"), "rock-spot-climbing")
        XCTAssertEqual(MerchantNormalizer.fallbackSlug("big night live boston ma 12345"), "big-night-live")
    }

    func testEveryAliasTargetIsAKnownBrandWithAKind() {
        // Drift guard: an alias pointing at an id the registry doesn't know would
        // silently produce an unnamed sub with kind "other" — no overlap, no
        // coverage check, no alternatives. A missing SVG is fine (the letter
        // avatar is a designed fallback); a missing name or kind is not.
        // Umbrella ids are deliberately kindless: Apple One is a bundle rather
        // than a substitute for anything, and a bare "Proton" charge could be
        // Mail, VPN, Drive or Pass. Both are resolved later, not at alias time.
        let kindless: Set<String> = ["apple-one", "proton"]
        for (pattern, _, id) in MerchantNormalizer.brandAliases {
            XCTAssertNotNil(BrandRegistry.displayName(for: id),
                            "alias \"\(pattern)\" targets \(id), which has no display name")
            guard !kindless.contains(id) else { continue }
            XCTAssertNotEqual(BrandRegistry.kind(for: id), .other,
                              "alias \"\(pattern)\" targets \(id), which has no kind")
        }
    }

    func testNetflixAndSpotifyAreDifferentKinds() {
        XCTAssertEqual(BrandRegistry.kind(for: "netflix"), .video)
        XCTAssertEqual(BrandRegistry.kind(for: "spotify"), .music)
        XCTAssertEqual(BrandRegistry.kind(for: "hulu"), .video)
        XCTAssertEqual(BrandRegistry.kind(for: "xfinity"), .telecom)
        XCTAssertFalse(Kind.telecom.participatesInOverlap)
        XCTAssertFalse(Kind.platformBilled.participatesInOverlap)
        XCTAssertTrue(Kind.video.participatesInOverlap)
    }
}

/// Same-kind overlap (pure helper the store delegates to).
final class OverlapsTests: XCTestCase {
    func testOnlySameKindSubsOverlap() {
        let subs = [
            makeSub(id: "netflix", name: "Netflix"),
            makeSub(id: "hulu", name: "Hulu"),
            makeSub(id: "spotify", name: "Spotify"),
            makeSub(id: "xfinity", name: "Xfinity"),
            makeSub(id: "t-mobile", name: "T-Mobile"),
            makeSub(id: "apple-services-1299c", name: "Apple"),
        ]
        let o = Overlaps.compute(subs, cancelledIds: [])
        XCTAssertEqual(o["netflix"], ["hulu"])
        XCTAssertEqual(o["hulu"], ["netflix"])
        XCTAssertEqual(o["spotify"], [])
        XCTAssertEqual(o["xfinity"], [], "internet and wireless are not substitutes")
        XCTAssertEqual(o["apple-services-1299c"], [])
    }

    func testCancelledSubsDropOutOfOverlap() {
        let subs = [makeSub(id: "netflix"), makeSub(id: "hulu", name: "Hulu")]
        let o = Overlaps.compute(subs, cancelledIds: ["hulu"])
        XCTAssertEqual(o["netflix"], [])
    }
}
