import Foundation

/// On-device version of the recurring-charge detector that previously lived in
/// `backend/lib/recurring.js`. Works on `ParsedTransaction` from OCR plus any
/// existing transactions the user has already accumulated.
enum RecurrenceDetector {
    private static let cycleRules: [(min: Int, max: Int, cycle: BillingCycle)] = [
        (6, 9,    .weekly),
        (13, 16,  .weekly), // biweekly counted as weekly for display
        (28, 32,  .monthly),
        (88, 95,  .monthly), // quarterly counted as monthly
        (363, 368, .yearly),
    ]

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    private static func medianInt(_ values: [Int]) -> Int {
        Int(median(values.map(Double.init)))
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: #"\s+(inc|llc|ltd|corp|co)\.?$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func slug(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func brandColor(for key: String) -> String {
        // Deterministic per-merchant color
        var h: UInt32 = 0
        for ch in key.unicodeScalars { h = h &* 31 &+ ch.value }
        let hue = Double(h % 360)
        return hslToHex(hue: hue, sat: 70 + Double(h % 20), light: 45 + Double(h % 10))
    }

    private static func hslToHex(hue: Double, sat: Double, light: Double) -> String {
        let h = hue / 360
        let s = sat / 100
        let l = light / 100
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func conv(_ t: Double) -> Int {
            var x = t
            if x < 0 { x += 1 }
            if x > 1 { x -= 1 }
            if x < 1.0 / 6 { return Int((p + (q - p) * 6 * x) * 255) }
            if x < 0.5     { return Int(q * 255) }
            if x < 2.0 / 3 { return Int((p + (q - p) * (2.0 / 3 - x) * 6) * 255) }
            return Int(p * 255)
        }
        let r = conv(h + 1.0 / 3)
        let g = conv(h)
        let b = conv(h - 1.0 / 3)
        return String(format: "%02X%02X%02X", r, g, b)
    }

    /// Single-screenshot mode: surface charges that LOOK subscription-shaped
    /// (known brand OR common price pattern) even with only 1 occurrence.
    /// Useful when the user uploaded just one statement.
    static func detectLikelyFromSingle(_ txs: [ParsedTransaction]) -> [Subscription] {
        var grouped: [String: ParsedTransaction] = [:]
        for t in txs where t.amount > 0 {
            let key = MerchantNormalizer.brandId(forNormalized: t.merchant)
            if let existing = grouped[key] {
                let existingDate = existing.date ?? .distantPast
                let tDate = t.date ?? .distantPast
                // Newer date wins; same date → smaller amount wins (defends
                // against running-balance rows that slip past the parser dedup)
                if tDate < existingDate { continue }
                if tDate == existingDate && t.amount >= existing.amount { continue }
            }
            grouped[key] = t
        }
        var out: [Subscription] = []
        for (key, t) in grouped {
            guard MerchantNormalizer.looksLikeSubscription(name: t.merchant, amount: t.amount) else { continue }
            let nextBilling = (t.date ?? Date()).addingTimeInterval(30 * 86_400)
            out.append(
                Subscription(
                    id: key,
                    name: t.merchant,
                    vendor: t.merchant,
                    brandHex: brandColor(for: key),
                    category: .other,
                    amount: t.amount,
                    cycle: .monthly,
                    nextBilling: nextBilling,
                    startedAt: t.date ?? Date(),
                    lastUsedAt: nil,
                    sessionsLast30d: 0,
                    userRating: nil,
                    marketAverage: t.amount,
                    trialEndsAt: nil,
                    hasPriceHike: nil,
                    hasOverlapWith: [],
                    notes: "Detected from a single charge — upload next month to confirm."
                )
            )
        }
        return out.sorted { $0.amount > $1.amount }
    }

    /// Detect recurring subscriptions in a list of parsed transactions.
    /// - Parameter txs: All transactions known to the app (current OCR + previous imports).
    /// - Returns: One subscription per detected merchant whose charges look periodic.
    static func detect(in txs: [ParsedTransaction]) -> [Subscription] {
        // Group by brand id (so "POS DEBIT NETFLIX", "SP*NETFLIX", "NETFLIX.COM" all collapse).
        // Skip transactional merchants (Uber/Starbucks/etc.) even if they happen
        // to recur at sub-like intervals.
        var groups: [String: [ParsedTransaction]] = [:]
        for t in txs where t.amount > 0 && t.date != nil {
            guard !MerchantNormalizer.isLikelyTransactional(t.merchant) else { continue }
            let key = MerchantNormalizer.brandId(forNormalized: t.merchant)
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(t)
        }

        var subs: [Subscription] = []
        for (key, items) in groups where items.count >= 2 {
            let sorted = items.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            var gaps: [Int] = []
            for i in 1..<sorted.count {
                guard let a = sorted[i - 1].date, let b = sorted[i].date else { continue }
                gaps.append(Int(b.timeIntervalSince(a) / 86_400))
            }
            guard !gaps.isEmpty else { continue }
            let medGap = medianInt(gaps)
            guard let rule = cycleRules.first(where: { medGap >= $0.min && medGap <= $0.max }) else { continue }

            // Amount stability check
            let amounts = sorted.map(\.amount)
            let medAmt = median(amounts)
            let stable = amounts.filter { abs($0 - medAmt) / medAmt < 0.15 }
            guard stable.count >= 2 else { continue }

            guard let latest = sorted.last?.date, let earliest = sorted.first?.date else { continue }
            let next = latest.addingTimeInterval(TimeInterval(medGap * 86_400))

            // Pick a clean human-readable name from the source merchant text
            let representative = sorted.last?.merchant ?? key
            let id = slug(key)

            subs.append(
                Subscription(
                    id: id,
                    name: representative,
                    vendor: representative,
                    brandHex: brandColor(for: key),
                    category: .other,
                    amount: (medAmt * 100).rounded() / 100,
                    cycle: rule.cycle,
                    nextBilling: next,
                    startedAt: earliest,
                    lastUsedAt: nil,
                    sessionsLast30d: 0,
                    userRating: nil,
                    marketAverage: medAmt,
                    trialEndsAt: nil,
                    hasPriceHike: nil,
                    hasOverlapWith: [],
                    notes: "Detected from \(sorted.count) charges in your screenshots."
                )
            )
        }
        return subs.sorted { $0.amount > $1.amount }
    }
}
