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
        let sem = DispatchSemaphore(value: 0)
        let req = VNRecognizeTextRequest { r, _ in
            defer { sem.signal() }
            if let obs = r.results as? [VNRecognizedTextObservation] {
                result = obs.compactMap {
                    guard let t = $0.topCandidates(1).first else { return nil }
                    return Line(text: t.string, confidence: t.confidence, box: $0.boundingBox)
                }
            }
        }
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        req.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:]).perform([req])
        sem.wait()
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

struct GT {
    let merchant: String
    let amount: Double
    let isSub: Bool
    let expectedSvg: String?
}

func loadGT(_ path: String) -> [String: [GT]] {
    guard let s = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
    var result: [String: [GT]] = [:]
    for line in s.split(separator: "\n").dropFirst() {
        let p = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard p.count >= 6 else { continue }
        let img = p[0], merchant = p[2]
        let amt = Double(p[3].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
        let isSub = p[4] == "true"
        let svg = p[5].isEmpty ? nil : p[5]
        result[img, default: []].append(GT(merchant: merchant, amount: amt, isSub: isSub, expectedSvg: svg))
    }
    return result
}

func merchantMatches(_ a: String, _ b: String) -> Bool {
    let strip: (String) -> String = { $0.lowercased().filter { $0.isLetter } }
    let sa = strip(a), sb = strip(b)
    if sa == sb { return true }
    let short = sa.count < sb.count ? sa : sb
    let long  = sa.count < sb.count ? sb : sa
    if short.count >= 4 && long.contains(short) { return true }
    if short.count >= 6 && long.count >= 6,
       String(short.prefix(6)) == String(long.prefix(6)) { return true }
    return false
}

func loadCG(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

let dir = "/Users/pinan/Desktop/test_100"
let gtMap = loadGT("\(dir)/ground_truth.tsv")

print("Phantom 100-sample accuracy test")
print("MerchantML: \(MerchantML.isAvailable ? "loaded" : "MISSING")\n")

var total = 0, parsedOK = 0, amountOK = 0, classOK = 0, iconOK = 0, iconExp = 0
var subFails: [(String, GT, String)] = []
var iconFails: [(String, GT, String?)] = []

let files = (try? FileManager.default.contentsOfDirectory(atPath: dir).sorted()) ?? []
for name in files where name.hasSuffix(".png") {
    let gtRows = gtMap[name] ?? []
    guard let cg = loadCG("\(dir)/\(name)"), let lines = try? OCR.recognizeText(cgImage: cg) else { continue }
    let parsed = TransactionParser.parse(lines: lines)
    for g in gtRows {
        total += 1
        let p = parsed.first { pp in
            guard abs(pp.amount - g.amount) < 0.01 else { return false }
            if merchantMatches(pp.merchant, g.merchant) { return true }
            let idA = MerchantNormalizer.brandId(forNormalized: pp.merchant)
            let idB = MerchantNormalizer.brandId(forNormalized: g.merchant)
            return idA == idB && BrandRegistry.brand(for: idA, fallbackName: g.merchant) != nil
        }
        if p != nil { parsedOK += 1 }
        if let pp = p, abs(pp.amount - g.amount) < 0.01 { amountOK += 1 }
        let classified = p.map { MerchantNormalizer.looksLikeSubscription(name: $0.merchant, amount: $0.amount) } ?? false
        if classified == g.isSub {
            classOK += 1
        } else {
            let why = g.isSub ? "FN (expected sub, got non)" : "FP (expected non, got sub)"
            subFails.append((name, g, why))
        }
        if let exp = g.expectedSvg {
            iconExp += 1
            let actualSvg = p.flatMap { tx -> String? in
                let id = MerchantNormalizer.brandId(forNormalized: tx.merchant)
                return BrandRegistry.brand(for: id, fallbackName: tx.merchant)?.svgName
            }
            if actualSvg == exp { iconOK += 1 }
            else { iconFails.append((name, g, actualSvg)) }
        }
    }
}

print("==================================================")
print("ACCURACY (across \(total) ground-truth rows from 100 statements)")
print("==================================================")
let p1 = Double(parsedOK)/Double(total)*100
let p2 = Double(amountOK)/Double(total)*100
let p3 = Double(classOK)/Double(total)*100
let p4 = iconExp == 0 ? 100.0 : Double(iconOK)/Double(iconExp)*100
print(String(format: "  Parser extracted row:  %d/%d  = %.2f%%", parsedOK, total, p1))
print(String(format: "  Amount within $0.01:   %d/%d  = %.2f%%", amountOK, total, p2))
print(String(format: "  Sub classification:    %d/%d  = %.2f%%", classOK, total, p3))
print(String(format: "  Brand icon:            %d/%d  = %.2f%%", iconOK, iconExp, p4))

if !subFails.isEmpty {
    print("\nFirst 20 sub-classification fails:")
    for f in subFails.prefix(20) {
        print("  - [\(f.0)] \(f.1.merchant) $\(f.1.amount) — \(f.2)")
    }
    print("  ... \(subFails.count) total fails")
}
if !iconFails.isEmpty {
    print("\nFirst 20 icon fails:")
    for f in iconFails.prefix(20) {
        print("  - [\(f.0)] \(f.1.merchant) expected '\(f.1.expectedSvg!)' got '\(f.2 ?? "nil")'")
    }
    print("  ... \(iconFails.count) total fails")
}

let passed = p1 >= 95 && p2 >= 95 && p3 >= 95 && p4 >= 95
print("\nTarget ≥95% on every axis: \(passed ? "PASSED" : "FAILED")")
exit(passed ? 0 : 1)
