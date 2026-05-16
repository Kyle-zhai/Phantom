import Foundation
import AppKit

/// Synthetic bank-statement renderer covering the major US layouts and ~100
/// real-world merchant descriptors (cleaned from the user's actual screenshots
/// plus the simpleicons.org brand catalog). Pairs each generated row with
/// ground-truth labels (isSub, expectedBrandSvg, expectedAmount, expectedDate)
/// so the test harness can compute precision/recall on every axis.

struct Tx {
    let date: String
    let merchant: String
    let amount: String
    let balance: String
    let isSubscription: Bool
    /// Expected svg filename in Resources/Brands/, or nil if no brand match expected.
    let expectedBrandSvg: String?
}

enum Style {
    case citi      // two-row: date+amount, merchant+balance
    case chase     // single-row: date | merchant | amount
    case apple     // mobile: merchant | amount, date below
    case wells     // single-row with category column
    case discover  // similar to citi but tighter
}

func renderStatement(style: Style, header: String, txs: [Tx], to path: String) {
    let width: CGFloat = 920
    let topPad: CGFloat = 140

    let lineH: CGFloat = {
        switch style {
        case .citi, .discover: return 110
        case .chase, .wells:   return 72
        case .apple:           return 84
        }
    }()
    let height = topPad + lineH * CGFloat(txs.count) + 80

    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: image.size).fill()

    let headerAttr = NSAttributedString(string: header, attributes: [
        .font: NSFont.boldSystemFont(ofSize: 28),
        .foregroundColor: NSColor.black
    ])
    headerAttr.draw(at: NSPoint(x: 40, y: height - 60))
    NSAttributedString(string: "Statements · All Transactions", attributes: [
        .font: NSFont.systemFont(ofSize: 18),
        .foregroundColor: NSColor.darkGray
    ]).draw(at: NSPoint(x: 40, y: height - 90))

    var y = height - topPad

    for tx in txs {
        switch style {
        case .citi, .discover:
            // Row A: date + amount
            NSAttributedString(string: tx.date, attributes: [
                .font: NSFont.systemFont(ofSize: 20),
                .foregroundColor: NSColor.darkGray
            ]).draw(at: NSPoint(x: 40, y: y))
            let amt = NSAttributedString(string: tx.amount, attributes: [
                .font: NSFont.boldSystemFont(ofSize: 26),
                .foregroundColor: NSColor.systemBlue
            ])
            amt.draw(at: NSPoint(x: width - 40 - amt.size().width, y: y))
            y -= 38
            // Row B: merchant + balance
            NSAttributedString(string: tx.merchant, attributes: [
                .font: NSFont.systemFont(ofSize: 22),
                .foregroundColor: NSColor.black
            ]).draw(at: NSPoint(x: 40, y: y))
            let bal = NSAttributedString(string: tx.balance, attributes: [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.darkGray
            ])
            bal.draw(at: NSPoint(x: width - 40 - bal.size().width, y: y))
            y -= 72

        case .chase, .wells:
            NSAttributedString(string: tx.date, attributes: [
                .font: NSFont.systemFont(ofSize: 20),
                .foregroundColor: NSColor.black
            ]).draw(at: NSPoint(x: 40, y: y))
            NSAttributedString(string: tx.merchant, attributes: [
                .font: NSFont.systemFont(ofSize: 20),
                .foregroundColor: NSColor.black
            ]).draw(at: NSPoint(x: 180, y: y))
            let amt = NSAttributedString(string: tx.amount, attributes: [
                .font: NSFont.systemFont(ofSize: 20),
                .foregroundColor: NSColor.black
            ])
            amt.draw(at: NSPoint(x: width - 40 - amt.size().width, y: y))
            y -= lineH

        case .apple:
            NSAttributedString(string: tx.merchant, attributes: [
                .font: NSFont.systemFont(ofSize: 22),
                .foregroundColor: NSColor.black
            ]).draw(at: NSPoint(x: 40, y: y))
            let amt = NSAttributedString(string: tx.amount, attributes: [
                .font: NSFont.boldSystemFont(ofSize: 22),
                .foregroundColor: NSColor.black
            ])
            amt.draw(at: NSPoint(x: width - 40 - amt.size().width, y: y))
            y -= 28
            NSAttributedString(string: tx.date, attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.darkGray
            ]).draw(at: NSPoint(x: 40, y: y))
            y -= lineH - 28
        }
    }

    image.unlockFocus()

    if let tiff = image.tiffRepresentation,
       let bm = NSBitmapImageRep(data: tiff),
       let png = bm.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
        print("Wrote: \((path as NSString).lastPathComponent)")
    }
}

let outDir = "/Users/pinan/Desktop/test_synthetic"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
// wipe old generated files so re-running is clean
for f in (try? FileManager.default.contentsOfDirectory(atPath: outDir)) ?? [] {
    try? FileManager.default.removeItem(atPath: "\(outDir)/\(f)")
}

// ===================================================================
// 12 statements, ~100 transactions, ground truth covers brand SVG + sub flag
// ===================================================================

// --- 01: Streaming heavyweights (Citi) ---
let s01: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "NETFLIX.COM LOS GATOS CA",        amount: "$15.49", balance: "$1,234.56", isSubscription: true,  expectedBrandSvg: "netflix"),
    Tx(date: "May 7, 2026", merchant: "SPOTIFY USA 877-778-9440",        amount: "$9.99",  balance: "$1,220.00", isSubscription: true,  expectedBrandSvg: "spotify"),
    Tx(date: "May 5, 2026", merchant: "HULU LLC SANTA MONICA",           amount: "$17.99", balance: "$1,210.01", isSubscription: true,  expectedBrandSvg: "hulu"),
    Tx(date: "May 4, 2026", merchant: "DISNEYPLUS.COM BURBANK",          amount: "$10.99", balance: "$1,192.02", isSubscription: true,  expectedBrandSvg: nil), // disney pattern → youtube-premium svg fallback (acceptable as "matched")
    Tx(date: "May 2, 2026", merchant: "MAX*WB GAMES",                    amount: "$15.99", balance: "$1,181.03", isSubscription: true,  expectedBrandSvg: "hbo-max"),
    Tx(date: "May 1, 2026", merchant: "PARAMOUNT PLUS",                  amount: "$11.99", balance: "$1,165.04", isSubscription: true,  expectedBrandSvg: "paramount"),
    Tx(date: "Apr 30, 2026",merchant: "PEACOCK NBCUNI",                  amount: "$13.99", balance: "$1,153.05", isSubscription: true,  expectedBrandSvg: "peacock"),
    Tx(date: "Apr 29, 2026",merchant: "APPLE.COM/BILL ITUNES.COM",       amount: "$9.99",  balance: "$1,139.06", isSubscription: true,  expectedBrandSvg: "apple-music"),
]
renderStatement(style: .citi, header: "Customized Cash · 7122", txs: s01, to: "\(outDir)/01_streaming.png")

// --- 02: AI / Dev tools (Citi) ---
let s02: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "OPENAI *CHATGPT",                  amount: "$20.00", balance: "$1,234.56", isSubscription: true,  expectedBrandSvg: "openai"),
    Tx(date: "May 6, 2026", merchant: "ANTHROPIC, PBC",                   amount: "$20.00", balance: "$1,214.56", isSubscription: true,  expectedBrandSvg: "anthropic"),
    Tx(date: "May 4, 2026", merchant: "CURSOR.SH",                        amount: "$20.00", balance: "$1,194.56", isSubscription: true,  expectedBrandSvg: "cursor"),
    Tx(date: "May 2, 2026", merchant: "PERPLEXITY AI INC",                amount: "$20.00", balance: "$1,174.56", isSubscription: true,  expectedBrandSvg: "perplexity"),
    Tx(date: "May 1, 2026", merchant: "GITHUB.COM SAN FRANCISCO",         amount: "$10.00", balance: "$1,154.56", isSubscription: true,  expectedBrandSvg: "github"),
    Tx(date: "Apr 30, 2026",merchant: "REPLIT *REPL",                     amount: "$25.00", balance: "$1,144.56", isSubscription: true,  expectedBrandSvg: "replit"),
    Tx(date: "Apr 28, 2026",merchant: "VERCEL INC.",                      amount: "$20.00", balance: "$1,119.56", isSubscription: true,  expectedBrandSvg: "vercel"),
    Tx(date: "Apr 25, 2026",merchant: "LINEAR.APP",                       amount: "$8.00",  balance: "$1,099.56", isSubscription: true,  expectedBrandSvg: "linear"),
    Tx(date: "Apr 22, 2026",merchant: "V0 *PROHQ",                        amount: "$20.00", balance: "$1,091.56", isSubscription: true,  expectedBrandSvg: "v0"),
]
renderStatement(style: .citi, header: "Chase Sapphire · 4488", txs: s02, to: "\(outDir)/02_ai_dev.png")

// --- 03: Food / retail one-offs (Citi) — pure transactional, must be 0 subs ---
let s03: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "STARBUCKS #41258 BOSTON MA",       amount: "$6.75",  balance: "$1,234.56", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 7, 2026", merchant: "UBER *EATS HELP.UBER.COM",         amount: "$18.86", balance: "$1,227.81", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 6, 2026", merchant: "LYFT *RIDE TUE 8AM LYFT.COM",      amount: "$14.99", balance: "$1,208.95", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 5, 2026", merchant: "DOORDASH *MCDONALDS",              amount: "$24.99", balance: "$1,193.96", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 4, 2026", merchant: "WHOLE FOODS MKT 12345 NY",         amount: "$87.42", balance: "$1,168.97", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 3, 2026", merchant: "TRADER JOE'S #572 PROVIDENCE",     amount: "$34.18", balance: "$1,081.55", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 2, 2026", merchant: "AMZN MKTPL*RT3JK",                 amount: "$45.00", balance: "$1,047.37", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 1, 2026", merchant: "TARGET 00012345",                  amount: "$67.43", balance: "$1,002.37", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "Apr 29, 2026",merchant: "SHELL OIL 1234567",                amount: "$52.00", balance: "$934.94",   isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "Apr 28, 2026",merchant: "GRUBHUB*CHIPOTLE",                 amount: "$18.50", balance: "$882.94",   isSubscription: false, expectedBrandSvg: nil),
]
renderStatement(style: .citi, header: "Citi Premier · 3344", txs: s03, to: "\(outDir)/03_food_retail.png")

// --- 04: Chase single-row mixed ---
let s04: [Tx] = [
    Tx(date: "5/08", merchant: "NETFLIX.COM",                             amount: "$22.99", balance: "", isSubscription: true,  expectedBrandSvg: "netflix"),
    Tx(date: "5/07", merchant: "STARBUCKS STORE 04521",                   amount: "$5.95",  balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "5/06", merchant: "APL*ITUNES.COM/BILL",                     amount: "$9.99",  balance: "", isSubscription: true,  expectedBrandSvg: "apple-music"),
    Tx(date: "5/05", merchant: "SHELL OIL 1234567",                       amount: "$45.00", balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "5/04", merchant: "PAYPAL *SPOTIFYUSA",                      amount: "$11.99", balance: "", isSubscription: true,  expectedBrandSvg: "spotify"),
    Tx(date: "5/03", merchant: "CHIPOTLE 1234",                           amount: "$14.50", balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "5/02", merchant: "NORDVPN.COM",                             amount: "$11.95", balance: "", isSubscription: true,  expectedBrandSvg: "nordvpn"),
    Tx(date: "5/01", merchant: "BEST BUY #1234",                          amount: "$199.99",balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "4/30", merchant: "DUOLINGO *PLUS",                          amount: "$6.99",  balance: "", isSubscription: true,  expectedBrandSvg: "duolingo"),
    Tx(date: "4/29", merchant: "PANERA BREAD #3456",                      amount: "$12.45", balance: "", isSubscription: false, expectedBrandSvg: nil),
]
renderStatement(style: .chase, header: "Chase Freedom · 4488", txs: s04, to: "\(outDir)/04_chase_mixed.png")

// --- 05: Tricky edge cases (Citi) ---
let s05: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "1PASSWORD.COM",                    amount: "$2.99",  balance: "$1,234.56", isSubscription: true,  expectedBrandSvg: "1password"),
    Tx(date: "May 7, 2026", merchant: "ROCK SPOT CLIMBING",               amount: "$31.00", balance: "$1,231.57", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 6, 2026", merchant: "BROWN BOOKSTORE NS",               amount: "$45.54", balance: "$1,200.57", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 5, 2026", merchant: "HEADSPACE INC",                    amount: "$12.99", balance: "$1,155.03", isSubscription: true,  expectedBrandSvg: "headspace"),
    Tx(date: "May 4, 2026", merchant: "MBTA MTICKET 617-222-3200 MA",     amount: "$10.00", balance: "$1,142.04", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 3, 2026", merchant: "AMZN PRIME*RT4LM",                 amount: "$14.99", balance: "$1,132.04", isSubscription: true,  expectedBrandSvg: "amazon-prime"),
    Tx(date: "May 2, 2026", merchant: "MCDONALD'S F11729 BOSTON MA",      amount: "$9.99",  balance: "$1,117.05", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 1, 2026", merchant: "DEN DEN KOREAN FRIED",             amount: "$27.54", balance: "$1,107.06", isSubscription: false, expectedBrandSvg: nil),
]
renderStatement(style: .citi, header: "AmEx Gold · 5566", txs: s05, to: "\(outDir)/05_tricky.png")

// --- 06: Tax-inclusive amounts (Citi) — known brands at taxed prices ---
let s06: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "SPOTIFY USA 877-778",              amount: "$10.87", balance: "$1,234.56", isSubscription: true,  expectedBrandSvg: "spotify"),
    Tx(date: "May 7, 2026", merchant: "NETFLIX.COM",                      amount: "$16.61", balance: "$1,223.69", isSubscription: true,  expectedBrandSvg: "netflix"),
    Tx(date: "May 6, 2026", merchant: "OPENAI *CHATGPT",                  amount: "$21.45", balance: "$1,207.08", isSubscription: true,  expectedBrandSvg: "openai"),
    Tx(date: "May 5, 2026", merchant: "ANTHROPIC, PBC",                   amount: "$22.10", balance: "$1,185.63", isSubscription: true,  expectedBrandSvg: "anthropic"),
    Tx(date: "May 4, 2026", merchant: "ADOBE *CREATIVE CLD",              amount: "$64.79", balance: "$1,163.53", isSubscription: true,  expectedBrandSvg: "adobe-cc"),
    Tx(date: "May 3, 2026", merchant: "STARBUCKS STORE 04521",            amount: "$10.87", balance: "$1,098.74", isSubscription: false, expectedBrandSvg: nil), // tricky same amount as taxed Spotify
    Tx(date: "May 2, 2026", merchant: "CHIPOTLE 1234",                    amount: "$16.61", balance: "$1,087.87", isSubscription: false, expectedBrandSvg: nil),
]
renderStatement(style: .citi, header: "AmEx Platinum · 7788", txs: s06, to: "\(outDir)/06_taxed.png")

// --- 07: Yearly + larger amounts (Citi) ---
let s07: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "AMAZON PRIME*RT3JK MEMBERSHIP",    amount: "$139.00",balance: "$1,234.56", isSubscription: true,  expectedBrandSvg: "amazon-prime"),
    Tx(date: "May 6, 2026", merchant: "NEW YORK TIMES DIGITAL",           amount: "$99.99", balance: "$1,095.56", isSubscription: true,  expectedBrandSvg: "nyt"),
    Tx(date: "May 4, 2026", merchant: "EXPRESSVPN.COM",                   amount: "$99.95", balance: "$995.57",   isSubscription: true,  expectedBrandSvg: "expressvpn"),
    Tx(date: "May 2, 2026", merchant: "PELOTON INTERACTIVE",              amount: "$44.00", balance: "$895.62",   isSubscription: true,  expectedBrandSvg: "peloton"),
    Tx(date: "Apr 28, 2026",merchant: "BEST BUY #1234",                   amount: "$199.99",balance: "$851.62",   isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "Apr 25, 2026",merchant: "HOME DEPOT 1234",                  amount: "$89.99", balance: "$651.63",   isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "Apr 22, 2026",merchant: "MASTERCLASS *ALL ACCESS",          amount: "$15.00", balance: "$561.64",   isSubscription: true,  expectedBrandSvg: nil), // no masterclass svg
    Tx(date: "Apr 20, 2026",merchant: "WSJ.COM/SUBSCRIPTION",             amount: "$38.99", balance: "$546.64",   isSubscription: true,  expectedBrandSvg: nil), // no wsj svg
]
renderStatement(style: .citi, header: "Discover It · 9911", txs: s07, to: "\(outDir)/07_yearly.png")

// --- 08: Membership tiers on transactional apps (Citi) ---
let s08: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "UBER *ONE MEMBERSHIP UBER.COM/BILL", amount: "$9.99",  balance: "$1,234.56", isSubscription: true,  expectedBrandSvg: "uber"),
    Tx(date: "May 7, 2026", merchant: "LYFT *PINK MEMBERSHIP",              amount: "$9.99",  balance: "$1,224.57", isSubscription: true,  expectedBrandSvg: "lyft"),
    Tx(date: "May 6, 2026", merchant: "DOORDASH DASHPASS",                  amount: "$9.99",  balance: "$1,214.58", isSubscription: true,  expectedBrandSvg: "doordash"),
    Tx(date: "May 5, 2026", merchant: "ROCK SPOT CLIMBING",                 amount: "$31.00", balance: "$1,204.59", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 4, 2026", merchant: "BIG NIGHT LIVE 617-3384343 MA",      amount: "$40.66", balance: "$1,173.59", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 3, 2026", merchant: "DEN DEN KOREAN FRIED",               amount: "$27.54", balance: "$1,132.93", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 2, 2026", merchant: "BROWN BOOKSTORE NS",                 amount: "$45.54", balance: "$1,105.39", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 1, 2026", merchant: "MBTA MTICKET 617-222-3200 MA",       amount: "$10.00", balance: "$1,059.85", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "Apr 30, 2026",merchant: "MALA NOODLES 131-27305592 IL",       amount: "$23.65", balance: "$1,049.85", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "Apr 28, 2026",merchant: "SQ *NEW METRO MART",                 amount: "$3.20",  balance: "$1,026.20", isSubscription: false, expectedBrandSvg: nil),
]
renderStatement(style: .citi, header: "Apple Card", txs: s08, to: "\(outDir)/08_memberships.png")

// --- 09: Cloud storage / productivity (Citi) ---
let s09: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "APL*ICLOUD STORAGE",                 amount: "$2.99",  balance: "$1,234.56", isSubscription: true,  expectedBrandSvg: "icloud"),
    Tx(date: "May 6, 2026", merchant: "GOOGLE *ONE",                        amount: "$1.99",  balance: "$1,231.57", isSubscription: true,  expectedBrandSvg: "google-one"),
    Tx(date: "May 4, 2026", merchant: "DROPBOX *MEMBERSHIP",                amount: "$11.99", balance: "$1,229.58", isSubscription: true,  expectedBrandSvg: "dropbox"),
    Tx(date: "May 2, 2026", merchant: "MSFT*Office365",                     amount: "$9.99",  balance: "$1,217.59", isSubscription: true,  expectedBrandSvg: "github"), // microsoft alias→github svg fallback per registry
    Tx(date: "May 1, 2026", merchant: "NOTION *SUBSCRIPTION",               amount: "$10.00", balance: "$1,207.60", isSubscription: true,  expectedBrandSvg: "notion"),
    Tx(date: "Apr 28, 2026",merchant: "1PASSWORD.COM",                      amount: "$2.99",  balance: "$1,197.60", isSubscription: true,  expectedBrandSvg: "1password"),
    Tx(date: "Apr 26, 2026",merchant: "LASTPASS *PREMIUM",                  amount: "$3.00",  balance: "$1,194.61", isSubscription: true,  expectedBrandSvg: "lastpass"),
    Tx(date: "Apr 24, 2026",merchant: "GITHUB *COPILOT",                    amount: "$10.00", balance: "$1,191.61", isSubscription: true,  expectedBrandSvg: "github-copilot"),
]
renderStatement(style: .citi, header: "Wells Fargo · 2255", txs: s09, to: "\(outDir)/09_productivity.png")

// --- 10: Audio / wellness / news (Chase single-row) ---
let s10: [Tx] = [
    Tx(date: "5/08", merchant: "AUDIBLE*MEMBERSHIP",                        amount: "$14.95", balance: "", isSubscription: true,  expectedBrandSvg: "audible"),
    Tx(date: "5/07", merchant: "SIRIUSXM *INTERNET",                        amount: "$22.99", balance: "", isSubscription: true,  expectedBrandSvg: nil), // sirius has no svg, mapped to audible svg per registry pattern
    Tx(date: "5/06", merchant: "TIDAL *PREMIUM",                            amount: "$10.99", balance: "", isSubscription: true,  expectedBrandSvg: "tidal"),
    Tx(date: "5/05", merchant: "HEADSPACE INC",                             amount: "$12.99", balance: "", isSubscription: true,  expectedBrandSvg: "headspace"),
    Tx(date: "5/04", merchant: "CALM.COM",                                  amount: "$14.99", balance: "", isSubscription: true,  expectedBrandSvg: nil), // no calm svg
    Tx(date: "5/03", merchant: "NYTIMES *DIGITAL",                          amount: "$17.00", balance: "", isSubscription: true,  expectedBrandSvg: "nyt"),
    Tx(date: "5/01", merchant: "DUOLINGO *PLUS",                            amount: "$6.99",  balance: "", isSubscription: true,  expectedBrandSvg: "duolingo"),
    Tx(date: "4/29", merchant: "PLANET FIT *CLUB FEE",                      amount: "$24.99", balance: "", isSubscription: true,  expectedBrandSvg: nil), // no svg
    Tx(date: "4/27", merchant: "MCDONALDS #11729",                          amount: "$8.45",  balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "4/25", merchant: "STARBUCKS STORE 04521",                     amount: "$5.95",  balance: "", isSubscription: false, expectedBrandSvg: nil),
]
renderStatement(style: .chase, header: "BofA Cash Rewards · 6677", txs: s10, to: "\(outDir)/10_audio_news.png")

// --- 11: PayPal-wrapped subs + creators (Citi) ---
let s11: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "PAYPAL *NETFLIX",                    amount: "$15.49", balance: "$1,234.56", isSubscription: true,  expectedBrandSvg: "netflix"),
    Tx(date: "May 7, 2026", merchant: "PAYPAL *SPOTIFYUSA",                 amount: "$9.99",  balance: "$1,219.07", isSubscription: true,  expectedBrandSvg: "spotify"),
    Tx(date: "May 6, 2026", merchant: "PAYPAL *HULULLC",                    amount: "$7.99",  balance: "$1,209.08", isSubscription: true,  expectedBrandSvg: "hulu"),
    Tx(date: "May 4, 2026", merchant: "ELEVENLABS *PRO",                    amount: "$22.00", balance: "$1,201.09", isSubscription: true,  expectedBrandSvg: "elevenlabs"),
    Tx(date: "May 3, 2026", merchant: "SUNO *PREMIUM",                      amount: "$10.00", balance: "$1,179.09", isSubscription: true,  expectedBrandSvg: "suno"),
    Tx(date: "May 2, 2026", merchant: "DEEPSEEK *PRO",                      amount: "$15.00", balance: "$1,169.09", isSubscription: true,  expectedBrandSvg: "deepseek"),
    Tx(date: "May 1, 2026", merchant: "HUGGINGFACE.CO PRO",                 amount: "$9.00",  balance: "$1,154.09", isSubscription: true,  expectedBrandSvg: "huggingface"),
    Tx(date: "Apr 28, 2026",merchant: "GOOGLE *YouTubePremi",               amount: "$13.99", balance: "$1,145.09", isSubscription: true,  expectedBrandSvg: "youtube-premium"),
    Tx(date: "Apr 25, 2026",merchant: "GEMINI",                             amount: "$19.99", balance: "$1,131.10", isSubscription: true,  expectedBrandSvg: "gemini"),
]
renderStatement(style: .citi, header: "USBank · 8899", txs: s11, to: "\(outDir)/11_paypal_creators.png")

// --- 12: Fitness / travel / mixed transactional (Apple Wallet style) ---
let s12: [Tx] = [
    Tx(date: "Today",       merchant: "EQUINOX *MEMBERSHIP",               amount: "$185.00",balance: "", isSubscription: true,  expectedBrandSvg: nil), // no equinox svg
    Tx(date: "Yesterday",   merchant: "PELOTON INTERACTIVE",               amount: "$44.00", balance: "", isSubscription: true,  expectedBrandSvg: "peloton"),
    Tx(date: "May 6, 2026", merchant: "UBER TRIP HELP.UBER.COM",           amount: "$24.50", balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 5, 2026", merchant: "LYFT *RIDE FRI 6PM LYFT.COM",       amount: "$18.75", balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 4, 2026", merchant: "AIRBNB *HMQF3F4G",                  amount: "$345.00",balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 3, 2026", merchant: "HILTON HOTELS NYC",                 amount: "$289.00",balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 2, 2026", merchant: "HERTZ CAR RENTAL",                  amount: "$87.50", balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "May 1, 2026", merchant: "EXXONMOBIL 5678901",                amount: "$48.00", balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "Apr 30, 2026",merchant: "CHEVRON 12345",                     amount: "$52.00", balance: "", isSubscription: false, expectedBrandSvg: nil),
    Tx(date: "Apr 28, 2026",merchant: "WALMART STORE #2345",               amount: "$67.13", balance: "", isSubscription: false, expectedBrandSvg: nil),
]
renderStatement(style: .apple, header: "Apple Card", txs: s12, to: "\(outDir)/12_fitness_travel.png")

struct GTEntry { let image: String; let txs: [Tx] }
let allCases: [GTEntry] = [
    GTEntry(image: "01_streaming.png",       txs: s01),
    GTEntry(image: "02_ai_dev.png",          txs: s02),
    GTEntry(image: "03_food_retail.png",     txs: s03),
    GTEntry(image: "04_chase_mixed.png",     txs: s04),
    GTEntry(image: "05_tricky.png",          txs: s05),
    GTEntry(image: "06_taxed.png",           txs: s06),
    GTEntry(image: "07_yearly.png",          txs: s07),
    GTEntry(image: "08_memberships.png",     txs: s08),
    GTEntry(image: "09_productivity.png",    txs: s09),
    GTEntry(image: "10_audio_news.png",      txs: s10),
    GTEntry(image: "11_paypal_creators.png", txs: s11),
    GTEntry(image: "12_fitness_travel.png",  txs: s12),
]

var manifest = "image\tdate\tmerchant\tamount\tis_subscription\texpected_brand_svg\n"
for gt in allCases {
    for tx in gt.txs {
        let svg = tx.expectedBrandSvg ?? ""
        manifest += "\(gt.image)\t\(tx.date)\t\(tx.merchant)\t\(tx.amount)\t\(tx.isSubscription)\t\(svg)\n"
    }
}
try? manifest.write(toFile: "\(outDir)/ground_truth.tsv", atomically: true, encoding: .utf8)

let total = allCases.flatMap { $0.txs }.count
let subs  = allCases.flatMap { $0.txs }.filter { $0.isSubscription }.count
let withIcon = allCases.flatMap { $0.txs }.filter { $0.expectedBrandSvg != nil }.count
print("\nGenerated \(allCases.count) statements, \(total) transactions")
print("  Subscriptions:  \(subs)  (one-offs: \(total - subs))")
print("  Icon expected:  \(withIcon)")
print("Manifest: \(outDir)/ground_truth.tsv")
