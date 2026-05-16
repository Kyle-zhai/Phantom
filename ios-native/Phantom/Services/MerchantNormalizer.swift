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
            // Leading numeric date — e.g. "5/08 NETFLIX.COM" (Chase, Wells,
            // Discover all use this single-row layout where date prefixes the
            // merchant on the same OCR row).
            "\\d{1,2}/\\d{1,2}(?:/\\d{2,4})?\\s+",
            "\\d{1,2}-\\d{1,2}(?:-\\d{2,4})?\\s+",
        ]
        for prefix in prefixes {
            s = s.replacingOccurrences(of: "^" + prefix, with: "", options: .regularExpression)
        }

        // 3. Strip 3rd-party processor prefixes (these are 99% of mis-grouping)
        //
        // Note on Amazon: AMZN MKTPL / AMAZON MKTPLACE are MARKETPLACE one-offs
        // (random retail), NOT Amazon Prime subscriptions. We leave them alone
        // so the "amzn mktpl" keyword blacklist + the ML classifier handle them
        // as transactional. Amazon Prime descriptors ("AMZN PRIME*RT4LM",
        // "AMAZON PRIME*…") are caught separately via the brandId alias map.
        let processors: [(pattern: String, brand: String?)] = [
            (#"^PAYPAL\s*\*"#, nil),       // PAYPAL *<merchant> — strip, keep merchant
            (#"^SQ\s*\*"#, nil),           // Square: SQ *<merchant>
            (#"^SPO\s*\*"#, nil),          // SPO* (another Square variant — restaurants/retail)
            (#"^TST\s*\*"#, nil),          // Toast: TST*<merchant>
            (#"^SP\s*\*"#, nil),           // Stripe: SP*<merchant>
            (#"^STR\s*\*"#, nil),          // Stripe alt
            (#"^STRIPE\s*\*"#, nil),
            (#"^GOOGLE\s*\*"#, "Google"),  // GOOGLE *YouTube etc → could be Google itself
            (#"^APPLE\.COM/BILL"#, "Apple"),
            (#"^ITUNES\.COM/BILL"#, "Apple"),
            (#"^APPLE\s+\.COM"#, "Apple"),
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
            #"\*[A-Z0-9]*\d[A-Z0-9]*"#,             // *RT3JK / *A5KU — must contain a digit
                                                    // (never strip *EATS / *RIDE / *ONE / *PRO,
                                                    // which are subscription-meaningful)
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
    /// Patterns are matched against both the raw lowercase string AND a
    /// punctuation-stripped variant so that "APL*ITUNES.COM/BILL",
    /// "AMZN PRIME*RT3JK", and OCR'd misreads like "NETFL IX" still map.
    static func brandId(forNormalized name: String) -> String {
        let lower = name.lowercased()
        let stripped = lower.filter { $0.isLetter || $0.isNumber }
        // (rawPattern, strippedPattern, id) — strippedPattern checked when raw misses.
        // Bank-statement descriptors known to occur in the wild: keep this list
        // up to date as users report unfamiliar formats.
        let aliases: [(String, String, String)] = [
            // Streaming
            ("netflix",         "netflix",       "netflix"),
            ("hulu",            "hulu",          "hulu"),
            ("spotify",         "spotify",       "spotify"),
            ("peacock",         "peacock",       "peacock"),
            ("paramount",       "paramount",     "paramount"),
            ("disney",          "disney",        "disney-plus"),
            ("hbo",             "hbomax",        "hbo-max"),
            ("max ",            "hbomax",        "hbo-max"),
            ("youtubepre",      "youtubepre",    "youtube-premium"),
            ("youtube tv",      "youtubetv",     "youtube-tv"),
            ("youtube",         "youtube",       "youtube-premium"),
            // Apple — billing always goes through APL*/APPLE.COM/BILL
            ("apple tv",        "appletv",       "apple-tv"),
            ("apple music",     "applemusic",    "apple-music"),
            ("apple one",       "appleone",      "apple-music"),
            ("apple.com/bill",  "applecombill",  "apple-music"),
            ("apl*itunes",      "aplitunes",     "apple-music"),
            ("apl itunes",      "aplitunes",     "apple-music"),
            ("itunes.com/bill", "itunescombill", "apple-music"),
            ("apl*",            "apl",           "apple-music"),
            ("icloud",          "icloud",        "icloud"),
            // Music & audio
            ("tidal",           "tidal",         "tidal"),
            ("sirius",          "sirius",        "sirius-xm"),
            ("audible",         "audible",       "audible"),
            // Amazon
            ("amazon prime",    "amazonprime",   "amazon-prime"),
            ("amzn prime",      "amznprime",     "amazon-prime"),
            ("amzn digital",    "amzndigital",   "audible"),
            ("amazon digital",  "amazondigital", "audible"),
            ("kindle unlimited","kindleunlim",   "audible"),
            ("amazon",          "amazon",        "amazon-prime"),
            ("walmart",         "walmart",       "walmart-plus"),
            // Google
            ("google one",      "googleone",     "google-one"),
            ("google *youtube", "googleyoutube", "youtube-premium"),
            ("googl*youtube",   "googleyoutube", "youtube-premium"),
            ("google storage",  "googlestorage", "google-one"),
            ("google",          "google",        "google-one"),
            ("googl*",          "google",        "google-one"),
            // Cloud storage / productivity
            ("dropbox",         "dropbox",       "dropbox"),
            ("adobe creative",  "adobecreative", "adobe-cc"),
            ("adobe *cre",      "adobecre",      "adobe-cc"),
            ("adobe",           "adobe",         "adobe-photography"),
            ("microsoft 365",   "microsoft365",  "github"),
            ("msft*office",     "msftoffice",    "github"),
            ("msft *office",    "msftoffice",    "github"),
            // GitHub & Copilot
            ("github copilot",  "githubcopilot", "github-copilot"),
            ("github *copilot", "githubcopilot", "github-copilot"),
            ("github",          "github",        "github"),
            // AI / chat
            ("chatgpt",         "chatgpt",       "chatgpt"),
            ("openai",          "openai",        "chatgpt"),
            ("anthropic",       "anthropic",     "claude"),
            ("claude",          "claude",        "claude"),
            ("gemini",          "gemini",        "gemini"),
            ("google ai pro",   "googleaipro",   "gemini"),
            ("ai premium",      "aipremium",     "gemini"),
            ("perplexity",      "perplexity",    "perplexity"),
            // Dev tools
            ("cursor",          "cursor",        "cursor"),
            ("anyspher",        "anyspher",      "cursor"),
            ("replit",          "replit",        "replit"),
            ("v0.dev",          "v0dev",         "v0"),
            ("v0 *",            "v0",            "v0"),
            ("vercel",          "vercel",        "vercel"),
            ("bolt.new",        "boltnew",       "bolt"),
            ("stackblitz",      "stackblitz",    "bolt"),
            ("lovable",         "lovable",       "lovable"),
            ("linear.app",      "linearapp",     "linear"),
            ("linear orbit",    "linearorbit",   "linear"),
            ("linear inc",      "linearinc",     "linear"),
            // AI media
            ("midjourney",      "midjourney",    "openai"),
            ("runway",          "runway",        "openai"),
            ("suno",            "suno",          "suno"),
            ("elevenlabs",      "elevenlabs",    "elevenlabs"),
            ("eleven labs",     "elevenlabs",    "elevenlabs"),
            ("huggingface",     "huggingface",   "huggingface"),
            ("hugging face",    "huggingface",   "huggingface"),
            ("deepseek",        "deepseek",      "deepseek"),
            ("mistral",         "mistral",       "anthropic"),
            ("cohere",          "cohere",        "anthropic"),
            ("together ai",     "togetherai",    "anthropic"),
            ("groq",            "groq",          "anthropic"),
            // Notes / language / learning
            ("notion",          "notion",        "notion"),
            ("duolingo",        "duolingo",      "duolingo"),
            ("masterclass",     "masterclass",   "masterclass"),
            // Password / VPN
            ("lastpass",        "lastpass",      "lastpass"),
            ("logmein*lastpass","logmeinlastpass","lastpass"),
            ("1password",       "1password",     "1password"),
            ("expressvpn",      "expressvpn",    "expressvpn"),
            ("express vpn",     "expressvpn",    "expressvpn"),
            ("nordvpn",         "nordvpn",       "nordvpn"),
            ("nord vpn",        "nordvpn",       "nordvpn"),
            // News
            ("new york times",  "newyorktimes",  "nyt"),
            ("nytimes",         "nytimes",       "nyt"),
            ("nyt ",            "nyt",           "nyt"),
            ("wsj",             "wsj",           "wsj"),
            ("washington post", "washingtonpost","washington-post"),
            // Fitness
            ("planet fitness",  "planetfitness", "planet-fitness"),
            ("equinox",         "equinox",       "equinox"),
            ("peloton",         "peloton",       "peloton"),
            // Wellness
            ("headspace",       "headspace",     "headspace"),
            ("calm",            "calm",          "calm"),
            ("noom",            "noom",          "noom"),
            // Third-party processors that wrap subs
            ("paypal *netflix", "paypalnetflix", "netflix"),
            ("paypal *spotify", "paypalspotify", "spotify"),
            ("paypal *hulu",    "paypalhulu",    "hulu"),
            // Mobility / delivery memberships (subs that ride on transactional apps)
            ("uber one",        "uberone",       "uber-one"),
            ("uber *one",       "uberone",       "uber-one"),
            ("uber*one",        "uberone",       "uber-one"),
            ("lyft pink",       "lyftpink",      "lyft-pink"),
            ("lyft *pink",      "lyftpink",      "lyft-pink"),
            ("dashpass",        "dashpass",      "dashpass"),
            ("doordash dashpass","doordashdashpass","dashpass"),
        ]
        for (pattern, _, id) in aliases {
            if lower.contains(pattern) { return id }
        }
        // Fuzzy fallback: try stripped pattern against stripped name
        // (handles "APL*ITUNES", "AMZN  DIGITAL" with double space, etc.)
        for (_, strippedPattern, id) in aliases where strippedPattern.count >= 5 {
            if stripped.contains(strippedPattern) { return id }
        }
        // Last resort: slug the name
        return lower.replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Three-tier check: hard rejection → known brand → ML × price gate.
    ///
    /// The price gate exists because subscription pricing is unusually regular
    /// ($X.99 tiers, round-dollar AI tools). When the merchant is unknown but
    /// the amount matches that pattern, we trust mid-confidence ML predictions.
    /// When the amount is random ($24.50, $6.75 — classic restaurant/ride),
    /// we require ML to be very confident before saying "subscription".
    static func looksLikeSubscription(name: String, amount: Double) -> Bool {
        // Hard transactional rejection (gas station, restaurant, ride, etc.)
        if isLikelyTransactional(name) { return false }
        // Known subscription brand → accept
        if BrandRegistry.brand(for: brandId(forNormalized: name), fallbackName: name) != nil {
            return true
        }
        // Otherwise weigh the ML score against the price signal
        let mlScore = MerchantML.subscriptionProbability(for: name)
        if mlScore >= 0.80 { return true }
        if mlScore >= 0.50 && isLikelySubscriptionAmount(amount) { return true }
        return false
    }

    /// Returns true if `amount` looks like a common subscription price tier.
    /// Used as a secondary signal in `looksLikeSubscription` (paired with
    /// mid-confidence ML).
    ///
    /// Conservative on purpose: we ONLY match exact advertised prices and
    /// the .99-ending pattern. A naive "base + tax tolerance" loop sounds
    /// useful but is actually deadly — the commonSubscriptionAmounts set
    /// has ~50 entries densely packed every $1-$2, so a 10% tax window
    /// covers nearly every dollar amount $1-$275. That caused $10/$31/$52
    /// restaurant/gym one-offs to all match.
    ///
    /// Tradeoff: we miss tax-included prices for UNKNOWN brands (e.g.,
    /// $10.87 = Spotify + NY tax). For KNOWN brands this is fine because
    /// BrandRegistry catches them before the price gate. For unknown brands
    /// at tax-inclusive prices, the user adds them manually — preferable
    /// to scrolling through 30 false-positive restaurant charges.
    static func isLikelySubscriptionAmount(_ amount: Double) -> Bool {
        let cents = Int((amount * 100).rounded())
        guard cents > 0 else { return false }
        let dollars = Double(cents) / 100

        // 1. Exact match against the curated base-price list
        if commonSubscriptionAmounts.contains(dollars) { return true }

        // 2. Generic ".99 under $250" — every streaming/SaaS tier in the US
        //    advertises in $X.99 form. This is the only safe generalization.
        if cents % 100 == 99 && dollars <= 250 { return true }

        return false
    }

    private static let commonSubscriptionAmounts: Set<Double> = [
        // Cheap tier (Apple TV+, iCloud 50GB, basic streaming with ads)
        0.99, 1.99, 2.99, 3.99, 4.99, 5.99, 6.99, 7.99, 8.99,
        // Standard streaming / music (Spotify, Apple Music, Hulu, DashPass, Uber One)
        9.99, 10.99, 11.99, 12.99, 13.99, 14.99,
        // Netflix Standard / family streaming / mid SaaS
        15.49, 15.99, 16.99, 17.99, 18.99, 19.99,
        // ChatGPT/Claude Pro round-dollar tier + family Apple One
        20.00, 21.99, 22.99, 24.99, 25.00, 29.99,
        // Live TV / fitness / family
        34.99, 39.99, 44.99, 49.99, 54.99, 59.99, 69.99,
        // Annual rounded (Prime, news, gym)
        79.99, 89.99, 99.99, 109.99, 119.99, 129.99, 139.99, 149.99,
        159.99, 169.99, 179.99, 199.00, 199.99, 219.99, 239.99, 249.99,
    ]

    /// Returns true when the merchant string looks like a one-off retail/food/
    /// transport/ATM charge — never a subscription.
    ///
    /// Two-stage check:
    ///   1. Fast keyword blacklist (microseconds, deterministic, easy to debug)
    ///   2. CreateML-trained NLModel for anything not caught by keywords —
    ///      handles unseen merchant variants like "PANDA EXPRESS 7741" or
    ///      "TST*JOE'S DINER" that aren't in the keyword list verbatim.
    static func isLikelyTransactional(_ name: String) -> Bool {
        let lower = name.lowercased()
        for keyword in transactionalKeywords where lower.contains(keyword) {
            return true
        }
        // Fall back to ML classifier for unseen merchant patterns
        return MerchantML.isLikelyTransactional(name)
    }

    // Common US merchant strings that are never subscriptions.
    // Each entry is a lowercase substring searched in the merchant name.
    //
    // ⚠️ Be specific. "uber" alone would kill Uber One ($9.99/mo subscription)
    // and "amazon" alone would kill Amazon Prime. Only blacklist patterns that
    // unambiguously identify a one-off transaction.
    private static let transactionalKeywords: [String] = [
        // Rideshare & transit (specific patterns — keep Uber One / DashPass alive)
        "uber *trip", "uber trip", "uber*trip", "uber eats", "uber *eats",
        "ubereats", "lyft *ride", "lyft ride", "lyft trip", "lyft *trip",
        "via rideshare", "curb taxi", "yellow cab", " taxi ",
        "amtrak ", "greyhound bus", "septa key", "mta*nyct", "mta subway",
        "bart *fare", "wmata*metro", "metro card", "metrocard",
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
        // Delivery — match only the "<service> *<restaurant>" patterns, so
        // subscription tiers like DOORDASH DASHPASS / GRUBHUB+ / INSTACART+
        // don't get caught. Bare "DOORDASH" without an asterisk is rare in
        // the wild for individual orders.
        "doordash *", "doordash*",
        "ubereats *", "ubereats*", "ubereats ", "uber eats",
        "grubhub *", "grubhub*",
        "postmates *", "postmates*",
        "seamless *", "seamless*",
        "instacart *", "instacart*",
        "gopuff *", "gopuff*",
        "favor delivery",
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
