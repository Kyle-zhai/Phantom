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

    init(merchant: String, amount: Double, date: Date?) {
        self.merchant = merchant
        self.amount = amount
        self.date = date
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
        // Crude: try to find candidate date substrings
        let tokens = line.components(separatedBy: CharacterSet(charactersIn: " \t,"))
        for window in 1...3 {
            for i in 0..<tokens.count - window {
                let candidate = tokens[i..<i + window + 1].joined(separator: " ")
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
        let bandTolerance: CGFloat = 0.02 // 2% of image height
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

        // 2. For each row, see if there's a $ amount
        var transactions: [ParsedTransaction] = []
        for row in rows {
            let merged = row.sorted { $0.box.minX < $1.box.minX }
            let combined = merged.map(\.text).joined(separator: " ")
            guard let amount = parseAmount(in: combined), amount > 0.10 else { continue }
            // Merchant is the text up to the amount
            let merchantRaw = combined
                .replacingOccurrences(of: #"-?\$?\s?[0-9,]+\.[0-9]{2}"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Use the full normalizer (handles POS/SP*/AMZN/PAYPAL prefixes + bank junk)
            guard let merchant = MerchantNormalizer.normalize(merchantRaw),
                  !isSummary(merchant) else { continue }
            let date = extractDates(from: combined)
            transactions.append(ParsedTransaction(merchant: merchant, amount: amount, date: date))
        }
        return transactions
    }

    private static let summaryKeywords: Set<String> = [
        "total", "subtotal", "balance", "available", "current", "pending",
        "rewards", "interest", "points", "payment", "amount due",
        "credit limit", "minimum", "statement", "previous balance",
    ]

    private static func isSummary(_ text: String) -> Bool {
        let lower = text.lowercased()
        return summaryKeywords.contains(where: { lower.contains($0) })
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
