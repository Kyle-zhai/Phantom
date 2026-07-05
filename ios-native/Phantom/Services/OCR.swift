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
