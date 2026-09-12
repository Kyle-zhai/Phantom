import Foundation
import Vision
import UIKit

/// On-device OCR using Apple Vision.
/// Recognizes text from a screenshot, returns line-by-line text + bounding boxes.
enum OCR {
    struct Line {
        let text: String
        let confidence: Float
        let box: CGRect
    }

    static func recognizeText(in image: UIImage) async throws -> [Line] {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Image has no CGImage"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            // Vision can signal a per-request failure through BOTH the request's
            // completion handler AND a throw from perform([...]). Route every
            // outcome through a single resume-once box so we never resume the
            // continuation twice (which traps: SWIFT_TASK_CONTINUATION_MISUSE).
            let resumer = ContinuationResumer(continuation)
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    resumer.resume(throwing: error)
                    return
                }
                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    resumer.resume(returning: [])
                    return
                }
                let lines: [Line] = results.compactMap { obs in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    return Line(text: top.string, confidence: top.confidence, box: obs.boundingBox)
                }
                resumer.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            // Bank descriptors are not English prose: without a vocabulary the
            // language model "corrects" APL*ITUNES into words. Seeding brand
            // names and statement vocabulary keeps recognition on-descriptor.
            request.customWords = customVocabulary
            request.revision = VNRecognizeTextRequestRevision3

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    resumer.resume(throwing: error)
                }
            }
        }
    }

    /// Brand names + the tokens banks print on recurring rows. Vision uses
    /// these to bias its language correction; they are not a whitelist.
    static let customVocabulary: [String] = {
        var words: Set<String> = [
            "RECURRING", "PURCHASE", "AUTHORIZED", "MEMBERSHIP", "SUBSCRIPTION",
            "SUBSCR", "RENEWAL", "BILL", "APL", "ITUNES", "AMZN", "MKTP", "PRIME",
            "GOOGL", "MSFT", "NFLX", "DASHPASS", "COPILOT", "ICLOUD", "DISNEYPLUS",
            "PARAMOUNTPLUS", "YOUTUBE", "OPENAI", "CHATGPT", "ANTHROPIC", "GITHUB",
            "NORDVPN", "EXPRESSVPN", "NYTIMES", "AUDIBLE", "KINDLE", "XFINITY",
            "COMCAST", "TMOBILE", "VERIZON", "SPECTRUM", "PELOTON", "HEADSPACE",
            "DUOLINGO", "MASTERCLASS", "1PASSWORD", "LASTPASS", "DROPBOX", "NOTION",
            "ADOBE", "CURSOR", "PERPLEXITY", "SIRIUSXM", "TIDAL", "PEACOCK", "HULU",
            "SPOTIFY", "NETFLIX", "CRUNCHYROLL", "STARZ", "PHILO", "FUBO", "SLING",
            "INSTACART", "GRUBHUB", "DOORDASH", "UBER", "LYFT", "WALMART",
        ]
        for name in BrandRegistry.allDisplayNames {
            for token in name.uppercased().split(separator: " ") where token.count >= 3 {
                words.insert(String(token))
            }
        }
        return Array(words)
    }()

    /// Resumes a throwing continuation at most once, guarded by a lock so the
    /// completion-handler thread and the perform() thread can't both fire.
    private final class ContinuationResumer: @unchecked Sendable {
        private let continuation: CheckedContinuation<[Line], Error>
        private let lock = NSLock()
        private var done = false

        init(_ continuation: CheckedContinuation<[Line], Error>) {
            self.continuation = continuation
        }

        func resume(returning value: [Line]) {
            lock.lock(); defer { lock.unlock() }
            guard !done else { return }
            done = true
            continuation.resume(returning: value)
        }

        func resume(throwing error: Error) {
            lock.lock(); defer { lock.unlock() }
            guard !done else { return }
            done = true
            continuation.resume(throwing: error)
        }
    }
}
