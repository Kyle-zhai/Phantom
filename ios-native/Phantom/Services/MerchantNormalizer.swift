import Foundation

/// Strips noise from raw bank-statement merchant strings and normalizes them
/// so the same vendor appears as the same merchant across statements.
///
/// Examples it handles:
///   "POS DEBIT NETFLIX.COM SAN FRAN CA 4218" → "Netflix"
///   "SP* NETFLIX 0123456"                     → "Netflix"
///   "AMZN MKTP US*RT3JK"                      → "Amazon"
///   "AMAZON PRIME*RT4LM 866-216-1072 WA"      → "Amazon Prime"
///   "PAYPAL *SPOTIFY USA"                     → "Spotify"
///   "APPLE.COM/BILL ITUNES.COM"               → "Apple"
///   "CHASE CARD PYMT - THANK YOU"             → ignored (not a merchant)
enum MerchantNormalizer {
    /// Returns a cleaned, title-cased merchant name suitable for grouping.
    /// Returns nil if the line looks like a payment, transfer, or fee.
    static func normalize(_ raw: String) -> String? {
        var s = raw.uppercased()

        // 1. Reject obvious non-merchant rows
        let rejectKeywords: [String] = [
            "PAYMENT THANK YOU", "PAYMENT — THANK YOU", "CARD PYMT",
            "AUTOMATIC PAYMENT", "AUTOPAY", "TRANSFER FROM", "TRANSFER TO",
            "INTEREST CHARGE", "LATE FEE", "REVERSAL", "CASH ADVANCE",
            "ATM WITHDRAWAL", "BALANCE TRANSFER", "STATEMENT BALANCE",
            "PREVIOUS BALANCE", "CREDIT LIMIT", "AVAILABLE CREDIT",
            "MINIMUM PAYMENT", "AVAILABLE BALANCE",
        ]
        if rejectKeywords.contains(where: { s.contains($0) }) { return nil }

        // 2. Strip bank action prefixes
        let prefixes: [String] = [
            "POS DEBIT ", "POS PURCHASE ", "DEBIT CARD PURCHASE ",
            "PURCHASE AUTHORIZED ON \\d{1,2}/\\d{1,2}\\s*",
            "RECURRING PAYMENT ", "RECURRING DEBIT ",
            "ELECTRONIC PMT ", "ONLINE TRANSFER ", "MOBILE PURCHASE ",
            "PURCHASE ", "DEBIT ", "CHECK CARD PURCHASE ", "POS ",
            "PYMT TO ", "PAYMENT TO ",
        ]
        for prefix in prefixes {
            s = s.replacingOccurrences(of: "^" + prefix, with: "", options: .regularExpression)
        }

        // 3. Strip 3rd-party processor prefixes (these are 99% of mis-grouping)
        let processors: [(pattern: String, brand: String?)] = [
            (#"^PAYPAL\s*\*"#, nil),       // PAYPAL *<merchant> — strip, keep merchant
            (#"^SQ\s*\*"#, nil),           // Square: SQ *<merchant>
            (#"^TST\s*\*"#, nil),          // Toast: TST*<merchant>
            (#"^SP\s*\*"#, nil),           // Stripe: SP*<merchant>
            (#"^STR\s*\*"#, nil),          // Stripe alt
            (#"^STRIPE\s*\*"#, nil),
            (#"^GOOGLE\s*\*"#, "Google"),  // GOOGLE *YouTube etc → could be Google itself
            (#"^APPLE\.COM/BILL"#, "Apple"),
            (#"^ITUNES\.COM/BILL"#, "Apple"),
            (#"^APPLE\s+\.COM"#, "Apple"),
            (#"^AMZN\s+MKTP"#, "Amazon"),
            (#"^AMAZON\s+MKTP"#, "Amazon"),
            (#"^AMZN\.COM"#, "Amazon"),
        ]
        for (pattern, brand) in processors {
            if s.range(of: pattern, options: .regularExpression) != nil {
                if let brand {
                    // Whole-line replacement (the processor IS the merchant)
                    s = brand.uppercased()
                } else {
                    // Strip the processor prefix, keep what follows
                    s = s.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
                }
                break
            }
        }

        // 4. Strip trailing junk: card last-4, dates, city/state, phone numbers, transaction ids
        let trailingPatterns: [String] = [
            #"\s+\d{4}\s*$"#,                      // ending 4 digits (card last-4)
            #"\s+\d{2}/\d{2}(/\d{2,4})?\s*"#,      // dates anywhere
            #"\s+[A-Z]{2}\s*$"#,                    // trailing state code (CA, NY)
            #"\s+(US|USA)\s*$"#,                   // trailing US
            #"\s+\d{3}[- ]?\d{3}[- ]?\d{4}"#,      // phone numbers
            #"\s+\d{6,}"#,                          // long transaction ids
            #"\*[A-Z0-9]{4,}"#,                     // *ABC123 suffix
            #"\s+#\d+"#,                            // trailing #1234
        ]
        for pattern in trailingPatterns {
            s = s.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // 5. Cleanup whitespace and corporate suffixes
        s = s.replacingOccurrences(of: #"\s+(INC|LLC|LTD|CORP|CO|COMPANY)\.?$"#,
                                   with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"\.COM\s*$"#,
                                   with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        if s.isEmpty || s.count < 2 { return nil }

        return titleCase(s)
    }

    /// Returns an id suitable for matching against BrandRegistry.byId.
    static func brandId(forNormalized name: String) -> String {
        let lower = name.lowercased()
        // Map common-name aliases to canonical brand ids in BrandRegistry.byId
        let aliases: [(pattern: String, id: String)] = [
            ("netflix", "netflix"),
            ("hulu", "hulu"),
            ("spotify", "spotify"),
            ("peacock", "peacock"),
            ("paramount", "paramount"),
            ("disney", "disney-plus"),
            ("hbo", "hbo-max"),
            ("max ", "hbo-max"),
            ("apple tv", "apple-tv"),
            ("apple music", "apple-music"),
            ("tidal", "tidal"),
            ("sirius", "sirius-xm"),
            ("audible", "audible"),
            ("amazon prime", "amazon-prime"),
            ("amazon", "amazon-prime"),
            ("walmart", "walmart-plus"),
            ("icloud", "icloud"),
            ("google one", "google-one"),
            ("google", "google-one"),
            ("dropbox", "dropbox"),
            ("adobe creative", "adobe-cc"),
            ("adobe", "adobe-photography"),
            ("microsoft 365", "github"),
            ("github copilot", "github-copilot"),
            ("github", "github"),
            ("chatgpt", "chatgpt"),
            ("openai", "chatgpt"),
            ("anthropic", "claude"),
            ("claude", "claude"),
            ("gemini", "gemini"),
            ("notion", "notion"),
            ("duolingo", "duolingo"),
            ("masterclass", "masterclass"),
            ("lastpass", "lastpass"),
            ("1password", "1password"),
            ("expressvpn", "expressvpn"),
            ("nordvpn", "nordvpn"),
            ("new york times", "nyt"),
            ("nytimes", "nyt"),
            ("wsj", "wsj"),
            ("planet fitness", "planet-fitness"),
            ("peloton", "peloton"),
            ("headspace", "headspace"),
            ("calm", "calm"),
            ("noom", "noom"),
            ("youtube tv", "youtube-tv"),
            ("youtube", "youtube-premium"),
        ]
        for (pattern, id) in aliases {
            if lower.contains(pattern) { return id }
        }
        // Fall back: slug the name
        return lower.replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Heuristic: does this amount + name LOOK like a subscription (even with only 1 sighting)?
    /// Used in single-screenshot detection where we don't have recurrence proof.
    static func looksLikeSubscription(name: String, amount: Double) -> Bool {
        // 1. Known subscription brand → yes
        if BrandRegistry.brand(for: brandId(forNormalized: name), fallbackName: name) != nil {
            return true
        }
        // 2. Common subscription price points: round dollars + cents pattern
        let cents = Int((amount * 100).rounded()) % 100
        let isCommonCents = [99, 95, 0, 49, 9, 89].contains(cents)
        let isCommonRange = amount >= 2.99 && amount <= 100.0
        if isCommonCents && isCommonRange { return true }
        // 3. Yearly subs in $50-500 range with /yr-style amounts
        if amount >= 50 && amount <= 500 && (amount.truncatingRemainder(dividingBy: 1.0) == 0 || cents == 99) {
            return true
        }
        return false
    }

    private static func titleCase(_ s: String) -> String {
        s.lowercased()
            .split(separator: " ")
            .map { word -> String in
                guard let first = word.first else { return "" }
                // Preserve all-caps acronyms ≤ 3 chars (NYT, WSJ, AT&T)
                if word.count <= 3 && word.allSatisfy({ $0.isLetter }) {
                    return word.uppercased()
                }
                return String(first).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
