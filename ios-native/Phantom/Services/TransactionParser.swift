import Foundation
import CoreGraphics

/// Pulls structured transactions out of OCR-recognized lines.
///
/// Strategy: every screenshot row tends to have a merchant on the left and a $ amount on the right.
/// We look for `$NN.NN` patterns and pair them with the nearest text on the same horizontal line.
/// Dates (when present) are picked up via a few common formats.
struct ParsedTransaction: Identifiable, Hashable {
    let id: String
    let merchant: String
    let amount: Double
    let date: Date?
    /// The unprocessed OCR row text (merchant + amount + dates + junk),
    /// captured so the import screen can show users (and the developer)
    /// exactly what Vision read — invaluable when a charge looks wrong.
    let rawRow: String

    init(merchant: String, amount: Double, date: Date?, rawRow: String = "") {
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.rawRow = rawRow
        self.id = "\(merchant.lowercased())-\(amount)-\(date?.timeIntervalSince1970 ?? 0)"
    }
}

enum TransactionParser {
    private static let amountRegex = try! NSRegularExpression(
        pattern: #"-?\$?\s?([0-9]{1,5}(?:,[0-9]{3})*(?:\.[0-9]{2}))"#,
        options: []
    )

    private static let dateFormats: [String] = [
        "MMM d, yyyy",
        "MMM d",
        "M/d/yyyy",
        "M/d/yy",
        "yyyy-MM-dd",
        "MMM dd yyyy",
        "MMMM d, yyyy",
    ]

    private static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in dateFormats {
            f.dateFormat = format
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    private static func parseAmount(in line: String) -> Double? {
        let range = NSRange(line.startIndex..., in: line)
        guard let m = amountRegex.firstMatch(in: line, options: [], range: range),
              let r = Range(m.range(at: 1), in: line) else { return nil }
        let cleaned = String(line[r]).replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    private static func extractDates(from line: String) -> Date? {
        // Scan sliding token windows for a parseable date.
        //
        // Critical: try LARGEST windows first so "Apr 28 2026" (window 3,
        // includes the year) gets recognized before "Apr 28" (window 2,
        // "MMM d" format defaults to year 2000). Previously the parser
        // returned year-2000 dates for every screenshot.
        let tokens = line
            .components(separatedBy: CharacterSet(charactersIn: " \t,"))
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        for window in stride(from: 3, through: 1, by: -1) {
            guard tokens.count >= window else { continue }
            let lastStart = tokens.count - window
            for i in 0...lastStart {
                let candidate = tokens[i..<(i + window)].joined(separator: " ")
                if let d = parseDate(candidate) { return d }
            }
        }
        return nil
    }

    /// Group OCR lines into rows by Y-coordinate proximity, then extract transactions per row.
    static func parse(lines: [OCR.Line]) -> [ParsedTransaction] {
        guard !lines.isEmpty else { return [] }

        // 1. Cluster lines by horizontal band (rows in the original image)
        let sorted = lines.sorted { $0.box.midY > $1.box.midY }
        // 1.2% of image height — tight enough to keep BoA's "merchant + amount"
        // and "running balance" on separate rows, loose enough that a wrapped
        // merchant + its right-aligned amount still cluster together.
        let bandTolerance: CGFloat = 0.012
        var rows: [[OCR.Line]] = []
        var currentRow: [OCR.Line] = []
        var currentY: CGFloat = sorted.first?.box.midY ?? 0
        for line in sorted {
            if abs(line.box.midY - currentY) < bandTolerance {
                currentRow.append(line)
            } else {
                if !currentRow.isEmpty { rows.append(currentRow) }
                currentRow = [line]
                currentY = line.box.midY
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        // 2. Classify each row, then pair stacked "date row + merchant row"
        //    transactions before generating ParsedTransactions.
        //
        //    Citi and some Discover statements use a two-row layout per charge:
        //      Row A: "May 8, 2026                 $18.86"      ← txn amount
        //      Row B: "UBER *EATS HELP.UBER.COMCA  $1,343.61"   ← running balance
        //    The amount on row A is the real transaction; the amount on row B
        //    is the running balance. The merchant name lives on row B.
        //    We pair them: take amount + date from A, merchant from B.
        let kinds: [RowKind] = rows.map(classify)

        var transactions: [ParsedTransaction] = []
        var i = 0
        while i < kinds.count {
            switch kinds[i] {
            case .ignored:
                i += 1
            case let .dateOnlyWithAmount(amount, date, raw):
                // Look ahead for the next merchant row to pair with
                if i + 1 < kinds.count,
                   case let .merchantWithAmount(merchant, _, mDate, mRaw) = kinds[i + 1] {
                    transactions.append(ParsedTransaction(
                        merchant: merchant,
                        amount: amount,
                        date: date ?? mDate,
                        rawRow: "\(raw) | \(mRaw)"
                    ))
                    i += 2
                } else {
                    // Orphan date row — no merchant to attach to. Drop it
                    // (otherwise the date string itself ends up as the merchant).
                    i += 1
                }
            case let .merchantWithAmount(merchant, amount, date, raw):
                transactions.append(ParsedTransaction(
                    merchant: merchant, amount: amount, date: date, rawRow: raw
                ))
                i += 1
            }
        }

        // 3. Per-merchant dedup: when the same merchant has multiple amounts
        //    in this batch (different Y-clustering races, OCR duplicates, etc.),
        //    the SMALLEST is the real transaction price.
        return collapseByMerchantPreferSmaller(transactions)
    }

    private enum RowKind {
        case ignored
        /// Row content is just a date string + a $ amount. Citi-style charges.
        case dateOnlyWithAmount(amount: Double, date: Date?, raw: String)
        /// Row has a real merchant name + a $ amount.
        case merchantWithAmount(merchant: String, amount: Double, date: Date?, raw: String)
    }

    private static func classify(_ row: [OCR.Line]) -> RowKind {
        let merged = row.sorted { $0.box.minX < $1.box.minX }
        let combined = merged.map(\.text).joined(separator: " ")
        guard let amount = parseAmount(in: combined), amount > 0.10 else { return .ignored }

        let merchantRaw = combined
            .replacingOccurrences(of: #"-?\$?\s?[0-9,]+\.[0-9]{2}"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if isDateOnlyText(merchantRaw) {
            return .dateOnlyWithAmount(amount: amount, date: extractDates(from: combined), raw: combined)
        }

        guard let merchant = MerchantNormalizer.normalize(merchantRaw),
              !isSummary(merchant),
              isPlausibleMerchant(merchant) else { return .ignored }

        return .merchantWithAmount(
            merchant: merchant,
            amount: amount,
            date: extractDates(from: combined),
            raw: combined
        )
    }

    /// Returns true when `text` is JUST a date (no merchant content).
    /// Catches both numeric ("12/15", "12-15-2024") and month-name forms
    /// ("May 8, 2026", "Apr 30", "May 4,").
    private static func isDateOnlyText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Numeric date: 12/15, 1/2, 12-15-2024
        if trimmed.range(of: #"^\d{1,2}[/-]\d{1,2}([/-]\d{2,4})?$"#,
                         options: .regularExpression) != nil { return true }
        // Month-name date: "May 8, 2026", "May 4,", "Apr 30 2026"
        let pattern = #"^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}[\s,]*\d{0,4}\s*$"#
        if trimmed.lowercased().range(of: pattern, options: .regularExpression) != nil { return true }
        return false
    }

    /// Per-merchant collapse: keep only the smallest amount per (merchant + date).
    /// Running-balance / daily-total rows are always larger than the individual
    /// transaction, so the smallest is the safe choice.
    private static func collapseByMerchantPreferSmaller(_ txs: [ParsedTransaction]) -> [ParsedTransaction] {
        var bestByKey: [String: ParsedTransaction] = [:]
        for t in txs {
            let key = "\(t.merchant.lowercased())|\(dateKey(t.date))"
            if let existing = bestByKey[key] {
                if t.amount < existing.amount {
                    bestByKey[key] = t
                }
            } else {
                bestByKey[key] = t
            }
        }
        return Array(bestByKey.values)
    }

    private static func dateKey(_ d: Date?) -> String {
        guard let d else { return "nil" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private static let summaryKeywords: Set<String> = [
        "total", "subtotal", "balance", "available", "current", "pending",
        "rewards", "interest", "points", "payment", "amount due",
        "credit limit", "minimum", "statement", "previous balance",
        // BoA / Chase / Wells specific
        "running total", "running balance", "daily total", "daily balance",
        "month-to-date", "month to date", "year-to-date", "year to date",
        "ytd", "mtd", "ending balance", "beginning balance",
        "purchases", "fees charged", "interest charged",
        "new balance", "this period",
    ]

    private static func isSummary(_ text: String) -> Bool {
        let lower = text.lowercased()
        return summaryKeywords.contains(where: { lower.contains($0) })
    }

    /// True when the merchant string looks like an actual store/service name —
    /// at least 3 letters and not just a date / state code / single token.
    /// Filters out OCR'd row fragments like "12/15", "CA", "WA 98101".
    private static func isPlausibleMerchant(_ name: String) -> Bool {
        let letters = name.filter { $0.isLetter }
        if letters.count < 3 { return false }
        // Reject if the whole string is a date pattern
        if name.range(of: #"^\s*\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\s*$"#,
                      options: .regularExpression) != nil { return false }
        return true
    }

    private static func cleanMerchant(_ raw: String) -> String {
        var s = raw
        // Drop common bank/transaction noise
        let noise = [
            "PURCHASE", "DEBIT", "CREDIT", "POS", "AUTH", "PENDING", "RECURRING",
            "TST*", "SQ*", "PAYPAL *", "AMZN MKTP", "AMAZON.COM*",
            #"\s+\d{2}/\d{2}\s*"#, // dates
            #"\s+\d{4}\s*$"#, // trailing card last-4
            #"\s+CA\s+"#, "\\s+US\\s*$", // state codes
            "*", // generic separator some apps use
        ]
        for n in noise {
            s = s.replacingOccurrences(of: n, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Title-case it (NETFLIX.COM → Netflix.Com → Netflix)
        return titleCase(s)
    }

    private static func titleCase(_ s: String) -> String {
        s.lowercased()
            .split(separator: " ")
            .map { word -> String in
                guard let first = word.first else { return "" }
                return String(first).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
            .replacingOccurrences(of: ".Com", with: "")
            .replacingOccurrences(of: ".com", with: "")
    }
}
