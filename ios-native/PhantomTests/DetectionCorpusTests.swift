import XCTest
@testable import Phantom

/// End-to-end recognition on a corpus of real-style bank descriptors: does the
/// normalizer + brand map + subscription gate say "subscription" for the subs,
/// reject the one-offs, and name the right brand? Thresholds are deliberately
/// tight — a regression here is a user seeing "GitHub" for Microsoft 365 or a
/// restaurant in their Radar.
final class DetectionCorpusTests: XCTestCase {
    struct Row {
        let raw: String
        let amount: Double
        let brand: String?
        let isSub: Bool
        init(_ raw: String, _ amount: Double, _ brand: String?) {
            self.raw = raw; self.amount = amount; self.brand = brand; self.isSub = brand != nil
        }
    }

    static let subs: [Row] = [
        Row("NETFLIX.COM LOS GATOS CA", 15.49, "netflix"),
        Row("NETFLIX.COM 866-579-7172", 17.99, "netflix"),
        Row("NFLX*SUBSCRIPTION", 19.99, "netflix"),
        Row("HULU LLC SANTA MONICA", 17.99, "hulu"),
        Row("HULU CA HULU.COM/BIL", 7.99, "hulu"),
        Row("DISNEYPLUS.COM BURBANK", 10.99, "disney-plus"),
        Row("DISNEY PLUS BURBANK CA", 15.99, "disney-plus"),
        Row("PARAMOUNT PLUS NY", 11.99, "paramount"),
        Row("PEACOCK NBCUNI", 13.99, "peacock"),
        Row("MAX*WB GAMES", 15.99, "hbo-max"),
        Row("POS DEBIT HBO MAX *SUBSCRIPTION", 15.99, "hbo-max"),
        Row("APPLE TV+ APL*", 9.99, "apple-tv"),
        Row("APL*APPLE TV+", 9.99, "apple-tv"),
        Row("CRUNCHYROLL *PREMIUM", 7.99, "crunchyroll"),
        Row("ESPN PLUS", 11.99, "espn-plus"),
        Row("STARZ ENTERTAINMENT", 10.99, "starz"),
        Row("AMC PLUS", 8.99, "amc-plus"),
        Row("FUBOTV INC", 84.99, "fubo"),
        Row("SLING TV", 45.99, "sling"),
        Row("SPOTIFY USA 877-778-9440", 11.99, "spotify"),
        Row("SPOTIFY USA NEW YORK NY", 11.99, "spotify"),
        Row("SPOTIFY USA 877-7781161 NY", 9.99, "spotify"),
        Row("PAYPAL *SPOTIFY", 11.99, "spotify"),
        Row("APL*APPLE MUSIC", 10.99, "apple-music"),
        Row("APPLE.COM/BILL ITUNES.COM", 9.99, "apple-services"),
        Row("APPLE.COM/BILL 866-712-7753", 2.99, "apple-services"),
        Row("ITUNES.COM/BILL CORK IE", 0.99, "apple-services"),
        Row("APL*ICLOUD+ STORAGE 200GB", 2.99, "icloud"),
        Row("APL*ICLOUD STORAGE", 9.99, "icloud"),
        Row("APL*APPLE ONE FAMILY", 22.95, "apple-one"),
        Row("APL*APPLE ARCADE", 6.99, "apple-arcade"),
        Row("TIDAL *PREMIUM", 10.99, "tidal"),
        Row("AUDIBLE*MEMBERSHIP", 14.95, "audible"),
        Row("KINDLE UNLTD*2K4J8 AMZN.COM/BILL", 11.99, "kindle-unlimited"),
        Row("AMAZON PRIME VIDEO*AB12C", 8.99, "prime-video"),
        Row("SIRIUSXM *INTERNET", 22.99, "sirius-xm"),
        Row("PANDORA MEDIA", 10.99, "pandora"),
        Row("GOOGLE *YouTube Premium", 13.99, "youtube-premium"),
        Row("GOOGLE *YouTube Music", 10.99, "youtube-music"),
        Row("GOOGLE *YouTube TV", 82.99, "youtube-tv"),
        Row("GOOGLE *Google One", 1.99, "google-one"),
        Row("GOOGLE *Workspace", 6.00, "google-workspace"),
        Row("GOOGLE *Gemini Advanced", 19.99, "gemini"),
        Row("GOOGL*YouTube Premium", 13.99, "youtube-premium"),
        Row("GOOGLE *Calm", 14.99, "google-play"),
        Row("AMZN PRIME*RT3JK 866-216-1072", 14.99, "amazon-prime"),
        Row("AMAZON PRIME*RT4LM 866-216-1072 WA", 139.00, "amazon-prime"),
        Row("AMAZON PRIME MEMBERSHIP", 14.99, "amazon-prime"),
        Row("AMAZON MUSIC*UNLIMITED", 10.99, "amazon-music"),
        Row("WALMART+ MEMBERSHIP", 12.95, "walmart-plus"),
        Row("OPENAI *CHATGPT", 20.00, "chatgpt"),
        Row("OPENAI *CHATGPT SUBSCR SAN FRAN", 20.00, "chatgpt"),
        Row("ANTHROPIC, PBC", 20.00, "anthropic"),
        Row("ANTHROPIC PBC *CLDPRO", 20.00, "anthropic"),
        Row("CURSOR AI ANYSPHERE", 20.00, "cursor"),
        Row("PERPLEXITY AI INC", 20.00, "perplexity"),
        Row("MIDJOURNEY INC", 10.00, "midjourney"),
        Row("GITHUB.COM SAN FRANCISCO", 10.00, "github"),
        Row("GITHUB *COPILOT", 10.00, "github-copilot"),
        Row("REPLIT *REPL", 25.00, "replit"),
        Row("VERCEL INC.", 20.00, "vercel"),
        Row("LINEAR.APP", 8.00, "linear"),
        Row("V0 *PROHQ", 20.00, "v0"),
        Row("UBER *ONE MEMBERSHIP UBER.COM/BILL", 9.99, "uber-one"),
        Row("LYFT *PINK MEMBERSHIP", 9.99, "lyft-pink"),
        Row("DOORDASH DASHPASS", 9.99, "dashpass"),
        Row("DOORDASH*DASHPASS SAN FRANCISCO", 9.99, "dashpass"),
        Row("INSTACART *PLUS", 9.99, "instacart-plus"),
        Row("GRUBHUB*GRUBHUB+", 9.99, "grubhub-plus"),
        Row("DROPBOX *MEMBERSHIP", 11.99, "dropbox"),
        Row("NOTION *SUBSCRIPTION", 10.00, "notion"),
        Row("ADOBE *CREATIVE CLD", 59.99, "adobe-cc"),
        Row("ADOBE *ACROBAT PRO", 19.99, "adobe"),
        Row("MICROSOFT*365 PERSONAL", 9.99, "microsoft-365"),
        Row("MSFT * E0700ABCDE", 9.99, "microsoft-365"),
        Row("1PASSWORD.COM", 2.99, "1password"),
        Row("LASTPASS *PREMIUM", 3.00, "lastpass"),
        Row("BITWARDEN INC", 10.00, "bitwarden"),
        Row("NORDVPN.COM", 11.95, "nordvpn"),
        Row("EXPRESSVPN.COM", 12.95, "expressvpn"),
        Row("PROTON AG", 9.99, "proton"),
        Row("NEW YORK TIMES DIGITAL", 25.00, "nyt"),
        Row("NYTIMES *DIGITAL", 17.00, "nyt"),
        Row("WSJ.COM/SUBSCRIPTION", 38.99, "wsj"),
        Row("WASHINGTON POST DIGITAL", 12.00, "washington-post"),
        Row("PELOTON INTERACTIVE", 44.00, "peloton"),
        Row("PLANET FIT *CLUB FEE", 24.99, "planet-fitness"),
        Row("EQUINOX *MEMBERSHIP", 235.00, "equinox"),
        Row("HEADSPACE INC", 12.99, "headspace"),
        Row("CALM.COM", 14.99, "calm"),
        Row("DUOLINGO *PLUS", 6.99, "duolingo"),
        Row("MASTERCLASS *ALL ACCESS", 15.00, "masterclass"),
        Row("SPECTRUM 833-697-7328", 89.99, "spectrum"),
        Row("COMCAST XFINITY 800-9346-489", 109.99, "xfinity"),
        Row("T-MOBILE 800-937-8997", 65.00, "t-mobile"),
        Row("VERIZON WIRELESS 800-922-0204", 85.00, "verizon"),
        Row("PURCHASE AUTHORIZED ON 05/07 NETFLIX.COM", 15.49, "netflix"),
        Row("RECURRING PAYMENT AUTHORIZED ON 05/06 SPOTIFY USA NY", 11.99, "spotify"),
        Row("ELECTRONIC PMT - DISNEYPLUS.COM BURBANK", 10.99, "disney-plus"),
        Row("RECURRING DEBIT GITHUB.COM SAN FRANCISCO", 4.00, "github"),
        Row("RECURRING CARD PURCHASE 03/12 ROCK SPOT CLIMBING", 62.00, "rock-spot-climbing"),
    ]

    static let oneOffs: [Row] = [
        Row("UBER *EATS HELP.UBER.COM", 18.86, nil),
        Row("UBER *EATS HELP.UBER.COMCA", 47.40, nil),
        Row("LYFT *RIDE TUE 8AM LYFT.COM", 14.99, nil),
        Row("LYFT *RIDE THU 6PM LYFT.COM CA", 6.94, nil),
        Row("UBER TRIP HELP.UBER.COM", 24.50, nil),
        Row("DOORDASH *MCDONALDS", 24.99, nil),
        Row("GRUBHUB*CHIPOTLE", 18.50, nil),
        Row("DOORDASH *CHIPOTLE", 16.42, nil),
        Row("UBEREATS *CHIPOTLE", 19.32, nil),
        Row("STARBUCKS STORE 04521", 6.75, nil),
        Row("STARBUCKS #41258 BOSTON MA", 5.95, nil),
        Row("DUNKIN #341928 BOSTON", 4.50, nil),
        Row("MCDONALD'S F11729 BOSTON MA", 9.99, nil),
        Row("CHIPOTLE 1234", 14.50, nil),
        Row("PANERA BREAD #3456", 12.45, nil),
        Row("SHAKE SHACK PROVIDENCE", 18.11, nil),
        Row("WHOLE FOODS MKT 12345 NY", 87.42, nil),
        Row("TRADER JOE'S #572 PROVIDENCE", 34.18, nil),
        Row("KROGER #001 FUEL", 42.00, nil),
        Row("CVS PHARMACY #1234", 18.92, nil),
        Row("WALGREENS #5677", 24.99, nil),
        Row("AMZN MKTPL*RT3JK", 45.00, nil),
        Row("AMZN MKTP US*W2A4QR1", 28.43, nil),
        Row("AMAZON MKTPLACE PMTS AMZN.COM/BILL", 67.43, nil),
        Row("TARGET 00012345", 67.43, nil),
        Row("BEST BUY #1234", 199.99, nil),
        Row("HOME DEPOT 1234", 89.99, nil),
        Row("WALMART STORE #2345", 67.13, nil),
        Row("SHELL OIL 1234567", 52.00, nil),
        Row("EXXONMOBIL 5678901", 48.00, nil),
        Row("CHEVRON 12345", 52.00, nil),
        Row("MBTA MTICKET 617-222-3200 MA", 10.00, nil),
        Row("BART *FARE OAKLAND CA", 4.95, nil),
        Row("WMATA*METRO WASHINGTON DC", 2.85, nil),
        Row("METROCARD NYC MTA", 2.90, nil),
        Row("CTA TRAIN CHICAGO", 2.50, nil),
        Row("BIG NIGHT LIVE 617-3384343 MA", 40.66, nil),
        Row("MALA NOODLES 131-27305592 IL", 23.65, nil),
        Row("TST*AGUARDENTE PROVIDENCE", 63.00, nil),
        Row("SPO*YSHABUSHABU PROVIDENCE", 144.71, nil),
        Row("HILTON HOTELS NYC", 289.00, nil),
        Row("AIRBNB *HMQF3F4G", 345.00, nil),
        Row("APPLE STORE #R051 BOSTON MA", 129.00, nil),
        Row("APPLE.COM/US CUPERTINO CA", 549.00, nil),
        Row("GOOGLE *Google Pixel", 799.00, nil),
        Row("PHILOSOPHY SKINCARE", 32.00, nil),
        Row("PINEAPPLE EXPRESS SMOOTHIES", 8.45, nil),
        Row("CHASE CARD PYMT - THANK YOU", 250.00, nil),
        Row("AUTOMATIC PAYMENT - THANK YOU", 120.00, nil),
        Row("ANNUAL FEE", 95.00, nil),
        Row("USPS PO 1234567890", 9.99, nil),
        Row("PARKING METER 123", 4.00, nil),
    ]

    private struct Outcome { let row: Row; let isSub: Bool; let brand: String? }

    private func run(_ row: Row) -> Outcome {
        guard let merchant = MerchantNormalizer.normalize(row.raw) else {
            return Outcome(row: row, isSub: false, brand: nil)
        }
        let hint = MerchantNormalizer.hasSubscriptionHint(row.raw)
        let isSub = MerchantNormalizer.looksLikeSubscription(name: merchant, amount: row.amount, recurringHint: hint)
        return Outcome(row: row, isSub: isSub, brand: MerchantNormalizer.brandId(forNormalized: merchant))
    }

    func testSubscriptionRecallAndBrandAccuracy() {
        let outcomes = Self.subs.map(run)
        let missed = outcomes.filter { !$0.isSub }
        let wrongBrand = outcomes.filter { $0.isSub && $0.brand != $0.row.brand }
        let recall = Double(outcomes.count - missed.count) / Double(outcomes.count)
        let brandAcc = Double(outcomes.count - wrongBrand.count) / Double(outcomes.count)
        XCTAssertGreaterThanOrEqual(recall, 0.97,
            "missed subs: " + missed.map { "\($0.row.raw) → \($0.brand ?? "nil")" }.joined(separator: "; "))
        XCTAssertGreaterThanOrEqual(brandAcc, 0.97,
            "wrong brands: " + wrongBrand.map { "\($0.row.raw) → \($0.brand ?? "nil") (want \($0.row.brand!))" }.joined(separator: "; "))
    }

    func testOneOffRejection() {
        let outcomes = Self.oneOffs.map(run)
        let falsePositives = outcomes.filter { $0.isSub }
        let precision = Double(outcomes.count - falsePositives.count) / Double(outcomes.count)
        XCTAssertGreaterThanOrEqual(precision, 0.95,
            "false positives: " + falsePositives.map { "\($0.row.raw) → \($0.brand ?? "nil")" }.joined(separator: "; "))
    }

    func testHardNegativesNeverMapToABrand() {
        XCTAssertNotEqual(run(Row("PINEAPPLE EXPRESS SMOOTHIES", 8.45, nil)).brand, "apple-services")
        XCTAssertNotEqual(run(Row("PHILOSOPHY SKINCARE", 32, nil)).brand, "philo")
        XCTAssertFalse(run(Row("APPLE STORE #R051 BOSTON MA", 129, nil)).isSub)
        XCTAssertFalse(run(Row("GOOGLE *Google Pixel", 799, nil)).isSub)
        XCTAssertFalse(run(Row("ANNUAL FEE", 95, nil)).isSub)
    }
}
