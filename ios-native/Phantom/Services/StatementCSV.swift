import Foundation

/// Turns a bank / card CSV export into the same `ParsedTransaction` rows the
/// screenshot OCR path produces, so recurrence detection is shared.
///
/// Handles the common US exports (Chase, Bank of America, Citi, Apple Card,
/// Amex, Capital One) plus a headerless `date,description,amount` fallback.
/// Purchases become positive amounts; credits / payments / payments-to-card
/// are dropped so they never look like subscriptions.
enum StatementCSV {
    static func parse(_ data: Data) -> [ParsedTransaction] {
        guard let text = decode(data) else { return [] }
        return parse(text: text)
    }

    static func parse(text raw: String) -> [ParsedTransaction] {
        let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        let delimiter = detectDelimiter(lines.prefix(5).joined(separator: "\n"))
        let rows = lines.map { splitCSV($0, delimiter: delimiter) }
        guard let first = rows.first else { return [] }

        let headerIdx = headerMap(first)
        let body: [[String]]
        if headerIdx != nil {
            body = Array(rows.dropFirst())
        } else {
            body = rows
        }

        let parsed = body.compactMap { rowValues(from: $0, header: headerIdx) }
        let negativeCount = parsed.filter { $0.signedAmount < 0 }.count
        let positiveCount = parsed.filter { $0.signedAmount > 0 }.count
        // Bank/card CSVs usually sign purchases negative. Apple Card (and a
        // debit-column export) signs them positive. Pick the dominant sign so
        // a $200 card payment doesn't become a fake subscription.
        let purchasesAreNegative = negativeCount >= positiveCount && negativeCount > 0

        var txs: [ParsedTransaction] = []
        for row in parsed {
            let charge: Double
            if purchasesAreNegative {
                guard row.signedAmount < 0 else { continue }
                charge = abs(row.signedAmount)
            } else {
                guard row.signedAmount > 0 else { continue }
                charge = row.signedAmount
            }
            guard charge > 0, !row.merchant.isEmpty else { continue }
            txs.append(ParsedTransaction(
                merchant: row.merchant, amount: charge, date: row.date, rawRow: row.raw
            ))
        }
        return txs
    }

    // MARK: - Row → transaction

    private struct Header {
        var date: Int
        var merchant: Int
        var amount: Int?
        var debit: Int?
        var credit: Int?
        var type: Int?
    }

    private struct RowValues {
        var merchant: String
        var signedAmount: Double
        var date: Date?
        var raw: String
    }

    private static func rowValues(from cols: [String], header: Header?) -> RowValues? {
        let dateStr: String
        let merchant: String
        let amount: Double
        let raw = cols.joined(separator: ",")

        if let h = header {
            dateStr = col(cols, h.date)
            merchant = col(cols, h.merchant)
            if let debitI = h.debit, let creditI = h.credit {
                let debit = parseAmount(col(cols, debitI)) ?? 0
                let credit = parseAmount(col(cols, creditI)) ?? 0
                // Separate debit/credit columns: only debit rows are purchases.
                guard debit > 0, credit == 0 else { return nil }
                amount = debit
            } else if let amtI = h.amount {
                amount = parseAmount(col(cols, amtI)) ?? 0
            } else {
                return nil
            }
            if let typeI = h.type {
                let t = col(cols, typeI).lowercased()
                if t.contains("payment") || t.contains("credit") || t.contains("refund")
                    || t.contains("deposit") || t.contains("interest") || t.contains("transfer") {
                    return nil
                }
            }
        } else {
            guard cols.count >= 3 else { return nil }
            let dateI = cols.firstIndex(where: { parseDate($0) != nil }) ?? 0
            let amountI = cols.lastIndex(where: { parseAmount($0) != nil }) ?? (cols.count - 1)
            dateStr = cols[dateI]
            amount = parseAmount(cols[amountI]) ?? 0
            merchant = cols.enumerated()
                .filter { $0.offset != dateI && $0.offset != amountI }
                .map { $0.element }
                .joined(separator: " ")
        }

        let cleaned = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, amount != 0 else { return nil }
        return RowValues(merchant: cleaned, signedAmount: amount, date: parseDate(dateStr), raw: raw)
    }

    private static func col(_ cols: [String], _ i: Int) -> String {
        guard i >= 0, i < cols.count else { return "" }
        return cols[i].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    }

    private static func headerMap(_ row: [String]) -> Header? {
        let lower = row.map { $0.lowercased().replacingOccurrences(of: "\"", with: "") }
        func first(_ keys: [String]) -> Int? {
            lower.firstIndex { cell in keys.contains(where: { cell.contains($0) }) }
        }
        let date = first(["transaction date", "trans date", "posted date", "post date",
                          "clearing date", "cleared date", "date"])
        let merchant = first(["description", "payee", "merchant", "name", "memo"])
        let amount = first(["amount (usd)", "amount($)", "amount"])
        let debit = first(["debit"])
        let credit = first(["credit"])
        let type = first(["type", "transaction type", "status"])
        guard let date, let merchant else { return nil }
        if amount == nil && debit == nil { return nil }
        return Header(date: date, merchant: merchant, amount: amount, debit: debit, credit: credit, type: type)
    }

    // MARK: - Amount / date

    private static func parseAmount(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let negative = s.contains("(") && s.contains(")") || s.hasPrefix("-")
        s = s.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: " ", with: "")
        if s.hasPrefix("−") || s.hasPrefix("–") { s.removeFirst() }
        guard let v = Double(s), v.isFinite else { return nil }
        return negative ? -abs(v) : v
    }

    private static let dateFormats: [String] = [
        "yyyy-MM-dd",
        "M/d/yyyy",
        "MM/dd/yyyy",
        "M/d/yy",
        "MM/dd/yy",
        "MMM d, yyyy",
        "MMMM d, yyyy",
        "d MMM yyyy",
        "yyyy/MM/dd",
    ]

    private static let dateParsers: [DateFormatter] = dateFormats.map { fmt in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = fmt
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }

    private static func parseDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for f in dateParsers {
            if let d = f.date(from: trimmed) { return d }
        }
        return nil
    }

    // MARK: - CSV guts

    private static func detectDelimiter(_ sample: String) -> Character {
        let counts: [(Character, Int)] = [",", ";", "\t"].map { d in
            (d, sample.filter { $0 == d }.count)
        }
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? ","
    }

    /// RFC 4180-ish split: quoted fields may contain the delimiter and newlines
    /// are already stripped per-line by the caller.
    static func splitCSV(_ line: String, delimiter: Character = ",") -> [String] {
        var out: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 2
                    continue
                }
                inQuotes.toggle()
                i += 1
                continue
            }
            if c == delimiter && !inQuotes {
                out.append(current)
                current = ""
                i += 1
                continue
            }
            current.append(c)
            i += 1
        }
        out.append(current)
        return out
    }

    private static func decode(_ data: Data) -> String? {
        if data.count >= 3, data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16LittleEndian) { return s }
        if let s = String(data: data, encoding: .utf16BigEndian) { return s }
        return String(data: data, encoding: .isoLatin1)
    }

    #if DEBUG
    /// Tiny Chase-style fixture so `--demo-csv` can drive the review step in Simulator.
    static let debugChaseCSV = """
    Transaction Date,Post Date,Description,Category,Type,Amount
    08/01/2026,08/02/2026,NETFLIX.COM,Entertainment,Sale,-15.99
    07/01/2026,07/02/2026,NETFLIX.COM,Entertainment,Sale,-15.99
    06/01/2026,06/02/2026,NETFLIX.COM,Entertainment,Sale,-15.99
    08/04/2026,08/05/2026,SPOTIFY USA,Entertainment,Sale,-11.99
    07/04/2026,07/05/2026,SPOTIFY USA,Entertainment,Sale,-11.99
    08/08/2026,08/09/2026,Payment Thank You-Mobile,Payment,Payment,200.00
    08/12/2026,08/13/2026,UBER   *TRIP,Travel,Sale,-24.10
    """
    #endif
}
