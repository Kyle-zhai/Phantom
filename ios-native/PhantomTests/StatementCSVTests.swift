import XCTest
@testable import Phantom

final class StatementCSVTests: XCTestCase {

    func testChasePurchasesKeepAndPaymentsDrop() {
        let txs = StatementCSV.parse(text: """
        Transaction Date,Post Date,Description,Category,Type,Amount
        08/01/2026,08/02/2026,NETFLIX.COM,Entertainment,Sale,-15.99
        07/01/2026,07/02/2026,NETFLIX.COM,Entertainment,Sale,-15.99
        08/08/2026,08/09/2026,Payment Thank You-Mobile,Payment,Payment,200.00
        08/12/2026,08/13/2026,UBER   *TRIP,Travel,Sale,-24.10
        """)
        XCTAssertEqual(txs.count, 3)
        XCTAssertTrue(txs.contains { $0.merchant.contains("NETFLIX") && $0.amount == 15.99 })
        XCTAssertFalse(txs.contains { $0.amount == 200 })
        XCTAssertTrue(txs.contains { $0.merchant.contains("UBER") })
    }

    func testAppleCardPositivePurchases() {
        let txs = StatementCSV.parse(text: """
        Transaction Date,Clearing Date,Description,Merchant,Category,Type,Amount (USD)
        08/01/2026,08/02/2026,NETFLIX,Netflix,Entertainment,Purchase,15.99
        08/04/2026,08/05/2026,SPOTIFY,Spotify,Entertainment,Purchase,11.99
        """)
        XCTAssertEqual(txs.count, 2)
        XCTAssertEqual(txs.map(\.amount).sorted(), [11.99, 15.99])
    }

    func testCitiDebitCreditColumns() {
        let txs = StatementCSV.parse(text: """
        Status,Date,Description,Debit,Credit
        Cleared,08/01/2026,HULU,17.99,
        Cleared,08/03/2026,AUTOPAY PAYMENT,,250.00
        """)
        XCTAssertEqual(txs.count, 1)
        XCTAssertEqual(txs.first?.merchant, "HULU")
        XCTAssertEqual(txs.first?.amount ?? 0, 17.99, accuracy: 0.001)
    }

    func testQuotedMerchantWithComma() {
        let cols = StatementCSV.splitCSV("08/01/2026,\"NETFLIX, INC\",-15.99")
        XCTAssertEqual(cols.count, 3)
        XCTAssertEqual(cols[1], "NETFLIX, INC")
    }

    func testHeaderlessFallback() {
        let txs = StatementCSV.parse(text: """
        08/01/2026,SPOTIFY USA,-11.99
        07/01/2026,SPOTIFY USA,-11.99
        """)
        XCTAssertEqual(txs.count, 2)
        XCTAssertTrue(txs.allSatisfy { $0.merchant.contains("SPOTIFY") })
    }
}

final class ChargebackPacketTests: XCTestCase {
    func testScriptCitesRegulationEAndMerchant() {
        let script = ChargebackPacket.script(for: ChargebackPacket.Context(
            merchant: "Peacock",
            amount: 13.99,
            chargeDate: "August 1, 2026",
            reason: .cancelledStillCharged,
            confirmationNumber: "CXL-9",
            letterSentAt: Date(),
            fullName: "Jordan Lee"
        ))
        XCTAssertTrue(script.contains("Regulation E"))
        XCTAssertTrue(script.contains("Peacock"))
        XCTAssertTrue(script.contains("CXL-9"))
        XCTAssertTrue(script.contains("13.99") || script.contains("$14"))
    }
}
