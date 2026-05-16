import Foundation
import Vision
import CoreGraphics
import ImageIO
import AppKit
import NaturalLanguage
import CoreML

// === OCR shim (Vision + CGImage) ===
enum OCR {
    struct Line {
        let text: String
        let confidence: Float
        let box: CGRect
    }

    static func recognizeText(cgImage: CGImage) throws -> [Line] {
        var result: [Line] = []
        var captureError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { req, err in
            defer { semaphore.signal() }
            if let err {
                captureError = err
                return
            }
            guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
            result = observations.compactMap { obs in
                guard let top = obs.topCandidates(1).first else { return nil }
                return Line(text: top.string, confidence: top.confidence, box: obs.boundingBox)
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])
        semaphore.wait()
        if let err = captureError { throw err }
        return result
    }
}

// === MerchantML stub ===
enum MerchantML {
    enum Label: String { case subscription, transactional }
    private static let model: NLModel? = {
        let url = URL(fileURLWithPath: "/Users/pinan/Desktop/Phantom/ios-native/Phantom/Resources/MerchantClassifier.mlmodelc")
        guard let mlmodel = try? MLModel(contentsOf: url) else { return nil }
        return try? NLModel(mlModel: mlmodel)
    }()
    static func subscriptionProbability(for merchant: String) -> Double {
        guard let model else { return 0.5 }
        return model.predictedLabelHypotheses(for: merchant, maximumCount: 2)[Label.subscription.rawValue] ?? 0
    }
    static func isLikelyTransactional(_ merchant: String) -> Bool {
        guard let model else { return false }
        let txProb = model.predictedLabelHypotheses(for: merchant, maximumCount: 2)[Label.transactional.rawValue] ?? 0
        return txProb >= 0.70
    }
    static var isAvailable: Bool { model != nil }
}

func loadCGImage(at path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

struct GroundTruth {
    let merchant: String
    let amount: Double
    let isSubscription: Bool
}

func parseGroundTruth(at path: String) -> [String: [GroundTruth]] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
    var result: [String: [GroundTruth]] = [:]
    let lines = content.split(separator: "\n").dropFirst()
    for line in lines {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 5 else { continue }
        let image = parts[0]
        let merchant = parts[2]
        let amtStr = parts[3].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let amount = Double(amtStr) else { continue }
        let isSub = parts[4] == "true"
        result[image, default: []].append(GroundTruth(merchant: merchant, amount: amount, isSubscription: isSub))
    }
    return result
}

func merchantMatches(_ a: String, _ b: String) -> Bool {
    let strip: (String) -> String = { s in s.lowercased().filter { $0.isLetter || $0.isNumber } }
    let sa = strip(a)
    let sb = strip(b)
    if sa == sb { return true }
    let shorter = sa.count < sb.count ? sa : sb
    let longer = sa.count < sb.count ? sb : sa
    if shorter.count >= 4 && longer.contains(shorter) { return true }
    if shorter.count >= 5 && shorter.hasPrefix(String(longer.prefix(min(longer.count, 5)))) { return true }
    return false
}

struct TestResult {
    let image: String
    let groundTruth: [GroundTruth]
    let detected: [ParsedTransaction]
    let detectedSubs: [ParsedTransaction]
    let truePositives: [(gt: GroundTruth, found: ParsedTransaction)]
    let falsePositives: [ParsedTransaction]
    let falseNegatives: [GroundTruth]
    let unrecognized: [GroundTruth]
}

func runOnImage(path: String, name: String, gt: [GroundTruth]?) -> TestResult? {
    guard let cgImage = loadCGImage(at: path) else { return nil }
    guard let lines = try? OCR.recognizeText(cgImage: cgImage) else { return nil }
    let parsed = TransactionParser.parse(lines: lines)
    let detectedSubs = parsed.filter { MerchantNormalizer.looksLikeSubscription(name: $0.merchant, amount: $0.amount) }

    guard let gt else {
        return TestResult(image: name, groundTruth: [], detected: parsed, detectedSubs: detectedSubs,
                          truePositives: [], falsePositives: [], falseNegatives: [], unrecognized: [])
    }

    var tps: [(gt: GroundTruth, found: ParsedTransaction)] = []
    var fps: [ParsedTransaction] = []
    var fns: [GroundTruth] = []
    var unrecognized: [GroundTruth] = []
    let detectedSubKeys = Set(detectedSubs.map { "\($0.merchant.lowercased())|\(Int($0.amount * 100))" })

    for gtEntry in gt {
        let matchedParsed = parsed.first { p in
            merchantMatches(p.merchant, gtEntry.merchant) && abs(p.amount - gtEntry.amount) < 0.51
        }
        guard let matched = matchedParsed else {
            unrecognized.append(gtEntry)
            continue
        }
        let key = "\(matched.merchant.lowercased())|\(Int(matched.amount * 100))"
        let flaggedAsSub = detectedSubKeys.contains(key)
        if gtEntry.isSubscription && flaggedAsSub {
            tps.append((gtEntry, matched))
        } else if gtEntry.isSubscription && !flaggedAsSub {
            fns.append(gtEntry)
        } else if !gtEntry.isSubscription && flaggedAsSub {
            fps.append(matched)
        }
    }

    return TestResult(image: name, groundTruth: gt, detected: parsed, detectedSubs: detectedSubs,
                      truePositives: tps, falsePositives: fps, falseNegatives: fns, unrecognized: unrecognized)
}

let originalDir = "/Users/pinan/Desktop/test"
let syntheticDir = "/Users/pinan/Desktop/test_synthetic"

let synthGT = parseGroundTruth(at: "\(syntheticDir)/ground_truth.tsv")

print("Phantom test harness")
print("MerchantML: \(MerchantML.isAvailable ? "loaded" : "MISSING")")
print("")

var totalGT = 0
var totalTP = 0
var totalFP = 0
var totalFN = 0
var totalUnrecognized = 0

print("============================================================")
print("SYNTHETIC TEST CASES")
print("============================================================")
let synthFiles = (try? FileManager.default.contentsOfDirectory(atPath: syntheticDir).sorted()) ?? []
for name in synthFiles where name.hasSuffix(".png") {
    let gt = synthGT[name] ?? []
    guard let r = runOnImage(path: "\(syntheticDir)/\(name)", name: name, gt: gt) else {
        print("[\(name)] LOAD FAILED")
        continue
    }
    let realSubs = gt.filter { $0.isSubscription }.count
    let oneOffs = gt.count - realSubs
    print("\n[\(name)] GT: \(realSubs) subs / \(oneOffs) one-offs · parsed \(r.detected.count) · flagged \(r.detectedSubs.count)")
    print("  TP: \(r.truePositives.count)  FP: \(r.falsePositives.count)  FN: \(r.falseNegatives.count)  unrecognized: \(r.unrecognized.count)")
    for fp in r.falsePositives {
        print("    FP -> \(fp.merchant) $\(fp.amount)  [raw: \(fp.rawRow)]")
    }
    for fn in r.falseNegatives {
        print("    FN -> \(fn.merchant) $\(fn.amount)")
    }
    for u in r.unrecognized {
        print("    ? -> \(u.merchant) $\(u.amount)")
    }
    if !r.unrecognized.isEmpty {
        print("    [actual parser output for \(name)]:")
        for p in r.detected { print("      • \(p.merchant) $\(p.amount)  raw: \(p.rawRow)") }
    }
    totalGT += gt.count
    totalTP += r.truePositives.count
    totalFP += r.falsePositives.count
    totalFN += r.falseNegatives.count
    totalUnrecognized += r.unrecognized.count
}

print("\n============================================================")
print("ORIGINAL TEST CASES (only UBER ONE $9.99 is a sub)")
print("============================================================")
let origFiles = (try? FileManager.default.contentsOfDirectory(atPath: originalDir).sorted()) ?? []
var originalDetectedSubs: [ParsedTransaction] = []
var originalAllParsed: [ParsedTransaction] = []
for name in origFiles where name.uppercased().hasSuffix(".PNG") {
    guard let r = runOnImage(path: "\(originalDir)/\(name)", name: name, gt: nil) else { continue }
    print("[\(name)] parsed=\(r.detected.count) flagged=\(r.detectedSubs.count)")
    for s in r.detectedSubs {
        print("    flagged -> \(s.merchant) $\(s.amount)")
    }
    originalDetectedSubs.append(contentsOf: r.detectedSubs)
    originalAllParsed.append(contentsOf: r.detected)
}

let realSubsInOrig = originalDetectedSubs.filter { t in
    let m = t.merchant.lowercased()
    return m.contains("uber") && m.contains("one") && abs(t.amount - 9.99) < 0.50
}
let fakesInOrig = originalDetectedSubs.filter { t in
    let m = t.merchant.lowercased()
    return !(m.contains("uber") && m.contains("one") && abs(t.amount - 9.99) < 0.50)
}
print("\nOriginal: \(realSubsInOrig.count) TP (UBER ONE expected), \(fakesInOrig.count) FP")
totalGT += originalAllParsed.count
totalTP += realSubsInOrig.count
totalFP += fakesInOrig.count
if realSubsInOrig.isEmpty { totalFN += 1 }

print("\n============================================================")
print("OVERALL")
print("============================================================")
let totalErrors = totalFP + totalFN + totalUnrecognized
let correct = totalGT - totalErrors
let accuracy = Double(correct) / Double(totalGT) * 100
print("Total evaluated:   \(totalGT)")
print("True positives:    \(totalTP)")
print("False positives:   \(totalFP)")
print("False negatives:   \(totalFN)")
print("Unrecognized:      \(totalUnrecognized)")
print("Errors:            \(totalErrors)")
print("Correct:           \(correct)")
print("Accuracy:          \(String(format: "%.2f%%", accuracy))")
print("Target:            99.00%+")
if accuracy >= 99.0 {
    print("\n[PASSED]")
} else {
    print("\n[BELOW TARGET]")
}
