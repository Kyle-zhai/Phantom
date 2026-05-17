import Foundation
import AppKit

// Generate 100 synthetic bank-statement images mimicking the user's real
// BoA/Citi mobile screenshots (IMG_1795-1799.PNG). Layout:
//   - Brown header band
//   - Each tx row: date (gray, top) / merchant (black, big) / amount (blue, right)
//   - Running balance (gray, below amount)
//
// Mix of real subscription descriptors (verbatim from public articles) +
// real-world one-offs (rideshare, food, retail, gas). Each generated image
// gets a TSV ground-truth row so the accuracy harness can score it.

struct Tx {
    let date: String
    let merchant: String
    let amount: Double
    let isSub: Bool
    let expectedSvg: String?
}

let outDir = "/Users/pinan/Desktop/test_100"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for f in (try? FileManager.default.contentsOfDirectory(atPath: outDir)) ?? [] {
    try? FileManager.default.removeItem(atPath: "\(outDir)/\(f)")
}

// ===== Merchant pools (verbatim public descriptor formats) =====

let subs: [(String, Double, String)] = [
    // Streaming
    ("NETFLIX.COM LOS GATOS CA",        15.49, "netflix"),
    ("NETFLIX.COM 866-579-7172",        17.99, "netflix"),
    ("NETFLIX.COM",                     22.99, "netflix"),
    ("HULU LLC SANTA MONICA",           17.99, "hulu"),
    ("HULU CA HULU.COM/BIL",            7.99,  "hulu"),
    ("HULU LLC 877-824-4858",           18.99, "hulu"),
    ("DISNEYPLUS.COM BURBANK",          10.99, "disney-missing"),
    ("DISNEY PLUS BURBANK CA",          15.99, "disney-missing"),
    ("PARAMOUNT PLUS NY",               11.99, "paramount"),
    ("PEACOCK NBCUNI",                  13.99, "peacock"),
    ("MAX*WB GAMES",                    15.99, "hbo-max"),
    ("APPLE TV+ APL*",                  9.99,  "apple-tv"),
    ("APL*APPLE TV+",                   9.99,  "apple-tv"),
    // Music
    ("SPOTIFY USA 877-778-9440",        11.99, "spotify"),
    ("SPOTIFY USA NEW YORK NY",         11.99, "spotify"),
    ("SPOTIFY USA 877-7781161 NY",      9.99,  "spotify"),
    ("APL*APPLE MUSIC",                 10.99, "apple-music"),
    ("APPLE.COM/BILL ITUNES.COM",       9.99,  "apple-music"),
    ("APPLE.COM/BILL 866-712-7753",     2.99,  "apple-music"),
    ("ITUNES.COM/BILL CORK IE",         0.99,  "apple-music"),
    ("APL*ICLOUD+ STORAGE 200GB",       2.99,  "icloud"),
    ("APL*ICLOUD STORAGE",              9.99,  "icloud"),
    ("APL*APPLE ONE FAMILY",            22.95, "apple-music"),
    ("APL*APPLE ARCADE",                6.99,  "apple-music"),
    ("TIDAL *PREMIUM",                  10.99, "tidal"),
    ("AUDIBLE*MEMBERSHIP",              14.95, "audible"),
    ("SIRIUSXM *INTERNET",              22.99, "sirius-missing"),
    // Google
    ("GOOGLE *YouTube Premium",         13.99, "youtube-premium"),
    ("GOOGLE *YouTube TV",              82.99, "youtube-tv"),
    ("GOOGLE *Google One",              1.99,  "google-one"),
    ("GOOGLE *Workspace",               6.00,  "google-one"),
    ("GOOGLE *Gemini Advanced",         19.99, "gemini"),
    ("GOOGL*YouTube Premium",           13.99, "youtube-premium"),
    // Amazon
    ("AMZN PRIME*RT3JK 866-216-1072",   14.99, "amazon-prime"),
    ("AMAZON PRIME*RT4LM 866-216-1072 WA", 139.00, "amazon-prime"),
    ("AMAZON PRIME MEMBERSHIP",         14.99, "amazon-prime"),
    // AI / dev tools
    ("OPENAI *CHATGPT",                 20.00, "openai"),
    ("OPENAI *CHATGPT SUBSCR SAN FRAN", 20.00, "openai"),
    ("ANTHROPIC, PBC",                  20.00, "anthropic"),
    ("ANTHROPIC PBC *CLDPRO",           20.00, "anthropic"),
    ("CURSOR AI ANYSPHERE",             20.00, "cursor"),
    ("PERPLEXITY AI INC",               20.00, "perplexity"),
    ("GITHUB.COM SAN FRANCISCO",        10.00, "github"),
    ("GITHUB *COPILOT",                 10.00, "github-copilot"),
    ("REPLIT *REPL",                    25.00, "replit"),
    ("VERCEL INC.",                     20.00, "vercel"),
    ("LINEAR.APP",                      8.00,  "linear"),
    ("V0 *PROHQ",                       20.00, "v0"),
    // Mobility memberships
    ("UBER *ONE MEMBERSHIP UBER.COM/BILL", 9.99, "uber"),
    ("LYFT *PINK MEMBERSHIP",           9.99,  "lyft"),
    ("DOORDASH DASHPASS",               9.99,  "doordash"),
    ("DOORDASH*DASHPASS SAN FRANCISCO",  9.99, "doordash"),
    // Productivity
    ("DROPBOX *MEMBERSHIP",             11.99, "dropbox"),
    ("NOTION *SUBSCRIPTION",            10.00, "notion"),
    ("ADOBE *CREATIVE CLD",             59.99, "adobe-cc"),
    ("1PASSWORD.COM",                   2.99,  "1password"),
    ("LASTPASS *PREMIUM",               3.00,  "lastpass"),
    ("NORDVPN.COM",                     11.95, "nordvpn"),
    ("EXPRESSVPN.COM",                  12.95, "expressvpn"),
    // News
    ("NEW YORK TIMES DIGITAL",          25.00, "nyt"),
    ("NYTIMES *DIGITAL",                17.00, "nyt"),
    ("WSJ.COM/SUBSCRIPTION",            38.99, "wsj-missing"),
    ("WASHINGTON POST DIGITAL",         12.00, "washington-post-missing"),
    // Fitness / wellness
    ("PELOTON INTERACTIVE",             44.00, "peloton"),
    ("PLANET FIT *CLUB FEE",            24.99, "planet-fitness-missing"),
    ("EQUINOX *MEMBERSHIP",             235.00, "equinox-missing"),
    ("HEADSPACE INC",                   12.99, "headspace"),
    ("CALM.COM",                        14.99, "calm-missing"),
    // Language / learning
    ("DUOLINGO *PLUS",                  6.99,  "duolingo"),
    ("MASTERCLASS *ALL ACCESS",         15.00, "masterclass-missing"),
    // Cable / wireless
    ("SPECTRUM 833-697-7328",           89.99, "spectrum"),
    ("COMCAST XFINITY 800-9346-489",    109.99, "xfinity-missing"),
    ("T-MOBILE 800-937-8997",           65.00, "tmobile-missing"),
    ("VERIZON WIRELESS 800-922-0204",   85.00, "verizon"),
    // Wells / BoA verbose prefixes
    ("PURCHASE AUTHORIZED ON 05/07 NETFLIX.COM", 15.49, "netflix"),
    ("RECURRING PAYMENT AUTHORIZED ON 05/06 SPOTIFY USA NY", 11.99, "spotify"),
    ("ELECTRONIC PMT - DISNEYPLUS.COM BURBANK", 10.99, "disney-missing"),
    ("RECURRING DEBIT GITHUB.COM SAN FRANCISCO", 4.00, "github"),
    ("POS DEBIT HBO MAX *SUBSCRIPTION", 15.99, "hbo-max"),
]

let oneoffs: [(String, Double)] = [
    // Rideshare (real)
    ("UBER *EATS HELP.UBER.COM",        18.86),
    ("UBER *EATS HELP.UBER.COMCA",      47.40),
    ("UBER *EATS HELP.UBER.COM",        22.45),
    ("LYFT *RIDE TUE 8AM LYFT.COM",     14.99),
    ("LYFT *RIDE SUN 9PM LYFT.COM",     30.97),
    ("LYFT *RIDE FRI 6PM LYFT.COM",     6.92),
    ("LYFT *RIDE THU 6PM LYFT.COM CA",  6.94),
    ("UBER TRIP HELP.UBER.COM",         24.50),
    // Delivery
    ("DOORDASH *MCDONALDS",             24.99),
    ("GRUBHUB*CHIPOTLE",                18.50),
    ("DOORDASH *CHIPOTLE",              16.42),
    ("UBEREATS *CHIPOTLE",              19.32),
    // Coffee / fast food
    ("STARBUCKS STORE 04521",           6.75),
    ("STARBUCKS #41258 BOSTON MA",      5.95),
    ("DUNKIN #341928 BOSTON",           4.50),
    ("MCDONALD'S F11729 BOSTON MA",     9.99),
    ("MCDONALDS #11729",                8.45),
    ("CHIPOTLE 1234",                   14.50),
    ("PANERA BREAD #3456",              12.45),
    ("SHAKE SHACK PROVIDENCE",          18.11),
    // Groceries
    ("WHOLE FOODS MKT 12345 NY",        87.42),
    ("TRADER JOE'S #572 PROVIDENCE",    34.18),
    ("KROGER #001 FUEL",                42.00),
    ("CVS PHARMACY #1234",              18.92),
    ("WALGREENS #5677",                 24.99),
    // Big-box
    ("AMZN MKTPL*RT3JK",                45.00),
    ("AMZN MKTP US*W2A4QR1",            28.43),
    ("AMAZON MKTPLACE PMTS AMZN.COM/BILL", 67.43),
    ("TARGET 00012345",                 67.43),
    ("BEST BUY #1234",                  199.99),
    ("HOME DEPOT 1234",                 89.99),
    ("WALMART STORE #2345",             67.13),
    // Gas
    ("SHELL OIL 1234567",               52.00),
    ("EXXONMOBIL 5678901",              48.00),
    ("CHEVRON 12345",                   52.00),
    ("76 STATION FUEL 4321",            45.00),
    // Transit (US)
    ("MBTA MTICKET 617-222-3200 MA",    10.00),
    ("BART *FARE OAKLAND CA",           4.95),
    ("WMATA*METRO WASHINGTON DC",       2.85),
    ("METROCARD NYC MTA",               2.90),
    ("CTA TRAIN CHICAGO",               2.50),
    // Restaurants
    ("BIG NIGHT LIVE 617-3384343 MA",   40.66),
    ("DEN DEN KOREAN FRIED",            27.54),
    ("MALA NOODLES 131-27305592 IL",    23.65),
    ("TST*AGUARDENTE PROVIDENCE",       63.00),
    ("SPO*YSHABUSHABU PROVIDENCE",      144.71),
    ("WEIS YUNNAN RICE NOOD BOSTON",    52.00),
    // Misc
    ("ROCK SPOT CLIMBING",              31.00),
    ("BROWN BOOKSTORE NS",              45.54),
    ("1046 CAFFE NERO BROWN",           13.18),
    ("HILTON HOTELS NYC",               289.00),
    ("AIRBNB *HMQF3F4G",                345.00),
    ("HERTZ CAR RENTAL",                87.50),
    ("APPLE STORE #R051 BOSTON MA",     129.00),
    ("APPLE.COM/US CUPERTINO CA",       549.00),
    ("GOOGLE *Google Pixel",            799.00),
]

func dateLabel(_ daysAgo: Int) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "MMM d, yyyy"
    return f.string(from: Date().addingTimeInterval(-Double(daysAgo) * 86400))
}

func render(_ statement: [Tx], to path: String) {
    let width: CGFloat = 720
    let topPad: CGFloat = 120
    let rowH: CGFloat = 96
    let height = topPad + rowH * CGFloat(statement.count) + 40

    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: image.size).fill()

    // Brown header band — match the IMG_1795-1799 style
    NSColor(calibratedRed: 0.45, green: 0.36, blue: 0.27, alpha: 1).setFill()
    NSRect(x: 0, y: height - 80, width: width, height: 50).fill()
    NSAttributedString(string: "Now viewing", attributes: [
        .font: NSFont.boldSystemFont(ofSize: 16),
        .foregroundColor: NSColor.white,
    ]).draw(at: NSPoint(x: 20, y: height - 65))
    NSAttributedString(string: "Statements 05/14/2026 · All Transaction Types", attributes: [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.white,
    ]).draw(at: NSPoint(x: 300, y: height - 60))

    // Mirror the real BoA mobile statement layout the parser is tuned for:
    //   Band A (top of row):    date (left) + amount (right)  → parser reads
    //                            this as a dateOnlyWithAmount row
    //   Band B (bottom of row): merchant (left) + balance (right) → parser
    //                            pairs it with band A
    // Each band must be tight in Y (~1% of image height) so the OCR clustering
    // groups left/right elements together. The two bands are then ~35px apart
    // so OCR sees them as separate.
    var y = height - topPad
    var balance: Double = 1500.00
    for tx in statement {
        // === Band A: date + amount on same Y ===
        let bandA = y - 8
        NSAttributedString(string: tx.date, attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.gray,
        ]).draw(at: NSPoint(x: 24, y: bandA))
        let amtStr = String(format: "$%.2f", tx.amount)
        let amtAttr = NSAttributedString(string: amtStr, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 19),
            .foregroundColor: NSColor(calibratedRed: 0, green: 0.4, blue: 0.85, alpha: 1),
        ])
        amtAttr.draw(at: NSPoint(x: width - 24 - amtAttr.size().width, y: bandA - 4))

        // === Band B: merchant + balance on same Y, ~36px below band A ===
        let bandB = y - 46
        NSAttributedString(string: tx.merchant, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 17),
            .foregroundColor: NSColor.black,
        ]).draw(at: NSPoint(x: 24, y: bandB))
        balance -= tx.amount
        let balStr = String(format: "$%.2f", abs(balance))
        let balAttr = NSAttributedString(string: balStr, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.gray,
        ])
        balAttr.draw(at: NSPoint(x: width - 24 - balAttr.size().width, y: bandB + 2))
        // Hairline separator
        NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
        NSRect(x: 20, y: y - rowH + 6, width: width - 40, height: 1).fill()
        y -= rowH
    }
    image.unlockFocus()

    if let tiff = image.tiffRepresentation,
       let bm = NSBitmapImageRep(data: tiff),
       let png = bm.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

// ===== Generate 100 statements =====
var rng = SystemRandomNumberGenerator()
var manifest = "image\tdate\tmerchant\tamount\tis_subscription\texpected_brand_svg\n"
var totalRows = 0
var totalSubs = 0

for i in 1...100 {
    let n = Int.random(in: 7...10, using: &rng)
    var txs: [Tx] = []
    // ~30-50% subs per statement to mirror typical user spread
    let nSubs = Int.random(in: 2...5, using: &rng)
    for _ in 0..<nSubs {
        let s = subs.randomElement(using: &rng)!
        let day = Int.random(in: 1...28, using: &rng)
        txs.append(Tx(date: dateLabel(day), merchant: s.0, amount: s.1, isSub: true, expectedSvg: s.2))
    }
    for _ in nSubs..<n {
        let o = oneoffs.randomElement(using: &rng)!
        let day = Int.random(in: 1...28, using: &rng)
        txs.append(Tx(date: dateLabel(day), merchant: o.0, amount: o.1, isSub: false, expectedSvg: nil))
    }
    // Shuffle so subs/one-offs interleave realistically
    txs.shuffle(using: &rng)

    let name = String(format: "sample_%03d.png", i)
    render(txs, to: "\(outDir)/\(name)")
    for tx in txs {
        let svg = tx.expectedSvg ?? ""
        manifest += "\(name)\t\(tx.date)\t\(tx.merchant)\t\(String(format: "$%.2f", tx.amount))\t\(tx.isSub)\t\(svg)\n"
        totalRows += 1
        if tx.isSub { totalSubs += 1 }
    }
}

try? manifest.write(toFile: "\(outDir)/ground_truth.tsv", atomically: true, encoding: .utf8)
print("Generated 100 statements, \(totalRows) total rows, \(totalSubs) subs")
print("Manifest: \(outDir)/ground_truth.tsv")
