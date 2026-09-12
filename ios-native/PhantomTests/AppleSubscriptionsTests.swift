import XCTest
import CoreGraphics
@testable import Phantom

/// The Apple subscriptions list (Settings › Subscriptions) is the only source
/// that can NAME an APPLE.COM/BILL charge; these tests pin the parser and the
/// reconciliation that stops the same money appearing twice.
final class AppleSubscriptionsParserTests: XCTestCase {
    private let now: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 10
        return Calendar.current.date(from: c)!
    }()

    /// Lines top-to-bottom → OCR.Line with descending Y (Vision origin is bottom-left).
    private func lines(_ texts: [String]) -> [OCR.Line] {
        texts.enumerated().map { i, t in
            OCR.Line(text: t, confidence: 0.98, box: CGRect(x: 0.05, y: 1.0 - CGFloat(i + 1) * 0.03, width: 0.6, height: 0.02))
        }
    }

    private let settingsScreen = [
        "Subscriptions", "Active",
        "Netflix", "Standard with ads", "$8.99/month", "Renews Oct 12, 2026",
        "Apple TV+", "Monthly", "$14.99/month", "Renews Sep 30, 2026",
        "Fitbod", "Yearly", "$79.99/year", "Renews Mar 2, 2027",
        "Headspace", "Free trial until Sep 20, 2026, then $12.99/month",
        "Inactive",
        "Calm", "Expired Aug 1, 2026",
        "Duolingo", "Super", "$12.99/month", "Expires Sep 25, 2026",
    ]

    func testRecognisesTheAppleListAndNotABankStatement() {
        XCTAssertTrue(AppleSubscriptionsParser.looksLikeAppleList(lines(settingsScreen)))
        let bank = lines(["Statements 05/14/2026", "May 8, 2026   $18.86", "UBER *EATS HELP.UBER.COM   $1,343.61", "May 6, 2026   $15.49", "NETFLIX.COM   $1,324.75"])
        XCTAssertFalse(AppleSubscriptionsParser.looksLikeAppleList(bank))
    }

    func testParsesActiveRowsAndSkipsExpiredOnes() throws {
        let subs = AppleSubscriptionsParser.parse(lines: lines(settingsScreen), now: now)
        XCTAssertEqual(Set(subs.map(\.id)), ["netflix", "apple-tv", "apple-fitbod", "headspace"],
                       "expired Calm and cancelled-but-running Duolingo are not live subscriptions")
        let netflix = try XCTUnwrap(subs.first { $0.id == "netflix" })
        XCTAssertEqual(netflix.amount, 8.99, accuracy: 0.001)
        XCTAssertEqual(netflix.cycle, .monthly)
        XCTAssertEqual(netflix.billedVia, .apple)
        XCTAssertEqual(netflix.name, "Netflix")
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day], from: netflix.nextBilling).day, 12)
        XCTAssertTrue(netflix.rawDescriptor?.contains("Standard with ads") ?? false)

        let fitbod = try XCTUnwrap(subs.first { $0.id == "apple-fitbod" })
        XCTAssertEqual(fitbod.cycle, .yearly)
        XCTAssertEqual(fitbod.monthlyAmount, 79.99 / 12, accuracy: 0.001)
        XCTAssertEqual(fitbod.category, .other)

        let headspace = try XCTUnwrap(subs.first { $0.id == "headspace" })
        XCTAssertEqual(headspace.amount, 12.99, accuracy: 0.001)
        let trial = try XCTUnwrap(headspace.trialEndsAt)
        XCTAssertEqual(Calendar.current.component(.day, from: trial), 20)
        XCTAssertTrue(subs.allSatisfy { $0.billedVia == .apple })
    }

    func testAppStoreStyleRowsWithYearlessDates() throws {
        let screen = ["Subscriptions", "Spotify", "Premium Individual", "$12.99 / month", "Next billing date: Oct 3", "iCloud+", "2TB", "$9.99 per month", "Renews Sep 30", "YouTube Premium", "$15.99/month · Renews Oct 20, 2026"]
        let subs = AppleSubscriptionsParser.parse(lines: lines(screen), now: now)
        XCTAssertEqual(Set(subs.map(\.id)), ["spotify", "icloud", "youtube-premium"])
        let yt = try XCTUnwrap(subs.first { $0.id == "youtube-premium" })
        XCTAssertEqual(Calendar.current.component(.day, from: yt.nextBilling), 20, "price and renewal on one line")
        let spotify = try XCTUnwrap(subs.first { $0.id == "spotify" })
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: spotify.nextBilling)
        XCTAssertEqual(comps.year, 2026, "a year-less renewal date pins to the next occurrence")
        XCTAssertEqual(comps.month, 10)
        XCTAssertEqual(spotify.amount, 12.99, accuracy: 0.001)
    }

    func testPricePeriodVariants() {
        XCTAssertEqual(AppleSubscriptionsParser.pricePeriod(in: "$29.99/6 months")?.1, .semiannual)
        XCTAssertEqual(AppleSubscriptionsParser.pricePeriod(in: "$19.99/3 months")?.1, .quarterly)
        XCTAssertEqual(AppleSubscriptionsParser.pricePeriod(in: "$2.99/week")?.1, .weekly)
        XCTAssertEqual(AppleSubscriptionsParser.pricePeriod(in: "$99.99/yr")?.1, .yearly)
        XCTAssertEqual(AppleSubscriptionsParser.pricePeriod(in: "$1,299.00 per year")?.0, 1299)
        XCTAssertNil(AppleSubscriptionsParser.pricePeriod(in: "NETFLIX.COM $15.49"))
        // Name on the same line as the price.
        let p = AppleSubscriptionsParser.pricePeriod(in: "Peacock Premium — $12.99/month")
        XCTAssertEqual(p?.2, "Peacock Premium")
    }

    func testBillingCycleSemiannualMath() {
        let s = makeSub(amount: 30, cycle: .semiannual)
        XCTAssertEqual(s.monthlyAmount, 5, accuracy: 0.001)
        XCTAssertEqual(s.yearlyAmount, 60, accuracy: 0.001)
    }
}

final class AppleReconcilerTests: XCTestCase {
    private func anonymous(_ amount: Double, daysAgo: Int = 40) -> Subscription {
        let cents = Int((amount * 100).rounded())
        var s = makeSub(id: "apple-services-\(cents)c", name: "Apple (App Store) · $\(amount)", amount: amount)
        s.rawDescriptor = "APPLE.COM/BILL 866-712-7753 CA"
        return Subscription(
            id: s.id, name: s.name, vendor: s.vendor, rawDescriptor: s.rawDescriptor, brandHex: s.brandHex,
            category: s.category, amount: s.amount, cycle: s.cycle, nextBilling: s.nextBilling,
            startedAt: Date().addingTimeInterval(-Double(daysAgo) * 86_400), lastUsedAt: nil, sessionsLast30d: 0,
            userRating: 2, marketAverage: 0, trialEndsAt: nil, hasPriceHike: nil, hasOverlapWith: [], notes: nil
        )
    }

    private func named(_ id: String, _ amount: Double) -> Subscription {
        var s = makeSub(id: id, name: id.capitalized, amount: amount)
        s.billedVia = .apple
        s.rawDescriptor = "Apple Subscriptions · \(id.capitalized)"
        return s
    }

    func testAppleListSubAbsorbsTheAnonymousBankCharge() throws {
        let existing = [anonymous(19.99), anonymous(2.99), makeSub(id: "hulu", name: "Hulu", amount: 17.99)]
        let outcome = AppleReconciler.reconcile(existing: existing, incoming: [named("netflix", 19.99)])
        XCTAssertEqual(outcome.removeExistingIds, ["apple-services-1999c"], "only the matching amount is folded")
        let netflix = try XCTUnwrap(outcome.incoming.first)
        XCTAssertEqual(netflix.id, "netflix")
        XCTAssertEqual(netflix.userRating, 2, "the rating the user gave the anonymous charge carries over")
        XCTAssertLessThan(netflix.startedAt, Date().addingTimeInterval(-30 * 86_400), "earliest bank date carries over")
        XCTAssertTrue(netflix.rawDescriptor?.contains("APPLE.COM/BILL") ?? false)
        XCTAssertEqual(netflix.billedVia, .apple)
    }

    func testBankChargeArrivingAfterTheAppleListIsDroppedNotDuplicated() {
        let existing = [named("netflix", 19.99)]
        let outcome = AppleReconciler.reconcile(existing: existing, incoming: [anonymous(19.99), anonymous(4.99)])
        XCTAssertTrue(outcome.removeExistingIds.isEmpty)
        XCTAssertEqual(outcome.incoming.map(\.id).sorted(), ["apple-services-499c", "netflix"],
                       "the $19.99 bank row becomes an update to Netflix; the $4.99 one is still anonymous")
    }

    func testSameImportCanCarryBothViews() {
        let outcome = AppleReconciler.reconcile(existing: [], incoming: [anonymous(9.99), named("spotify", 9.99)])
        XCTAssertEqual(outcome.incoming.map(\.id), ["spotify"])
    }

    func testDifferentAmountsStaySeparate() {
        let outcome = AppleReconciler.reconcile(existing: [anonymous(12.99)], incoming: [named("netflix", 19.99)])
        XCTAssertTrue(outcome.removeExistingIds.isEmpty)
        XCTAssertEqual(outcome.incoming.count, 1)
    }

    func testNonAppleSubsPassThroughUntouched() {
        let hulu = makeSub(id: "hulu", name: "Hulu", amount: 17.99)
        let outcome = AppleReconciler.reconcile(existing: [anonymous(17.99)], incoming: [hulu])
        XCTAssertTrue(outcome.removeExistingIds.isEmpty, "a card-billed Hulu is not the Apple charge even at the same price")
        XCTAssertEqual(outcome.incoming.first?.billedVia, nil)
    }

    func testBilledViaSurvivesPersistence() {
        let sub = named("netflix", 19.99)
        let row = PersistentSubscription(from: sub)
        XCTAssertEqual(row.billedViaRaw, "apple")
        XCTAssertEqual(row.toDomain().billedVia, .apple)
        XCTAssertNil(PersistentSubscription(from: makeSub()).toDomain().billedVia)
    }

    func testAppleBilledSubsUseTheApplePathWhateverTheBrand() {
        let path = CancellationRegistry.path(forSubscriptionId: "netflix", fallbackName: "Netflix", billedViaApple: true)
        XCTAssertEqual(path.url, CancellationRegistry.appleSubscriptions.url)
        let direct = CancellationRegistry.path(forSubscriptionId: "netflix", fallbackName: "Netflix")
        XCTAssertNotEqual(direct.url, CancellationRegistry.appleSubscriptions.url)
    }
}
