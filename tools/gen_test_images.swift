import Foundation
import AppKit

/// Synthetic bank-statement renderer. Produces PNGs that mimic real US
/// credit-card statement layouts so we can drive Vision OCR against ground
/// truth.
///
/// Each test image is paired with an explicit list of (merchant, amount,
/// isSubscription) so the test harness can compute accuracy.

struct Tx {
    let date: String
    let merchant: String   // includes city/state/phone like real statements
    let amount: String     // e.g. "$15.49"
    let balance: String    // running balance for Citi-style layouts
    let isSubscription: Bool
}

enum Style {
    case citi    // two-row: date+amount on top, merchant+balance below
    case chase   // single row: date | merchant | amount
    case apple   // clean one-row, no balance
}

func renderStatement(style: Style, txs: [Tx], to path: String) {
    let width: CGFloat = 900
    let topPad: CGFloat = 140

    let lineH: CGFloat
    switch style {
    case .citi:  lineH = 110
    case .chase: lineH = 70
    case .apple: lineH = 80
    }
    let height = topPad + lineH * CGFloat(txs.count) + 60

    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()

    NSColor.white.setFill()
    NSRect(origin: .zero, size: image.size).fill()

    // Header
    let headerStr: String
    switch style {
    case .citi:  headerStr = "Customized Cash · 7122"
    case .chase: headerStr = "Chase Freedom · 4488"
    case .apple: headerStr = "Apple Card"
    }
    let header = NSAttributedString(string: headerStr, attributes: [
        .font: NSFont.boldSystemFont(ofSize: 28),
        .foregroundColor: NSColor.black
    ])
    header.draw(at: NSPoint(x: 40, y: height - 60))

    let sub = NSAttributedString(string: "Statements · All Transactions", attributes: [
        .font: NSFont.systemFont(ofSize: 18),
        .foregroundColor: NSColor.darkGray
    ])
    sub.draw(at: NSPoint(x: 40, y: height - 90))

    var y = height - topPad

    for tx in txs {
        switch style {
        case .citi:
            // Row A: date (left) + amount (right, blue, large)
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 20),
                .foregroundColor: NSColor.darkGray
            ]
            NSAttributedString(string: tx.date, attributes: dateAttr).draw(at: NSPoint(x: 40, y: y))

            let amtAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 26),
                .foregroundColor: NSColor.systemBlue
            ]
            let amtStr = NSAttributedString(string: tx.amount, attributes: amtAttr)
            let amtSize = amtStr.size()
            amtStr.draw(at: NSPoint(x: width - 40 - amtSize.width, y: y))

            y -= 38

            // Row B: merchant (left) + balance (right, gray, smaller)
            let merAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 22),
                .foregroundColor: NSColor.black
            ]
            NSAttributedString(string: tx.merchant, attributes: merAttr).draw(at: NSPoint(x: 40, y: y))

            let balAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.darkGray
            ]
            let balStr = NSAttributedString(string: tx.balance, attributes: balAttr)
            let balSize = balStr.size()
            balStr.draw(at: NSPoint(x: width - 40 - balSize.width, y: y))

            y -= 72

        case .chase:
            // Single row: date | merchant | amount
            let attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 20),
                .foregroundColor: NSColor.black
            ]
            NSAttributedString(string: tx.date, attributes: attr).draw(at: NSPoint(x: 40, y: y))
            NSAttributedString(string: tx.merchant, attributes: attr).draw(at: NSPoint(x: 180, y: y))

            let amtAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 20),
                .foregroundColor: NSColor.black
            ]
            let amtStr = NSAttributedString(string: tx.amount, attributes: amtAttr)
            let amtSize = amtStr.size()
            amtStr.draw(at: NSPoint(x: width - 40 - amtSize.width, y: y))
            y -= lineH

        case .apple:
            // Apple Wallet style: merchant left, amount right (no date column visible per row)
            let merAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 22),
                .foregroundColor: NSColor.black
            ]
            NSAttributedString(string: tx.merchant, attributes: merAttr).draw(at: NSPoint(x: 40, y: y))

            let amtAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 22),
                .foregroundColor: NSColor.black
            ]
            let amtStr = NSAttributedString(string: tx.amount, attributes: amtAttr)
            let amtSize = amtStr.size()
            amtStr.draw(at: NSPoint(x: width - 40 - amtSize.width, y: y))

            y -= 28

            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.darkGray
            ]
            NSAttributedString(string: tx.date, attributes: dateAttr).draw(at: NSPoint(x: 40, y: y))
            y -= lineH - 28
        }
    }

    image.unlockFocus()

    if let tiff = image.tiffRepresentation,
       let bm = NSBitmapImageRep(data: tiff),
       let png = bm.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
        print("Wrote: \(path)")
    }
}

// === Test cases with ground truth ===
let outDir = "/Users/pinan/Desktop/test_synthetic"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// === Case 1: Streaming mix (Citi style) ===
// All subs — testing brand-match recall
let streamingTxs: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "NETFLIX.COM LOS GATOS CA",       amount: "$15.49", balance: "$1,235.49", isSubscription: true),
    Tx(date: "May 7, 2026", merchant: "SPOTIFY USA 877-778-9440 NY",    amount: "$9.99",  balance: "$1,220.00", isSubscription: true),
    Tx(date: "May 5, 2026", merchant: "HULU LLC SANTA MONICA CA",       amount: "$17.99", balance: "$1,210.01", isSubscription: true),
    Tx(date: "May 4, 2026", merchant: "DISNEYPLUS.COM BURBANK CA",      amount: "$10.99", balance: "$1,192.02", isSubscription: true),
    Tx(date: "May 2, 2026", merchant: "MAX*WB GAMES",                   amount: "$15.99", balance: "$1,181.03", isSubscription: true),
    Tx(date: "May 1, 2026", merchant: "GOOGLE *YouTubePremi",           amount: "$13.99", balance: "$1,165.04", isSubscription: true),
]
renderStatement(style: .citi, txs: streamingTxs, to: "\(outDir)/01_streaming_all_subs.png")

// === Case 2: AI / Dev tools (Citi style) ===
let aiTxs: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "OPENAI *CHATGPT",                amount: "$20.00", balance: "$1,234.56", isSubscription: true),
    Tx(date: "May 5, 2026", merchant: "ANTHROPIC, PBC",                 amount: "$20.00", balance: "$1,214.56", isSubscription: true),
    Tx(date: "May 3, 2026", merchant: "CURSOR.SH",                      amount: "$20.00", balance: "$1,194.56", isSubscription: true),
    Tx(date: "May 1, 2026", merchant: "PERPLEXITY AI INC",              amount: "$20.00", balance: "$1,174.56", isSubscription: true),
    Tx(date: "Apr 30, 2026", merchant: "GITHUB.COM SAN FRANCISCO",      amount: "$10.00", balance: "$1,154.56", isSubscription: true),
    Tx(date: "Apr 28, 2026", merchant: "ADOBE *CREATIVE CLD",           amount: "$59.99", balance: "$1,144.56", isSubscription: true),
]
renderStatement(style: .citi, txs: aiTxs, to: "\(outDir)/02_ai_dev_tools.png")

// === Case 3: Food / retail only — no subs (Citi style) ===
let foodTxs: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "STARBUCKS #41258 BOSTON MA",     amount: "$6.75",  balance: "$1,234.56", isSubscription: false),
    Tx(date: "May 7, 2026", merchant: "UBER *EATS HELP.UBER.COM",       amount: "$18.86", balance: "$1,227.81", isSubscription: false),
    Tx(date: "May 6, 2026", merchant: "LYFT *RIDE TUE 8AM LYFT.COM",    amount: "$14.99", balance: "$1,208.95", isSubscription: false),
    Tx(date: "May 5, 2026", merchant: "DOORDASH *MCDONALDS",            amount: "$24.99", balance: "$1,193.96", isSubscription: false),
    Tx(date: "May 4, 2026", merchant: "WHOLE FOODS MKT 12345 NY",       amount: "$87.42", balance: "$1,168.97", isSubscription: false),
    Tx(date: "May 3, 2026", merchant: "TRADER JOE'S #572 PROVIDENCE",   amount: "$34.18", balance: "$1,081.55", isSubscription: false),
    Tx(date: "May 2, 2026", merchant: "AMZN MKTPL*RT3JK",               amount: "$45.00", balance: "$1,047.37", isSubscription: false),
    Tx(date: "May 1, 2026", merchant: "TARGET 00012345",                amount: "$67.43", balance: "$1,002.37", isSubscription: false),
]
renderStatement(style: .citi, txs: foodTxs, to: "\(outDir)/03_food_retail_no_subs.png")

// === Case 4: Mixed (Chase single-line style) ===
let mixedTxs: [Tx] = [
    Tx(date: "5/08", merchant: "NETFLIX.COM",                           amount: "$22.99", balance: "", isSubscription: true),
    Tx(date: "5/07", merchant: "STARBUCKS STORE 04521",                 amount: "$5.95",  balance: "", isSubscription: false),
    Tx(date: "5/06", merchant: "APL*ITUNES.COM/BILL",                   amount: "$9.99",  balance: "", isSubscription: true),
    Tx(date: "5/05", merchant: "SHELL OIL 1234567",                     amount: "$45.00", balance: "", isSubscription: false),
    Tx(date: "5/04", merchant: "PAYPAL *SPOTIFYUSA",                    amount: "$11.99", balance: "", isSubscription: true),
    Tx(date: "5/03", merchant: "CHIPOTLE 1234",                         amount: "$14.50", balance: "", isSubscription: false),
    Tx(date: "5/02", merchant: "NORDVPN.COM",                           amount: "$11.95", balance: "", isSubscription: true),
    Tx(date: "5/01", merchant: "BEST BUY #1234",                        amount: "$199.99", balance: "", isSubscription: false),
]
renderStatement(style: .chase, txs: mixedTxs, to: "\(outDir)/04_mixed_chase_style.png")

// === Case 5: Tricky — round-dollar one-offs AND sub-tier amounts (Citi style) ===
let trickyTxs: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "1PASSWORD.COM",                  amount: "$2.99",  balance: "$1,234.56", isSubscription: true),
    Tx(date: "May 7, 2026", merchant: "ROCK SPOT CLIMBING",             amount: "$31.00", balance: "$1,231.57", isSubscription: false),
    Tx(date: "May 6, 2026", merchant: "BROWN BOOKSTORE NS",             amount: "$45.54", balance: "$1,200.57", isSubscription: false),
    Tx(date: "May 5, 2026", merchant: "DUOLINGO *PLUS",                 amount: "$6.99",  balance: "$1,155.03", isSubscription: true),
    Tx(date: "May 4, 2026", merchant: "MBTA MTICKET 617-222-3200 MA",   amount: "$10.00", balance: "$1,148.04", isSubscription: false),
    Tx(date: "May 3, 2026", merchant: "HEADSPACE INC",                  amount: "$12.99", balance: "$1,138.04", isSubscription: true),
    Tx(date: "May 2, 2026", merchant: "AMZN PRIME*RT4LM",               amount: "$14.99", balance: "$1,125.05", isSubscription: true),
    Tx(date: "May 1, 2026", merchant: "MCDONALD'S F11729 BOSTON MA",    amount: "$9.99",  balance: "$1,110.06", isSubscription: false),
]
renderStatement(style: .citi, txs: trickyTxs, to: "\(outDir)/05_tricky_mixed.png")

// === Case 6: Tax-inclusive amounts (real bank-statement reality) ===
let taxTxs: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "SPOTIFY USA 877-778",            amount: "$10.87", balance: "$1,234.56", isSubscription: true),  // NY 8.875% tax on $9.99
    Tx(date: "May 7, 2026", merchant: "NETFLIX.COM",                    amount: "$16.61", balance: "$1,223.69", isSubscription: true),  // CA 7.25% on $15.49
    Tx(date: "May 6, 2026", merchant: "OPENAI *CHATGPT",                amount: "$21.45", balance: "$1,207.08", isSubscription: true),  // CA 7.25% on $20
    Tx(date: "May 5, 2026", merchant: "ANTHROPIC, PBC",                 amount: "$22.10", balance: "$1,185.63", isSubscription: true),  // WA 10.5% on $20
    Tx(date: "May 4, 2026", merchant: "ADOBE *CREATIVE CLD",            amount: "$64.79", balance: "$1,163.53", isSubscription: true),  // CA tax on $59.99
    Tx(date: "May 3, 2026", merchant: "STARBUCKS STORE 04521",          amount: "$10.87", balance: "$1,098.74", isSubscription: false), // tricky: same price as taxed Spotify
    Tx(date: "May 2, 2026", merchant: "CHIPOTLE 1234",                  amount: "$16.61", balance: "$1,087.87", isSubscription: false), // tricky: same as taxed Netflix
]
renderStatement(style: .citi, txs: taxTxs, to: "\(outDir)/06_taxed_amounts.png")

// === Case 7: Yearly subscriptions ($X.99 patterns at higher tiers) ===
let yearlyTxs: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "AMAZON PRIME*RT3JK MEMBERSHIP",   amount: "$139.00", balance: "$1,234.56", isSubscription: true),
    Tx(date: "May 6, 2026", merchant: "NEW YORK TIMES DIGITAL",          amount: "$99.99",  balance: "$1,095.56", isSubscription: true),
    Tx(date: "May 4, 2026", merchant: "EXPRESSVPN.COM",                  amount: "$99.95",  balance: "$995.57",   isSubscription: true),
    Tx(date: "May 2, 2026", merchant: "PELOTON INTERACTIVE",             amount: "$44.00",  balance: "$895.62",   isSubscription: true),
    Tx(date: "Apr 28, 2026", merchant: "BEST BUY #1234",                  amount: "$199.99", balance: "$851.62",   isSubscription: false), // tricky: ends in .99
    Tx(date: "Apr 25, 2026", merchant: "HOME DEPOT 1234",                 amount: "$89.99",  balance: "$651.63",   isSubscription: false),
]
renderStatement(style: .citi, txs: yearlyTxs, to: "\(outDir)/07_yearly_subs.png")

// === Case 8: Edge cases — gym day passes, restaurants at sub-typical prices ===
let edgeTxs: [Tx] = [
    Tx(date: "May 8, 2026", merchant: "UBER *ONE MEMBERSHIP UBER.COM/BILL", amount: "$9.99",  balance: "$1,234.56", isSubscription: true),
    Tx(date: "May 7, 2026", merchant: "LYFT *PINK MEMBERSHIP",              amount: "$9.99",  balance: "$1,224.57", isSubscription: true),
    Tx(date: "May 6, 2026", merchant: "DOORDASH DASHPASS",                  amount: "$9.99",  balance: "$1,214.58", isSubscription: true),
    Tx(date: "May 5, 2026", merchant: "ROCK SPOT CLIMBING",                 amount: "$31.00", balance: "$1,204.59", isSubscription: false),  // gym day pass
    Tx(date: "May 4, 2026", merchant: "BIG NIGHT LIVE 617-3384343 MA",      amount: "$40.66", balance: "$1,173.59", isSubscription: false),  // concert
    Tx(date: "May 3, 2026", merchant: "DEN DEN KOREAN FRIED",               amount: "$27.54", balance: "$1,132.93", isSubscription: false),  // restaurant
    Tx(date: "May 2, 2026", merchant: "BROWN BOOKSTORE NS",                 amount: "$45.54", balance: "$1,105.39", isSubscription: false),  // bookstore
    Tx(date: "May 1, 2026", merchant: "MBTA MTICKET 617-222-3200 MA",       amount: "$10.00", balance: "$1,059.85", isSubscription: false),  // transit
    Tx(date: "Apr 30, 2026", merchant: "MALA NOODLES 131-27305592 IL",      amount: "$23.65", balance: "$1,049.85", isSubscription: false),  // restaurant
    Tx(date: "Apr 28, 2026", merchant: "SQ *NEW METRO MART",                amount: "$3.20",  balance: "$1,026.20", isSubscription: false),  // corner store
]
renderStatement(style: .citi, txs: edgeTxs, to: "\(outDir)/08_edge_cases.png")

// === Write ground truth manifest ===
struct GTEntry {
    let image: String
    let txs: [Tx]
}
let allCases: [GTEntry] = [
    GTEntry(image: "01_streaming_all_subs.png",      txs: streamingTxs),
    GTEntry(image: "02_ai_dev_tools.png",            txs: aiTxs),
    GTEntry(image: "03_food_retail_no_subs.png",     txs: foodTxs),
    GTEntry(image: "04_mixed_chase_style.png",       txs: mixedTxs),
    GTEntry(image: "05_tricky_mixed.png",            txs: trickyTxs),
    GTEntry(image: "06_taxed_amounts.png",           txs: taxTxs),
    GTEntry(image: "07_yearly_subs.png",             txs: yearlyTxs),
    GTEntry(image: "08_edge_cases.png",              txs: edgeTxs),
]

var manifest = "image,date,merchant,amount,is_subscription\n"
for gt in allCases {
    for tx in gt.txs {
        let csv = "\(gt.image)\t\(tx.date)\t\(tx.merchant)\t\(tx.amount)\t\(tx.isSubscription)\n"
        manifest += csv
    }
}
try? manifest.write(toFile: "\(outDir)/ground_truth.tsv", atomically: true, encoding: .utf8)

let total = allCases.flatMap { $0.txs }.count
let subs  = allCases.flatMap { $0.txs }.filter { $0.isSubscription }.count
print("Generated \(allCases.count) statements, \(total) transactions, \(subs) real subs, \(total - subs) one-offs")
print("Manifest: \(outDir)/ground_truth.tsv")
