import Foundation
import CoreGraphics

/// Reads a screenshot of iOS Settings › [Apple Account] › Subscriptions (or the
/// App Store's Subscriptions page). Apple offers no API for a third-party app
/// to enumerate the user's subscriptions to other apps — StoreKit only exposes
/// the calling app's own products — so this screenshot is the closest thing to
/// a direct feed, and it is the only source that can NAME an APPLE.COM/BILL
/// charge. Everything stays on-device.
///
/// Rows on that screen stack vertically (name / plan / "$8.99/month" /
/// "Renews Oct 12, 2026"), so the bank-statement row clustering doesn't apply;
/// this walks the lines top-to-bottom and assembles records instead.
enum AppleSubscriptionsParser {
    struct Record: Equatable {
        var name: String = ""
        var plan: String? = nil
        var amount: Double = 0
        var cycle: BillingCycle = .monthly
        var renews: Date? = nil
        var trialEndsAt: Date? = nil
        var active: Bool = true

        var isComplete: Bool { !name.isEmpty && amount > 0 }
    }

    // "$8.99/month", "$8.99 / month", "$99.99 per year", "$29.99/6 months", "$2.99 a week"
    private static let pricePeriodRegex = try! NSRegularExpression(
        pattern: #"(?i)\$\s?([0-9]{1,4}(?:,[0-9]{3})*(?:\.[0-9]{2})?)\s*(?:/|per|every|a|each)\s*(1\s+)?(6\s*months?|3\s*months?|2\s*months?|month|mo\b|year|yr\b|week|wk\b|quarter)"#
    )
    private static let renewRegex = try! NSRegularExpression(
        pattern: #"(?i)\b(renews?|renewing|next billing|next payment|next charge|expires?|expired|expiring|ends?|ended|until)\b"#
    )
    private static let trialRegex = try! NSRegularExpression(pattern: #"(?i)\b(free trial|trial)\b"#)
    private static let inactiveRegex = try! NSRegularExpression(pattern: #"(?i)\b(expired|ended|cancelled|canceled)\b"#)

    /// Lines that are chrome, not data.
    private static let sectionWords: Set<String> = [
        "subscriptions", "subscription", "active", "inactive", "expired", "manage", "done", "edit",
        "renewal receipts", "family sharing", "shared with family", "your subscriptions",
        "apple account", "apple id", "media & purchases", "see all", "cancel subscription",
        "options", "purchase history", "manage subscriptions", "back",
    ]

    static func looksLikeAppleList(_ lines: [OCR.Line]) -> Bool {
        var priceHits = 0
        var renewHits = 0
        var header = false
        for line in lines {
            let t = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if matches(pricePeriodRegex, t) { priceHits += 1 }
            if matches(renewRegex, t) { renewHits += 1 }
            if t.lowercased() == "subscriptions" { header = true }
        }
        return priceHits >= 2 || (priceHits >= 1 && (renewHits >= 1 || header))
    }

    /// Parse OCR lines into subscriptions. `now` anchors year-less renewal
    /// dates ("Renews Oct 12") to the next occurrence.
    static func parse(lines: [OCR.Line], now: Date = Date()) -> [Subscription] {
        let sorted = lines.sorted { $0.box.midY > $1.box.midY }   // Vision: origin bottom-left → top first
        var records: [Record] = []
        var current: Record? = nil

        func flush() {
            if let c = current, c.isComplete { records.append(c) }
            current = nil
        }

        for line in sorted {
            let t = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "›>•·"))
                .trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            let lower = t.lowercased()
            if sectionWords.contains(lower) { flush(); continue }

            if let (amount, cycle, prefix) = pricePeriod(in: t) {
                if current == nil || current!.isComplete {
                    flush()
                    current = Record()
                }
                if current!.name.isEmpty, let prefix, !prefix.isEmpty, !matches(trialRegex, prefix) {
                    current!.name = prefix
                }
                current!.amount = amount
                current!.cycle = cycle
                // "$8.99/month · Renews Oct 12" on one line, or a trial's
                // "until <date>, then $12.99/month".
                if matches(trialRegex, t), let d = extractDate(from: t, now: now, future: true) {
                    current!.trialEndsAt = d
                    current!.renews = d
                } else if matches(renewRegex, t) {
                    if matches(inactiveRegex, t) { current!.active = false }
                    if let d = extractDate(from: t, now: now, future: true) { current!.renews = d }
                }
                continue
            }

            if matches(renewRegex, t) {
                if current == nil { current = Record() }
                let inactive = matches(inactiveRegex, t)
                    || lower.hasPrefix("expires")   // cancelled, running out — not a live subscription to track
                if inactive { current!.active = false }
                if let d = extractDate(from: t, now: now, future: !inactive) {
                    if matches(trialRegex, t) { current!.trialEndsAt = d }
                    current!.renews = d
                }
                continue
            }

            if let d = extractDate(from: t, now: now, future: true), isDateOnly(t) {
                if current == nil { current = Record() }
                if current!.renews == nil { current!.renews = d }
                continue
            }

            // A text line: name, then plan, then the next record.
            if current == nil || current!.isComplete {
                flush()
                current = Record(name: t)
            } else if current!.name.isEmpty {
                current!.name = t
            } else if current!.plan == nil {
                current!.plan = t
            } else {
                // Third text line without a price in between — a new record.
                flush()
                current = Record(name: t)
            }
        }
        flush()

        return records.filter { $0.active }.map { subscription(from: $0, now: now) }
    }

    private static func subscription(from r: Record, now: Date) -> Subscription {
        let name = cleanName(r.name)
        let brandId = MerchantNormalizer.brandId(forNormalized: name)
        let known = BrandRegistry.brand(for: brandId, fallbackName: name) != nil
        let id = known ? brandId : "apple-" + RecurrenceDetector.slug(name)
        let period = RecurrenceDetector.period(for: r.cycle) * 86_400
        let next = r.renews ?? now.addingTimeInterval(period)
        let hex = BrandRegistry.brand(for: brandId, fallbackName: name)?.hex ?? "000000"
        let planText = r.plan.map { " — \($0)" } ?? ""
        return Subscription(
            id: id,
            name: known ? (BrandRegistry.displayName(for: brandId) ?? name) : name,
            vendor: name,
            rawDescriptor: "Apple Subscriptions · \(name)\(planText)",
            brandHex: hex,
            category: known ? BrandRegistry.category(for: brandId) : .other,
            amount: r.amount,
            cycle: r.cycle,
            nextBilling: next,
            startedAt: next.addingTimeInterval(-period),
            lastUsedAt: nil,
            sessionsLast30d: 0,
            userRating: nil,
            marketAverage: 0,
            trialEndsAt: r.trialEndsAt,
            hasPriceHike: nil,
            hasOverlapWith: [],
            notes: r.trialEndsAt != nil
                ? "From your Apple subscriptions list. Free trial — you'll be charged \(fmtUSD(r.amount)) when it ends."
                : "From your Apple subscriptions list. Cancel or request a refund through Apple, not the vendor.",
            billedVia: .apple
        )
    }

    private static func cleanName(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Matching helpers

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// (amount, cycle, text before the price) for "$8.99/month"-style lines.
    static func pricePeriod(in text: String) -> (Double, BillingCycle, String?)? {
        let range = NSRange(text.startIndex..., in: text)
        guard let m = pricePeriodRegex.firstMatch(in: text, options: [], range: range),
              let amountRange = Range(m.range(at: 1), in: text),
              let periodRange = Range(m.range(at: 3), in: text),
              let amount = Double(text[amountRange].replacingOccurrences(of: ",", with: ""))
        else { return nil }
        let period = text[periodRange].lowercased().replacingOccurrences(of: " ", with: "")
        let cycle: BillingCycle
        switch period {
        case _ where period.hasPrefix("6month"): cycle = .semiannual
        case _ where period.hasPrefix("3month"), "quarter": cycle = .quarterly
        case _ where period.hasPrefix("year") || period.hasPrefix("yr"): cycle = .yearly
        case _ where period.hasPrefix("week") || period.hasPrefix("wk"): cycle = .weekly
        default: cycle = .monthly
        }
        let prefix: String? = Range(m.range, in: text).map {
            String(text[text.startIndex..<$0.lowerBound]).trimmingCharacters(in: CharacterSet(charactersIn: " -–—:,·"))
        }
        return (amount, cycle, prefix)
    }

    private static let dateFormats: [(String, Bool)] = [
        ("MMMM d, yyyy", false), ("MMM d, yyyy", false), ("MMM d yyyy", false), ("MMMM d yyyy", false),
        ("M/d/yyyy", false), ("M/d/yy", false), ("yyyy-MM-dd", false),
        ("MMMM d", true), ("MMM d", true), ("M/d", true),
    ]

    private static let formatters: [(DateFormatter, Bool)] = dateFormats.map { fmt, yearless in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = fmt
        return (f, yearless)
    }

    private static let dateTokenRegex = try! NSRegularExpression(
        pattern: #"(?i)\b((?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{1,2}(?:,?\s+\d{4})?|\d{1,2}/\d{1,2}(?:/\d{2,4})?|\d{4}-\d{2}-\d{2})\b"#
    )

    /// First date-looking token in the text. Year-less dates are pinned to the
    /// next (future=true) or most recent (future=false) occurrence.
    static func extractDate(from text: String, now: Date, future: Bool) -> Date? {
        let range = NSRange(text.startIndex..., in: text)
        guard let m = dateTokenRegex.firstMatch(in: text, options: [], range: range),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        let token = String(text[r]).replacingOccurrences(of: "Sept", with: "Sep").replacingOccurrences(of: ".", with: "")
        for (f, yearless) in formatters {
            guard let d = f.date(from: token) else { continue }
            guard yearless else { return d }
            let cal = Calendar.current
            let md = cal.dateComponents([.month, .day], from: d)
            var comps = cal.dateComponents([.year], from: now)
            comps.month = md.month
            comps.day = md.day
            guard var candidate = cal.date(from: comps) else { return d }
            if future, candidate < now.addingTimeInterval(-86_400), let next = cal.date(byAdding: .year, value: 1, to: candidate) {
                candidate = next
            } else if !future, candidate > now, let prev = cal.date(byAdding: .year, value: -1, to: candidate) {
                candidate = prev
            }
            return candidate
        }
        return nil
    }

    private static func isDateOnly(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        guard let m = dateTokenRegex.firstMatch(in: text, options: [], range: range) else { return false }
        return m.range.length >= text.utf16.count - 2
    }
}
