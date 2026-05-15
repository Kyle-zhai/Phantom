// Adds Phantom-branded marketing overlays to App Store screenshots.
//
// Output: launch/store/screenshots-final/01..08.png (each 1320×2868, App Store 6.9" spec)
//
// Run from project root:  swift launch/render-screenshots.swift
import AppKit
import CoreGraphics
import Foundation

let inputDir = "launch/store/screenshots-69inch"
let outputDir = "launch/store/screenshots-final"

// Headline per screenshot. Top line = bold hero, bottom line = sub.
let headlines: [(file: String, top: String, sub: String)] = [
    ("01-welcome.png",          "$564 a year, gone\nwithout a fight.",  "The average American pays for 4.5 subs they never use. Phantom finds them."),
    ("02-radar.png",            "Every subscription,\nfound.",          "Snap your bank app. OCR runs on-device — nothing leaves your phone."),
    ("03-detail-peacock.png",   "Why it's a zombie.\nQuantified.",      "5-factor score from 0-100. Cancel the ones above 80."),
    ("04-alerts.png",           "Notified 7 days\nbefore any price hike.", "We watch 50+ services. You hear about it before the bill."),
    ("05-negotiate.png",        "Save without\ncancelling.",             "Up to $1,400/yr in retention discounts you didn't know to ask for."),
    ("06-negotiate-sirius.png", "Proven retention\nscripts.",            "Tap to copy. Read it almost verbatim. 87% success on SiriusXM."),
    ("07-dispute-form.png",     "EFTA-compliant\ndispute letters.",      "One tap = a legal letter for wrongful charges and forgotten trials."),
    ("08-paywall.png",          "$3.99 a month.\nSaves you $47.",        "Phantom Pro pays for itself the first time it catches a forgotten sub."),
]

let canvasSize: CGFloat = 1320  // width
let canvasHeight: CGFloat = 2868
let topPanelHeight: CGFloat = 880  // height of the black marketing band at top — covers status bar + any in-app banners

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for (idx, item) in headlines.enumerated() {
    let inputURL = URL(fileURLWithPath: "\(inputDir)/\(item.file)")
    let outputURL = URL(fileURLWithPath: "\(outputDir)/\(item.file)")

    guard let original = NSImage(contentsOf: inputURL),
          let originalCG = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("⚠️ Skipping \(item.file): could not load")
        continue
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(canvasSize),
        height: Int(canvasHeight),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }

    // 1. Draw original screenshot full-size (it's already 1320×2868)
    ctx.draw(originalCG, in: CGRect(x: 0, y: 0, width: canvasSize, height: canvasHeight))

    // 2. Black panel over top portion (covers status bar + app header)
    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
    let panelRect = CGRect(x: 0, y: canvasHeight - topPanelHeight, width: canvasSize, height: topPanelHeight)
    ctx.fill(panelRect)

    // 3. Subtle gradient bottom edge of panel (smooth transition)
    let gradColors = [
        CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        CGColor(red: 0, green: 0, blue: 0, alpha: 0),
    ] as CFArray
    if let grad = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: [0, 1]) {
        let gradTop = canvasHeight - topPanelHeight
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: canvasSize / 2, y: gradTop),
            end: CGPoint(x: canvasSize / 2, y: gradTop - 80),
            options: []
        )
    }

    // 4. Phantom mark (small ghost) in top-left of panel
    drawPhantomMark(ctx: ctx, center: CGPoint(x: 110, y: canvasHeight - 110), size: 70)

    // 5. Headline text — top line BIG, sub line smaller
    let topFont = NSFont.systemFont(ofSize: 110, weight: .black)
    let subFont = NSFont.systemFont(ofSize: 38, weight: .regular)

    let topAttrs: [NSAttributedString.Key: Any] = [
        .font: topFont,
        .foregroundColor: NSColor.white,
        .kern: -2.0,
    ]
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(white: 1, alpha: 0.7),
    ]

    drawText(
        ctx: ctx,
        text: item.top,
        attrs: topAttrs,
        rect: CGRect(x: 80, y: canvasHeight - 560, width: canvasSize - 160, height: 280),
        align: .left,
        lineSpacing: -8
    )
    drawText(
        ctx: ctx,
        text: item.sub,
        attrs: subAttrs,
        rect: CGRect(x: 80, y: canvasHeight - 760, width: canvasSize - 160, height: 160),
        align: .left,
        lineSpacing: 6
    )

    // Save
    guard let image = ctx.makeImage() else { continue }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else { continue }
    try? data.write(to: outputURL)
    print("✅ \(idx + 1)/\(headlines.count)  \(item.file)  (\(data.count / 1024) KB)")
}

print("\nDone. Final screenshots in \(outputDir)/")

// MARK: - Helpers

func drawText(
    ctx: CGContext,
    text: String,
    attrs: [NSAttributedString.Key: Any],
    rect: CGRect,
    align: NSTextAlignment,
    lineSpacing: CGFloat
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineSpacing = lineSpacing
    var attrs = attrs
    attrs[.paragraphStyle] = paragraph

    let attributedString = NSAttributedString(string: text, attributes: attrs)

    // Use NSGraphicsContext to draw NSAttributedString
    let prev = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    attributedString.draw(in: rect)
    NSGraphicsContext.current = prev
}

func drawPhantomMark(ctx: CGContext, center: CGPoint, size: CGFloat) {
    // Black rounded square
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    let bgRect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: size * 0.22, cornerHeight: size * 0.22, transform: nil)
    ctx.addPath(bgPath)
    ctx.fillPath()

    // Ghost in black (inverted: white square, black ghost)
    let ghostW = size * 0.6
    let ghostH = size * 0.65
    let topR = ghostW / 2
    let leftX = center.x - ghostW / 2
    let rightX = center.x + ghostW / 2
    let topY = center.y + ghostH / 2
    let shoulderY = topY - topR
    let bottomY = center.y - ghostH / 2
    let humpCount = 4
    let humpW = ghostW / CGFloat(humpCount)
    let humpDepth = size * 0.04
    let dx = topR * 0.5523

    let path = CGMutablePath()
    path.move(to: CGPoint(x: leftX, y: bottomY))
    path.addLine(to: CGPoint(x: leftX, y: shoulderY))
    path.addCurve(
        to: CGPoint(x: center.x, y: topY),
        control1: CGPoint(x: leftX, y: shoulderY + dx),
        control2: CGPoint(x: center.x - dx, y: topY)
    )
    path.addCurve(
        to: CGPoint(x: rightX, y: shoulderY),
        control1: CGPoint(x: center.x + dx, y: topY),
        control2: CGPoint(x: rightX, y: shoulderY + dx)
    )
    path.addLine(to: CGPoint(x: rightX, y: bottomY))
    for i in 0..<humpCount {
        let segR = rightX - CGFloat(i) * humpW
        let segL = segR - humpW
        let mid = (segR + segL) / 2
        path.addQuadCurve(to: CGPoint(x: segL, y: bottomY), control: CGPoint(x: mid, y: bottomY + humpDepth))
    }
    path.closeSubpath()
    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
    ctx.addPath(path)
    ctx.fillPath()
}
