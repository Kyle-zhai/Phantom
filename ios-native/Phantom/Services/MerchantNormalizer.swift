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

    /// Strict single-sighting filter. Only surfaces a charge as a "likely sub"
    /// when the merchant matches a known subscription brand AND isn't on the
    /// transactional blacklist.
    ///
    /// Why so strict: with only one observation we can't distinguish a Starbucks
    /// at $5.95 from a streaming service at $5.95. The previous cents-pattern
    /// heuristic produced too many false positives (Uber rides, restaurant bills,
    /// gas station charges all hit ".99" or ".95" prices). Known brand → high
    /// confidence; everything else waits for the recurrence detector to confirm.
    static func looksLikeSubscription(name: String, amount: Double) -> Bool {
        if isLikelyTransactional(name) { return false }
        return BrandRegistry.brand(for: brandId(forNormalized: name), fallbackName: name) != nil
    }

    /// Returns true when the merchant string looks like a one-off retail/food/
    /// transport/ATM charge — never a subscription. Used to filter noise from
    /// both single-sighting and recurrence detection so a daily Starbucks habit
    /// doesn't get flagged as a subscription.
    static func isLikelyTransactional(_ name: String) -> Bool {
        let lower = name.lowercased()
        for keyword in transactionalKeywords where lower.contains(keyword) {
            return true
        }
        return false
    }

    // Common US merchant strings that are never subscriptions.
    // Each entry is a lowercase substring searched in the merchant name.
    private static let transactionalKeywords: [String] = [
        // Rideshare & transit
        "uber", "lyft", "via ", "curb", "yellow cab", "taxi",
        "amtrak", "greyhound", "septa", "mta", "bart", "wmata", "metro card",
        // Gas stations
        "shell oil", "shell ", "exxon", "chevron", "bp ", "mobil", "speedway",
        "sunoco", "valero", "citgo", "marathon ", "76 station",
        // Food / coffee / fast food / chains
        "starbucks", "dunkin", "peets", "mcdonald", "burger king", "wendy",
        "chipotle", "panera", "chick-fil", "taco bell", "kfc", "popeyes",
        "subway sandwich", "domino", "pizza hut", "papa john", "in-n-out",
        "shake shack", "five guys", "sweetgreen", "cava ", "jamba",
        "smoothie king", "auntie anne", "panda express", "qdoba", "moe's",
        // Restaurant generic patterns
        "restaurant", "cafe", "diner", " grill", "bistro", "tavern",
        "kitchen", " deli", "bakery", "noodle", "ramen", "sushi", "pho ",
        " bbq", "steakhouse", "pizzeria", "pub ",
        // Delivery
        "doordash", "ubereats", "uber eats", "grubhub", "postmates",
        "seamless", "instacart", "gopuff", "favor delivery",
        // Groceries / convenience
        "trader joe", "whole foods", "safeway", "kroger", "publix",
        "wegmans", "h-e-b", "stop & shop", "shoprite", "albertsons",
        "7-eleven", "wawa", "cvs ", "walgreens", "rite aid", "duane reade",
        "aldi ", "sprouts", "fresh market",
        // Big-box retail (one-off purchases)
        "target.com", "target store", "walmart store", "walmart.com",
        "best buy", "home depot", "lowe's", "marshalls", "tjmaxx",
        "tj maxx", "ross stores", "burlington store", "ikea", "macy",
        "nordstrom", "kohl's", "bloomingdale",
        // Apparel chains
        "uniqlo", "h&m", "zara ", "gap store", "old navy", "urban outfitters",
        "lululemon", "athleta", "banana republic",
        // Beauty
        "sephora", "ulta beauty",
        // ATM / fees / transfers
        "atm withdrawal", "cash withdrawal", "wire fee", "service charge",
        "overdraft", "annual fee", "interest charge", "foreign transaction",
        "non-sufficient funds",
        // Peer-to-peer payments (not subs)
        "venmo *", "zelle to", "zelle from", "cash app *", "popmoney",
        // Travel one-offs
        "airline", "expedia", "kayak", "booking.com", "airbnb",
        "marriott", "hilton ", "hyatt ", "ihg ",
        " hertz", "enterprise rent", "budget rent", "avis ",
    ]

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
