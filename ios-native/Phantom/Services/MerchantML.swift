import Foundation
import NaturalLanguage
import CoreML

/// On-device ML classifier: takes a raw merchant string from OCR and predicts
/// whether it's a subscription or a one-off transactional charge.
///
/// Model trained via `tools/train-merchant-classifier.swift` (CreateML
/// MLTextClassifier on a curated dataset of ~350 labeled US merchant strings).
/// Output sits in `Resources/MerchantClassifier.mlmodelc` (12 KB).
///
/// At runtime ~1ms per prediction. Privacy: 100% on-device — no network.
enum MerchantML {
    enum Label: String {
        case subscription
        case transactional
    }

    private static let model: NLModel? = {
        guard let url = Bundle.main.url(forResource: "MerchantClassifier", withExtension: "mlmodelc") else {
            return nil
        }
        do {
            let mlmodel = try MLModel(contentsOf: url)
            return try NLModel(mlModel: mlmodel)
        } catch {
            return nil
        }
    }()

    /// Returns a probability that the merchant is a subscription (0..1).
    /// Higher = more likely subscription.
    static func subscriptionProbability(for merchant: String) -> Double {
        guard let model else { return 0.5 }  // unknown if model missing
        let scores = model.predictedLabelHypotheses(for: merchant, maximumCount: 2)
        return scores[Label.subscription.rawValue] ?? 0
    }

    /// Hard classification — returns true only when the model is >70% confident
    /// the merchant is transactional. Keeps recall high for actual subs.
    static func isLikelyTransactional(_ merchant: String) -> Bool {
        guard let model else { return false }
        let scores = model.predictedLabelHypotheses(for: merchant, maximumCount: 2)
        let txProb = scores[Label.transactional.rawValue] ?? 0
        return txProb >= 0.70
    }

    /// True if the model is available (always true on shipping builds; can be
    /// false during local development before training).
    static var isAvailable: Bool { model != nil }
}
