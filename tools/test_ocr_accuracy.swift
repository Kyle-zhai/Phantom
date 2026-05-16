import Foundation
import Vision
import CoreGraphics
import ImageIO
import AppKit
import NaturalLanguage
import CoreML

enum OCR {
    struct Line { let text: String; let confidence: Float; let box: CGRect }
    static func recognizeText(cgImage: CGImage) throws -> [Line] {
        var result: [Line] = []
        var captureError: Error?
        let sem = DispatchSemaphore(value: 0)
        let req = VNRecognizeTextRequest { r, e in
            defer { sem.signal() }
            if let e { captureError = e; return }
            guard let obs = r.results as? [VNRecognizedTextObservation] else { return }
            result = obs.compactMap {
                guard let top = $0.topCandidates(1).first else { return nil }
                return Line(text: top.string, confidence: top.confidence, box: $0.boundingBox)
            }
        }
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        req.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:]).perform([req])
        sem.wait()
        if let e = captureError { throw e }
        return result
    }
}

enum MerchantML {
    enum Label: String { case subscription, transactional }
    private static let model: NLModel? = {
        let url = URL(fileURLWithPath: "/Users/pinan/Desktop/Phantom/ios-native/Phantom/Resources/MerchantClassifier.mlmodelc")
        guard let m = try? MLModel(contentsOf: url) else { return nil }
        return try? NLModel(mlModel: m)
    }()
    static func subscriptionProbability(for s: String) -> Double {
        guard let m = model else { return 0.5 }
        return m.predictedLabelHypotheses(for: s, maximumCount: 2)[Label.subscription.rawValue] ?? 0
    }
    static func isLikelyTransactional(_ s: String) -> Bool {
        guard let m = model else { return false }
        let p = m.predictedLabelHypotheses(for: s, maximumCount: 2)[Label.transactional.rawValue] ?? 0
        return p >= 0.70
    }
    static var isAvailable: Bool { model != nil }
}

func loadCGImage(at path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let s = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(s, 0, nil)
}

struct GroundTruth {
    let merchant: String
    let amount: Double
    let isSubscription: Bool
    let expectedBrandSvg: String?   // nil = no icon expected (letter avatar OK)
}

func parseGT(at path: String) -> [String: [GroundTruth]] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
    var result: [String: [GroundTruth]] = [:]
    let lines = content.split(separator: "\n").dropFirst()
    for line in lines {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 6 else { continue }
        let image = parts[0]
        let merchant = parts[2]
        let amtStr = parts[3].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let amount = Double(amtStr) else { continue }
        let isSub = parts[4] == "true"
        let svg = parts[5].isEmpty ? nil : parts[5]
        result[image, default: []].append(GroundTruth(merchant: merchant, amount: amount, isSubscription: isSub, expectedBrandSvg: svg))
    }
    return result
}

func merchantMatches(_ a: String, _ b: String) -> Bool {
    let strip: (String) -> String = { s in s.lowercased().filter { $0.isLetter } }
    let sa = strip(a), sb = strip(b)
    if sa == sb { return true }
    let sh = sa.count < sb.count ? sa : sb
    let lo = sa.count < sb.count ? sb : sa
    if sh.count >= 4 && lo.contains(sh) { return true }
    // Common 6-char prefix — catches "amazonprimemembership" vs
    // "amazonprimertjkmembership" after the *RT3JK is stripped.
    if sh.count >= 6 && lo.count >= 6 {
        if String(sh.prefix(6)) == String(lo.prefix(6)) { return true }
    }
    return false
}

struct RowReport {
    let gt: GroundTruth
    let parsed: ParsedTransaction?
    let classifiedAsSub: Bool
    let actualBrandSvg: String?
}

func runOnImage(path: String, gt: [GroundTruth]) -> [RowReport] {
    guard let cg = loadCGImage(at: path), let lines = try? OCR.recognizeText(cgImage: cg) else { return [] }
    let parsed = TransactionParser.parse(lines: lines)
    var out: [RowReport] = []
    for g in gt {
        // Require amount match AND (letter overlap OR same brandId), so an
        // amount collision between two unrelated rows can't cross-match. The
        // brandId path catches OCR misreads like "V0" → "VO" since both
        // resolve to brand id "v0" through the alias map.
        let p = parsed.first { pp in
            guard abs(pp.amount - g.amount) < 0.01 else { return false }
            if merchantMatches(pp.merchant, g.merchant) { return true }
            let idA = MerchantNormalizer.brandId(forNormalized: pp.merchant)
            let idB = MerchantNormalizer.brandId(forNormalized: g.merchant)
            return idA == idB && BrandRegistry.brand(for: idA, fallbackName: g.merchant) != nil
        }
        let classified = p.map { MerchantNormalizer.looksLikeSubscription(name: $0.merchant, amount: $0.amount) } ?? false
        let brandHit = p.flatMap { tx -> String? in
            let id = MerchantNormalizer.brandId(forNormalized: tx.merchant)
            return BrandRegistry.brand(for: id, fallbackName: tx.merchant)?.svgName
        }
        out.append(RowReport(gt: g, parsed: p, classifiedAsSub: classified, actualBrandSvg: brandHit))
    }
    return out
}

let synthDir = "/Users/pinan/Desktop/test_synthetic"
let origDir = "/Users/pinan/Desktop/test"
let gtMap = parseGT(at: "\(synthDir)/ground_truth.tsv")

print("Phantom 100-tx accuracy test")
print("MerchantML: \(MerchantML.isAvailable ? "loaded" : "MISSING")\n")

var allReports: [(image: String, reports: [RowReport])] = []
let synthFiles = (try? FileManager.default.contentsOfDirectory(atPath: synthDir).sorted()) ?? []
for name in synthFiles where name.hasSuffix(".png") {
    let gt = gtMap[name] ?? []
    let reports = runOnImage(path: "\(synthDir)/\(name)", gt: gt)
    allReports.append((name, reports))
}

// === Per-axis accuracy ===
var totalRows = 0
var subClassCorrect = 0
var amountCorrect = 0
var iconCorrect = 0
var iconExpected = 0
var parsedCorrect = 0

var subFails: [(image: String, gt: GroundTruth, why: String)] = []
var iconFails: [(image: String, gt: GroundTruth, gotSvg: String?)] = []

for (image, reports) in allReports {
    for r in reports {
        totalRows += 1
        // Parsed at all
        if r.parsed != nil { parsedCorrect += 1 }
        // Amount match
        if let p = r.parsed, abs(p.amount - r.gt.amount) < 0.01 { amountCorrect += 1 }
        // Sub classification
        if r.classifiedAsSub == r.gt.isSubscription {
            subClassCorrect += 1
        } else {
            let why = r.gt.isSubscription
                ? "missed (FN): expected sub, got non-sub"
                : "false positive: expected non-sub, got sub"
            subFails.append((image, r.gt, why))
        }
        // Icon (only check when GT expects one)
        if let expected = r.gt.expectedBrandSvg {
            iconExpected += 1
            if r.actualBrandSvg == expected {
                iconCorrect += 1
            } else {
                iconFails.append((image, r.gt, r.actualBrandSvg))
            }
        }
    }
}

print("Per-image breakdown:")
for (image, reports) in allReports {
    let subs = reports.filter { $0.gt.isSubscription }.count
    let nonSubs = reports.count - subs
    let correct = reports.filter { $0.classifiedAsSub == $0.gt.isSubscription }.count
    print("  \(image)  GT \(subs)sub/\(nonSubs)one  → classify \(correct)/\(reports.count)")
}

print("")
print("==================================================")
print("ACCURACY (across \(totalRows) ground-truth rows)")
print("==================================================")
let parsedPct  = Double(parsedCorrect) / Double(totalRows) * 100
let amtPct     = Double(amountCorrect) / Double(totalRows) * 100
let classPct   = Double(subClassCorrect) / Double(totalRows) * 100
let iconPct: Double = iconExpected == 0 ? 100.0 : Double(iconCorrect) / Double(iconExpected) * 100

print(String(format: "  Parser extracted row:  %d/%d  = %.2f%%", parsedCorrect, totalRows, parsedPct))
print(String(format: "  Amount within $0.01:   %d/%d  = %.2f%%", amountCorrect, totalRows, amtPct))
print(String(format: "  Sub classification:    %d/%d  = %.2f%%", subClassCorrect, totalRows, classPct))
print(String(format: "  Brand icon (vs GT):    %d/%d  = %.2f%%", iconCorrect, iconExpected, iconPct))

if !subFails.isEmpty {
    print("\nSub-classification fails:")
    for f in subFails { print("  - [\(f.image)] \(f.gt.merchant) $\(f.gt.amount) — \(f.why)") }
}
if !iconFails.isEmpty {
    print("\nIcon fails:")
    for f in iconFails { print("  - [\(f.image)] \(f.gt.merchant) expected '\(f.gt.expectedBrandSvg!)' got '\(f.gotSvg ?? "nil")'") }
}

let allOver95 = parsedPct >= 95 && amtPct >= 95 && classPct >= 95 && iconPct >= 95
print("\nTarget 95%+ on every axis: \(allOver95 ? "PASSED" : "FAILED")")
exit(allOver95 ? 0 : 1)
