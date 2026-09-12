import XCTest
import CoreGraphics
@testable import Phantom

/// Guards the parser fixes (#5 bare MM/DD dates, #7 credits-as-charges), the
/// recurring hint, multi-charge billers, and the category-inference that
/// powers overlap.
final class ParsingTests: XCTestCase {

    private func row(_ text: String, y: CGFloat) -> OCR.Line {
        OCR.Line(text: text, confidence: 0.99, box: CGRect(x: 0, y: y, width: 1, height: 0.01))
    }

    func testBareNumericDateGetsCurrentYearNotYear2000() {
        let txs = TransactionParser.parse(lines: [row("NETFLIX.COM 02/08 $15.99", y: 0.5)])
        XCTAssertEqual(txs.count, 1)
        let tx = try! XCTUnwrap(txs.first)
        XCTAssertEqual(tx.amount, 15.99, accuracy: 0.001)
        let date = try! XCTUnwrap(tx.date, "bare MM/DD must parse (was returning nil)")
        let year = Calendar.current.component(.year, from: date)
        XCTAssertGreaterThan(year, 2000, "year-less date must be backfilled, not left at 2000")
    }

    func testNegativeCreditIsNotCountedAsCharge() {
        let txs = TransactionParser.parse(lines: [row("NETFLIX.COM 02/08 -$9.99", y: 0.5)])
        XCTAssertTrue(txs.isEmpty, "a -$9.99 credit must not become a +$9.99 charge")
    }

    func testCategoryInferredForKnownBrand() {
        XCTAssertEqual(BrandRegistry.category(for: "netflix"), .entertainment)
        XCTAssertEqual(BrandRegistry.category(for: "github"), .tools)
        XCTAssertEqual(BrandRegistry.category(for: "some-unknown-brand"), .other)
    }

    func testRecurringHintIsCapturedFromTheRowBeforeThePrefixIsStripped() {
        let txs = TransactionParser.parse(lines: [row("RECURRING CARD PURCHASE 03/12 ROCK SPOT CLIMBING $62.00", y: 0.5)])
        let tx = try! XCTUnwrap(txs.first)
        XCTAssertEqual(tx.merchant, "Rock Spot Climbing")
        XCTAssertTrue(tx.recurringHint)
        let plain = TransactionParser.parse(lines: [row("STARBUCKS STORE 04521 03/12 $6.75", y: 0.5)])
        XCTAssertFalse(plain.first?.recurringHint ?? true)
    }

    func testTwoAppleChargesOnTheSameDayAreBothKept() {
        // iCloud $2.99 and a $12.99 app, both billed as APPLE.COM/BILL on the same day.
        let txs = TransactionParser.parse(lines: [
            row("APPLE.COM/BILL 866-712-7753 CA 03/12 $2.99", y: 0.6),
            row("APPLE.COM/BILL 866-712-7753 CA 03/12 $12.99", y: 0.4),
        ])
        XCTAssertEqual(txs.map(\.amount).sorted(), [2.99, 12.99])
    }

    func testRunningBalanceStillCollapsesForNormalMerchants() {
        let txs = TransactionParser.parse(lines: [
            row("NETFLIX.COM 03/12 $15.99", y: 0.6),
            row("NETFLIX.COM 03/12 $1,343.61", y: 0.4),
        ])
        XCTAssertEqual(txs.count, 1)
        XCTAssertEqual(txs.first?.amount ?? 0, 15.99, accuracy: 0.001)
    }
}

/// Guards cross-charge recurrence confirmation (feeds the confirmed vs likely
/// distinction the import UI promises), cycle inference, on-statement hikes,
/// and multi-charge billers.
final class RecurrenceDetectorTests: XCTestCase {

    private func tx(_ merchant: String, _ amount: Double, daysAgo: Int, raw: String? = nil) -> ParsedTransaction {
        ParsedTransaction(
            merchant: merchant, amount: amount,
            date: Date().addingTimeInterval(TimeInterval(-daysAgo * 86_400)),
            rawRow: raw ?? merchant
        )
    }

    func testThreeMonthlyChargesConfirmOneMonthlySub() {
        let txs = [
            tx("NETFLIX.COM", 15.99, daysAgo: 0),
            tx("NETFLIX.COM", 15.99, daysAgo: 30),
            tx("NETFLIX.COM", 15.99, daysAgo: 60),
        ]
        let subs = RecurrenceDetector.detect(in: txs)
        XCTAssertEqual(subs.count, 1)
        let sub = try! XCTUnwrap(subs.first)
        XCTAssertEqual(sub.cycle, .monthly)
        XCTAssertEqual(sub.category, .entertainment)
        XCTAssertNil(sub.hasPriceHike)
    }

    func testSingleChargeIsLikelyNotConfirmed() {
        let confirmed = RecurrenceDetector.detect(in: [tx("NETFLIX.COM", 15.99, daysAgo: 0)])
        XCTAssertTrue(confirmed.isEmpty, "one charge can't confirm recurrence")
        let likely = RecurrenceDetector.detectLikelyFromSingle([tx("NETFLIX.COM", 15.99, daysAgo: 0)])
        XCTAssertEqual(likely.count, 1)
    }

    func testCycleInference() {
        XCTAssertEqual(RecurrenceDetector.inferCycle(gaps: [30, 31, 29]), .monthly)
        XCTAssertEqual(RecurrenceDetector.inferCycle(gaps: [7, 7, 7]), .weekly)
        XCTAssertEqual(RecurrenceDetector.inferCycle(gaps: [14, 14]), .biweekly)
        XCTAssertEqual(RecurrenceDetector.inferCycle(gaps: [91, 92]), .quarterly)
        XCTAssertEqual(RecurrenceDetector.inferCycle(gaps: [365]), .yearly)
        XCTAssertEqual(RecurrenceDetector.inferCycle(gaps: [30, 61, 30]), .monthly, "a missed month is still monthly")
        XCTAssertEqual(RecurrenceDetector.inferCycle(gaps: [61]), .monthly, "one skipped charge, monthly at 2×")
        XCTAssertNil(RecurrenceDetector.inferCycle(gaps: [3, 45, 200]), "random gaps are not a cycle")
        XCTAssertNil(RecurrenceDetector.inferCycle(gaps: []))
    }

    func testQuarterlyChargeIsNotOverstatedAsMonthly() {
        let txs = [tx("PEST CO *SERVICE", 90, daysAgo: 0, raw: "PEST CO *SERVICE"),
                   tx("PEST CO *SERVICE", 90, daysAgo: 91),
                   tx("PEST CO *SERVICE", 90, daysAgo: 182)]
        let sub = try! XCTUnwrap(RecurrenceDetector.detect(in: txs).first)
        XCTAssertEqual(sub.cycle, .quarterly)
        XCTAssertEqual(sub.monthlyAmount, 30, accuracy: 0.01)
    }

    func testMissedMonthStillConfirms() {
        let txs = [tx("HULU", 17.99, daysAgo: 0), tx("HULU", 17.99, daysAgo: 61)]
        XCTAssertEqual(RecurrenceDetector.detect(in: txs).first?.cycle, .monthly)
    }

    func testPriceHikeOnTheStatementIsDetected() {
        let txs = [
            tx("NETFLIX.COM", 15.49, daysAgo: 90),
            tx("NETFLIX.COM", 15.49, daysAgo: 60),
            tx("NETFLIX.COM", 17.99, daysAgo: 30),
            tx("NETFLIX.COM", 17.99, daysAgo: 0),
        ]
        let sub = try! XCTUnwrap(RecurrenceDetector.detect(in: txs).first)
        let hike = try! XCTUnwrap(sub.hasPriceHike)
        XCTAssertEqual(hike.from, 15.49, accuracy: 0.001)
        XCTAssertEqual(hike.to, 17.99, accuracy: 0.001)
        XCTAssertEqual(Calendar.current.dateComponents([.day], from: hike.effective, to: Date()).day, 30, "effective = first charge at the new price")
        XCTAssertEqual(sub.amount, 17.99, accuracy: 0.001, "the sub carries the new price, not the median")
    }

    func testTinyAmountWobbleIsNotAHike() {
        let txs = [tx("SPOTIFY USA", 11.99, daysAgo: 30), tx("SPOTIFY USA", 12.05, daysAgo: 0)]
        XCTAssertNil(RecurrenceDetector.detect(in: txs).first?.hasPriceHike)
    }

    func testObservedHikeHelper() {
        let now = Date()
        let run: [(amount: Double, date: Date)] = [(9.99, daysAgo(60, from: now)), (12.99, daysAgo(30, from: now)), (12.99, now)]
        let h = RecurrenceDetector.observedHike(sortedAmounts: run)
        XCTAssertEqual(h?.from, 9.99)
        XCTAssertEqual(h?.to, 12.99)
        XCTAssertEqual(h?.effective, daysAgo(30, from: now))
        XCTAssertNil(RecurrenceDetector.observedHike(sortedAmounts: [(12.99, daysAgo(30, from: now)), (9.99, now)]), "a decrease is not a hike")
    }

    func testAppleBilledChargesBecomeOneSubPerAmount() {
        let txs = [
            tx("Apple.com/bill", 2.99, daysAgo: 0), tx("Apple.com/bill", 2.99, daysAgo: 30),
            tx("Apple.com/bill", 12.99, daysAgo: 0), tx("Apple.com/bill", 12.99, daysAgo: 30),
        ]
        let subs = RecurrenceDetector.detect(in: txs)
        XCTAssertEqual(subs.count, 2)
        XCTAssertEqual(Set(subs.map(\.id)), ["apple-services-299c", "apple-services-1299c"])
        XCTAssertTrue(subs.allSatisfy { $0.brandId == "apple-services" && $0.kind == .platformBilled })
        XCTAssertTrue(subs.allSatisfy { $0.name.hasPrefix("Apple (App Store) · $") })
        // Same idea in single-statement mode.
        let likely = RecurrenceDetector.detectLikelyFromSingle([tx("Apple.com/bill", 2.99, daysAgo: 0), tx("Apple.com/bill", 12.99, daysAgo: 0)])
        XCTAssertEqual(likely.count, 2)
    }

    func testBankRecurringLabelPromotesUnknownMerchant() {
        let plain = RecurrenceDetector.detectLikelyFromSingle([tx("Rock Spot Climbing", 62, daysAgo: 0)])
        let hinted = RecurrenceDetector.detectLikelyFromSingle([tx("Rock Spot Climbing", 62, daysAgo: 0, raw: "RECURRING CARD PURCHASE 03/12 ROCK SPOT CLIMBING")])
        XCTAssertTrue(plain.isEmpty)
        XCTAssertEqual(hinted.count, 1)
        XCTAssertTrue(hinted.first?.notes?.contains("recurring") ?? false)
    }

    func testTransactionalMerchantsNeverConfirmEvenWhenPeriodic() {
        let txs = [tx("Starbucks Store 04521", 6.75, daysAgo: 0), tx("Starbucks Store 04521", 6.75, daysAgo: 30)]
        XCTAssertTrue(RecurrenceDetector.detect(in: txs).isEmpty)
    }

    func testDuplicateReadsOfOneChargeDontConfirm() {
        // The same row read twice (two screenshots of the same month) is one charge.
        let txs = [tx("NETFLIX.COM", 15.99, daysAgo: 3), tx("NETFLIX.COM", 15.99, daysAgo: 3)]
        XCTAssertTrue(RecurrenceDetector.detect(in: txs).isEmpty)
    }
}
