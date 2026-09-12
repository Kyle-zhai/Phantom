import Foundation

/// On-device recurring-charge detector. Works on `ParsedTransaction` from OCR /
/// CSV plus the on-device `TransactionLedger` of everything imported before, so
/// a charge seen in two different months is confirmed as recurring.
enum RecurrenceDetector {
    /// Candidate billing periods. A gap between two charges matches a rule when
    /// it is close to the period or a small multiple of it (a missed / skipped
    /// month still reads as monthly). Shortest period first.
    struct CycleRule {
        let cycle: BillingCycle
        let period: Double
        let tolerance: Double
    }

    static let cycleRules: [CycleRule] = [
        CycleRule(cycle: .weekly,    period: 7,      tolerance: 2),
        CycleRule(cycle: .biweekly,  period: 14,     tolerance: 3),
        CycleRule(cycle: .monthly,   period: 30.44,  tolerance: 5),
        CycleRule(cycle: .quarterly, period: 91.3,   tolerance: 8),
        CycleRule(cycle: .yearly,    period: 365.25, tolerance: 12),
    ]

    /// Infer the billing cycle from the day-gaps between consecutive charges.
    /// Picks the rule matching the most gaps (allowing 1×–3× multiples for a
    /// missed charge), tie-breaking toward the rule with more exact (1×) hits.
    /// Returns nil when fewer than half the gaps fit any rule.
    static func inferCycle(gaps: [Int]) -> BillingCycle? {
        guard !gaps.isEmpty else { return nil }
        var best: (rule: CycleRule, matched: Int, exact: Int)? = nil
        for rule in cycleRules {
            var matched = 0
            var exact = 0
            for gap in gaps {
                let g = Double(gap)
                var hit = false
                for k in 1...3 where abs(g - Double(k) * rule.period) <= rule.tolerance * Double(k) {
                    hit = true
                    if k == 1 { exact += 1 }
                    break
                }
                if hit { matched += 1 }
            }
            guard matched > 0 else { continue }
            if let b = best {
                if matched > b.matched || (matched == b.matched && exact > b.exact) {
                    best = (rule, matched, exact)
                }
            } else {
                best = (rule, matched, exact)
            }
        }
        guard let b = best, b.matched * 2 >= gaps.count else { return nil }
        return b.rule.cycle
    }

    static func period(for cycle: BillingCycle) -> Double {
        cycleRules.first { $0.cycle == cycle }?.period ?? 30.44
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    static func slug(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Grouping key for a transaction. Normally the brand id; for multi-charge
    /// billers (Apple / Google Play) the amount is part of the key so each
    /// distinct product becomes its own subscription line.
    static func groupKey(for tx: ParsedTransaction) -> String {
        let brand = MerchantNormalizer.brandId(forNormalized: tx.merchant)
        guard MerchantNormalizer.isMultiChargeBiller(brand) else { return brand }
        let cents = Int((tx.amount * 100).rounded())
        return "\(brand)-\(cents)c"
    }

    private static func displayName(brandId: String, key: String, fallback: String, amount: Double) -> String {
        let base = BrandRegistry.displayName(for: brandId) ?? fallback
        guard MerchantNormalizer.isMultiChargeBiller(brandId) else { return base }
        return base + " · " + String(format: "$%.2f", amount)
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

    /// A price change observed on the statement itself: the newest charge is
    /// at least 5% (and 50¢) above the amount charged before it.
    struct ObservedHike: Equatable {
        let from: Double
        let to: Double
        let effective: Date
    }

    /// Detect a hike from a date-sorted run of charges (oldest first).
    static func observedHike(sortedAmounts: [(amount: Double, date: Date)]) -> ObservedHike? {
        guard let latest = sortedAmounts.last else { return nil }
        // Walk back over the run of charges at the current amount to find when
        // it started, then look at the amount charged right before that run.
        var firstAtCurrent = latest
        var i = sortedAmounts.count - 1
        while i > 0, abs(sortedAmounts[i - 1].amount - latest.amount) < 0.01 {
            i -= 1
            firstAtCurrent = sortedAmounts[i]
        }
        guard i > 0 else { return nil }
        let previous = sortedAmounts[i - 1].amount
        guard previous > 0, latest.amount > previous + 0.5, (latest.amount - previous) / previous >= 0.05 else { return nil }
        return ObservedHike(from: (previous * 100).rounded() / 100,
                            to: (latest.amount * 100).rounded() / 100,
                            effective: firstAtCurrent.date)
    }

    /// Single-screenshot mode: surface charges that LOOK subscription-shaped
    /// (known brand, bank "recurring" label, or common price pattern) even with
    /// only 1 occurrence. Useful when the user uploaded just one statement.
    static func detectLikelyFromSingle(_ txs: [ParsedTransaction]) -> [Subscription] {
        var grouped: [String: ParsedTransaction] = [:]
        for t in txs where t.amount > 0 {
            let key = groupKey(for: t)
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
            guard MerchantNormalizer.looksLikeSubscription(name: t.merchant, amount: t.amount, recurringHint: t.recurringHint) else { continue }
            let brandId = MerchantNormalizer.brandId(forNormalized: t.merchant)
            let nextBilling = (t.date ?? Date()).addingTimeInterval(30 * 86_400)
            let brandHex = BrandRegistry.brand(for: brandId, fallbackName: t.merchant)?.hex
                ?? brandColor(for: key)
            // Prefer the curated brand display name ("Netflix", "Apple Music",
            // "Amazon Prime") over the raw bank-statement text. Keep the raw
            // text in rawDescriptor so the detail view can show "On your
            // statement: APL*APPLE MUSIC" for verification.
            out.append(
                Subscription(
                    id: slug(key),
                    name: displayName(brandId: brandId, key: key, fallback: t.merchant, amount: t.amount),
                    vendor: t.merchant,
                    rawDescriptor: t.merchant,
                    brandHex: brandHex,
                    category: BrandRegistry.category(for: brandId),
                    amount: t.amount,
                    cycle: .monthly,
                    nextBilling: nextBilling,
                    startedAt: t.date ?? Date(),
                    lastUsedAt: nil,
                    sessionsLast30d: 0,
                    userRating: nil,
                    marketAverage: 0,   // filled from the catalog by the store
                    trialEndsAt: nil,
                    hasPriceHike: nil,
                    hasOverlapWith: [],
                    notes: t.recurringHint
                        ? "Your bank labelled this charge as recurring. Upload next month's statement to confirm the cycle."
                        : "Detected from a single charge — upload next month to confirm."
                )
            )
        }
        return out.sorted { $0.amount > $1.amount }
    }

    /// Detect recurring subscriptions in a list of parsed transactions.
    /// - Parameter txs: All transactions known to the app (current OCR + the ledger of previous imports).
    /// - Returns: One subscription per detected merchant whose charges look periodic.
    static func detect(in txs: [ParsedTransaction]) -> [Subscription] {
        // Group by brand id (so "POS DEBIT NETFLIX", "SP*NETFLIX", "NETFLIX.COM" all collapse).
        // Skip transactional merchants (Uber/Starbucks/etc.) even if they happen
        // to recur at sub-like intervals.
        var groups: [String: [ParsedTransaction]] = [:]
        for t in txs where t.amount > 0 && t.date != nil {
            guard !MerchantNormalizer.isLikelyTransactional(t.merchant) else { continue }
            let key = groupKey(for: t)
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(t)
        }

        var subs: [Subscription] = []
        for (key, items) in groups where items.count >= 2 {
            // Same merchant, same day, same amount = the same charge read twice.
            var seen = Set<String>()
            let unique = items.filter { t in
                let cents = Int((t.amount * 100).rounded())
                let day = Int((t.date ?? .distantPast).timeIntervalSince1970 / 86_400)
                return seen.insert("\(cents)|\(day)").inserted
            }
            guard unique.count >= 2 else { continue }
            let sorted = unique.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            var gaps: [Int] = []
            for i in 1..<sorted.count {
                guard let a = sorted[i - 1].date, let b = sorted[i].date else { continue }
                gaps.append(Int(b.timeIntervalSince(a) / 86_400))
            }
            guard !gaps.isEmpty, let cycle = inferCycle(gaps: gaps) else { continue }

            let run = sorted.compactMap { t -> (amount: Double, date: Date)? in
                guard let d = t.date else { return nil }
                return (t.amount, d)
            }
            let hike = observedHike(sortedAmounts: run)
            let current = sorted.last!.amount
            // Amount stability: charges must sit near the current price, or —
            // when a hike was observed — near the pre-hike price.
            let stable = sorted.filter { t in
                let nearCurrent = abs(t.amount - current) / current < 0.15
                let nearPrevious = hike.map { abs(t.amount - $0.from) / $0.from < 0.15 } ?? false
                return nearCurrent || nearPrevious
            }
            guard stable.count >= 2 else { continue }

            guard let latest = sorted.last?.date, let earliest = sorted.first?.date else { continue }
            let next = latest.addingTimeInterval(period(for: cycle) * 86_400)
            let amount = hike != nil
                ? current
                : median(stable.map(\.amount))

            let brandId = MerchantNormalizer.brandId(forNormalized: sorted.last!.merchant)
            let representative = sorted.last?.merchant ?? key
            let brandHex = BrandRegistry.brand(for: brandId, fallbackName: representative)?.hex
                ?? brandColor(for: key)
            var note = "Detected from \(sorted.count) charges in your statements (\(cycle.label.lowercased()))."
            if let hike {
                note += " Price went from \(String(format: "$%.2f", hike.from)) to \(String(format: "$%.2f", hike.to))."
            }

            subs.append(
                Subscription(
                    id: slug(key),
                    name: displayName(brandId: brandId, key: key, fallback: representative, amount: amount),
                    vendor: representative,
                    rawDescriptor: representative,
                    brandHex: brandHex,
                    category: BrandRegistry.category(for: brandId),
                    amount: (amount * 100).rounded() / 100,
                    cycle: cycle,
                    nextBilling: next,
                    startedAt: earliest,
                    lastUsedAt: nil,
                    sessionsLast30d: 0,
                    userRating: nil,
                    marketAverage: 0,  // filled from the catalog by the store
                    trialEndsAt: nil,
                    hasPriceHike: hike.map { PriceHike(from: $0.from, to: $0.to, effective: $0.effective) },
                    hasOverlapWith: [],
                    notes: note
                )
            )
        }
        return subs.sorted { $0.amount > $1.amount }
    }
}
