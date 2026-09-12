import Foundation

/// On-device ledger of every charge the user has imported (screenshot, CSV,
/// share-sheet). Lives in Application Support as a small JSON file; nothing
/// leaves the phone. It is what makes cross-month recurrence confirmation and
/// on-statement price-hike detection possible — without it every import was
/// scored in isolation and "upload next month to confirm" could never happen.
enum TransactionLedger {
    struct Entry: Codable, Hashable {
        let merchant: String
        let amount: Double
        let date: Date?
        let recurringHint: Bool
        let rawRow: String
        let importedAt: Date

        var dedupeKey: String {
            let cents = Int((amount * 100).rounded())
            let day = date.map { Int($0.timeIntervalSince1970 / 86_400) } ?? -1
            return "\(merchant.lowercased())|\(cents)|\(day)"
        }

        func toTransaction() -> ParsedTransaction {
            ParsedTransaction(merchant: merchant, amount: amount, date: date, rawRow: rawRow, recurringHint: recurringHint)
        }
    }

    /// Charges older than this are dropped — two years is enough to confirm a
    /// yearly renewal twice.
    static let maxAgeDays = 730
    static let maxEntries = 6_000

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Phantom", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("transactions.json")
    }

    static func load() -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Entry].self, from: data)) ?? []
    }

    private static func save(_ entries: [Entry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    /// Pure merge used by `record` and by tests: dedupes on merchant+amount+day,
    /// prunes entries older than `maxAgeDays`, caps the total, newest first.
    static func merged(existing: [Entry], incoming: [ParsedTransaction], now: Date = Date()) -> [Entry] {
        var byKey: [String: Entry] = [:]
        for e in existing { byKey[e.dedupeKey] = e }
        for t in incoming where t.amount > 0 {
            let e = Entry(merchant: t.merchant, amount: t.amount, date: t.date,
                          recurringHint: t.recurringHint, rawRow: t.rawRow, importedAt: now)
            if byKey[e.dedupeKey] == nil { byKey[e.dedupeKey] = e }
        }
        let cutoff = now.addingTimeInterval(-Double(maxAgeDays) * 86_400)
        let kept = byKey.values.filter { ($0.date ?? $0.importedAt) >= cutoff }
        let sorted = kept.sorted { ($0.date ?? $0.importedAt) > ($1.date ?? $1.importedAt) }
        return Array(sorted.prefix(maxEntries))
    }

    /// Append an import to the ledger and return the full transaction history.
    @discardableResult
    static func record(_ txs: [ParsedTransaction], now: Date = Date()) -> [ParsedTransaction] {
        let all = merged(existing: load(), incoming: txs, now: now)
        save(all)
        return all.map { $0.toTransaction() }
    }

    static func transactions() -> [ParsedTransaction] {
        load().map { $0.toTransaction() }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
