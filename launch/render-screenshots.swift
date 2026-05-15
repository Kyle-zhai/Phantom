// Renders App Store marketing screenshots: brand headline on top,
// scaled-down screenshot (with rounded corners + drop shadow) floating
// below on a solid Phantom-black background. No content of the actual app
// is covered.
//
// Output: launch/store/screenshots-final/01..08.png (each 1320×2868, 6.9" spec)
//
// Run from project root:  swift launch/render-screenshots.swift
import AppKit
import CoreGraphics
import Foundation

let inputDir = "launch/store/screenshots-raw"
let outputDir = "launch/store/screenshots-final"

let headlines: [(file: String, top: String, sub: String)] = [
    ("01-welcome.png",  "Find the money\nyou're losing.",     "The average American pays for 4.5 subs they never use."),
    ("02-radar.png",    "Every subscription,\nfound.",         "Snap your bank app. OCR runs on-device — nothing leaves your phone."),
    ("03-detail.png",   "Why it's a zombie.\nQuantified.",     "5-factor score from 0–100. Cancel the ones above 80."),
    ("04-alerts.png",   "Notified 7 days\nbefore any price hike.", "We watch 50+ services. You hear about it before the bill."),
    ("05-negotiate.png","Save without\ncancelling.",            "Up to $1,400/yr in retention discounts most people never ask for."),
    ("06-script.png",   "Proven retention\nscripts.",            "Tap to copy. 87% success rate on SiriusXM. Read it almost verbatim."),
    ("07-dispute.png",  "EFTA-compliant\ndispute letters.",      "One tap = a legal letter for wrongful charges and forgotten trials."),
    ("08-paywall.png",  "$3.99 a month.\nSaves you $47.",        "Phantom Pro pays for itself the first time it catches a forgotten sub."),
]

let canvasW: CGFloat = 1320
let canvasH: CGFloat = 2868
let topPanelH: CGFloat = 700           // headline area (text + brand mark)
let screenshotGapTop: CGFloat = 40
let screenshotMarginBottom: CGFloat = 80
let screenshotCornerRadius: CGFloat = 56

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
        width: Int(canvasW),
        height: Int(canvasH),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }

    // Solid Phantom-black background
    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))

    // ----- Top: brand mark + headline + sub -----
    // (CoreGraphics uses bottom-left origin; "top of canvas" = high y)

    // Ghost mark in top-left of canvas
    drawPhantomMark(ctx: ctx, center: CGPoint(x: 110, y: canvasH - 130), size: 78)

    // Headline (huge, bold)
    let topFont = NSFont.systemFont(ofSize: 96, weight: .black)
    let subFont = NSFont.systemFont(ofSize: 36, weight: .regular)
    let topAttrs: [NSAttributedString.Key: Any] = [
        .font: topFont,
        .foregroundColor: NSColor.white,
        .kern: -1.5,
    ]
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(white: 1, alpha: 0.65),
    ]
    drawText(
        ctx: ctx,
        text: item.top,
        attrs: topAttrs,
        rect: CGRect(x: 80, y: canvasH - 470, width: canvasW - 160, height: 250),
        align: .left,
        lineSpacing: -10
    )
    drawText(
        ctx: ctx,
        text: item.sub,
        attrs: subAttrs,
        rect: CGRect(x: 80, y: canvasH - 620, width: canvasW - 160, height: 140),
        align: .left,
        lineSpacing: 6
    )

    // ----- Bottom: scaled screenshot with rounded corners + shadow -----
    // Compute target size that fits below the headline area
    let availableH = canvasH - topPanelH - screenshotGapTop - screenshotMarginBottom
    let originalRatio = CGFloat(originalCG.width) / CGFloat(originalCG.height)
    let screenshotH = availableH
    let screenshotW = screenshotH * originalRatio
    let screenshotX = (canvasW - screenshotW) / 2
    let screenshotY = screenshotMarginBottom
    let screenshotRect = CGRect(x: screenshotX, y: screenshotY, width: screenshotW, height: screenshotH)

    // Soft drop shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -20),
        blur: 60,
        color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.12)
    )

    // Clip to rounded rect (this clips the screenshot AND the shadow draws around it)
    let roundedPath = CGPath(
        roundedRect: screenshotRect,
        cornerWidth: screenshotCornerRadius,
        cornerHeight: screenshotCornerRadius,
        transform: nil
    )

    // Fill the rounded shape first (makes the shadow render)
    ctx.addPath(roundedPath)
    ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    ctx.fillPath()
    ctx.restoreGState()

    // Now draw the actual screenshot, clipped to the same rounded shape
    ctx.saveGState()
    ctx.addPath(roundedPath)
    ctx.clip()
    ctx.draw(originalCG, in: screenshotRect)
    ctx.restoreGState()

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

    let prev = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    attributedString.draw(in: rect)
    NSGraphicsContext.current = prev
}

func drawPhantomMark(ctx: CGContext, center: CGPoint, size: CGFloat) {
    // White rounded square base
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    let bgRect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: size * 0.22, cornerHeight: size * 0.22, transform: nil)
    ctx.addPath(bgPath)
    ctx.fillPath()

    // Black ghost inside
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
