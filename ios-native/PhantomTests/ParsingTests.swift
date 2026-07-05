import XCTest
import CoreGraphics
@testable import Phantom

/// Guards the parser fixes (#5 bare MM/DD dates, #7 credits-as-charges) and the
/// category-inference that powers overlap.
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
}

/// Guards cross-charge recurrence confirmation (feeds the confirmed vs likely
/// distinction the import UI promises) and category on detected subs.
final class RecurrenceDetectorTests: XCTestCase {

    private func tx(_ merchant: String, _ amount: Double, daysAgo: Int) -> ParsedTransaction {
        ParsedTransaction(
            merchant: merchant, amount: amount,
            date: Date().addingTimeInterval(TimeInterval(-daysAgo * 86_400))
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
    }

    func testSingleChargeIsLikelyNotConfirmed() {
        let confirmed = RecurrenceDetector.detect(in: [tx("NETFLIX.COM", 15.99, daysAgo: 0)])
        XCTAssertTrue(confirmed.isEmpty, "one charge can't confirm recurrence")
        let likely = RecurrenceDetector.detectLikelyFromSingle([tx("NETFLIX.COM", 15.99, daysAgo: 0)])
        XCTAssertEqual(likely.count, 1)
    }
}
