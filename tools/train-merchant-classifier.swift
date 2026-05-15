// Trains a text classifier on training-data.json and emits
// MerchantClassifier.mlmodel + MerchantClassifier.mlmodelc (compiled,
// ready to ship inside the iOS app bundle).
//
// Usage:  swift tools/train-merchant-classifier.swift
//
// Output:
//   ios-native/Phantom/Resources/MerchantClassifier.mlmodel
//   ios-native/Phantom/Resources/MerchantClassifier.mlmodelc/   (folder)
//
// Re-run whenever you tweak training-data.json. The compiled .mlmodelc
// is what gets loaded at runtime by `NLModel(contentsOf:)`.
import CreateML
import Foundation
import CoreML

let toolsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let dataURL = toolsDir.appendingPathComponent("training-data.json")
let outputDir = toolsDir.deletingLastPathComponent()
    .appendingPathComponent("ios-native/Phantom/Resources")
let modelURL = outputDir.appendingPathComponent("MerchantClassifier.mlmodel")
let compiledURL = outputDir.appendingPathComponent("MerchantClassifier.mlmodelc")

try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("→ Loading training data from \(dataURL.path)")
let raw = try Data(contentsOf: dataURL)
struct Example: Decodable { let text: String; let label: String }
let examples = try JSONDecoder().decode([Example].self, from: raw)
print("  loaded \(examples.count) labeled examples")

// CreateML's MLDataTable init from dictionary needs [String: any MLDataValueConvertible]
// — easiest is to dump to a temp JSON file in the right shape and load it back.
let tempJSON = FileManager.default.temporaryDirectory.appendingPathComponent("phantom-training.json")
let payload = examples.map { ["text": $0.text, "label": $0.label] }
try JSONSerialization.data(withJSONObject: payload, options: []).write(to: tempJSON)
let table = try MLDataTable(contentsOf: tempJSON)
print("  data table loaded: \(table.size.rows) rows")

let (train, test) = table.randomSplit(by: 0.8, seed: 42)

print("→ Training MLTextClassifier (this takes ~30 seconds)…")
let classifier = try MLTextClassifier(
    trainingData: train,
    textColumn: "text",
    labelColumn: "label"
)

// Evaluate
let trainEval = classifier.evaluation(on: train, textColumn: "text", labelColumn: "label")
let testEval = classifier.evaluation(on: test, textColumn: "text", labelColumn: "label")
print("  train accuracy: \(String(format: "%.1f", (1 - trainEval.classificationError) * 100))%")
print("  test  accuracy: \(String(format: "%.1f", (1 - testEval.classificationError) * 100))%")

// Save .mlmodel
print("→ Writing \(modelURL.path)")
try classifier.write(
    to: modelURL,
    metadata: MLModelMetadata(
        author: "Phantom",
        shortDescription: "Classifies a US merchant string as a recurring subscription vs one-off transactional charge.",
        version: "1.0"
    )
)

// Compile .mlmodelc (what runtime actually loads)
print("→ Compiling to \(compiledURL.path)")
let intermediateCompiledURL = try MLModel.compileModel(at: modelURL)

// Replace existing compiled output
try? FileManager.default.removeItem(at: compiledURL)
try FileManager.default.copyItem(at: intermediateCompiledURL, to: compiledURL)

// Sanity test against a few real merchants
print("→ Sanity check:")
let sanity = [
    "STARBUCKS STORE 6128",
    "SP*NETFLIX",
    "UBER *TRIP",
    "ADOBE *CREATIVE CLOUD",
    "TST*JOE'S DINER",
    "AMZN PRIME *",
    "WALMART STORE 0021",
    "SP*ROBLOX",
]
let loadedModel = try MLModel(contentsOf: compiledURL)
let nlmodel = try NLModel(mlModel: loadedModel)
for merchant in sanity {
    let label = nlmodel.predictedLabel(for: merchant) ?? "?"
    print("    \(merchant.padding(toLength: 32, withPad: " ", startingAt: 0)) → \(label)")
}

print("\n✅ Done. Model written to:")
print("   \(compiledURL.path)")
print("\nNext: rebuild the Xcode project. The .mlmodelc is auto-bundled via")
print("project.yml resources path.")

import NaturalLanguage
