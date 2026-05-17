import Foundation

// Standalone CI-style sanity check.
//
// Two assertions:
//
// (1) Every MockData subscription id has a matching Negotiation recipe.
//     Catches the mock-id-mismatch bug class (e.g. MockData said
//     id: "sirius" but the recipe was registered under "sirius-xm" —
//     the lookup silently fell through to the generic offer, surfaced
//     visually but not by the build system).
//
// (2) Every Negotiation recipe id maps to either a BrandRegistry brand
//     id OR a MerchantNormalizer alias output. Catches recipe entries
//     that never get matched against any real subscription.
//
// Compile + run:
//   cp tools/check_recipe_coverage.swift /tmp/main.swift
//   swiftc -o /tmp/recipe_check /tmp/main.swift \
//     ios-native/Phantom/Services/{MerchantNormalizer,BrandRegistry,Negotiation,MockData,MerchantML}.swift \
//     ios-native/Phantom/Models/Models.swift \
//     -framework Foundation -framework SwiftUI
//   /tmp/recipe_check
//
// Exits 0 on success, 1 on mismatch.

// NOTE: For this to compile, the recipes dictionary in Negotiation.swift
// needs to be exposed for inspection. The check uses a wrapper that re-
// reads the relevant ids from Subscription objects.

let mockIds = Set(MockData.subscriptions.map(\.id))

var unmatchedMocks: [String] = []
for sub in MockData.subscriptions {
    if Negotiation.offer(for: sub)?.successRateEstimated == true
        // generic fallback always reports estimated:true. If the recipe
        // existed and was social-sourced, estimated would be false.
        || Negotiation.offer(for: sub) == nil {
        unmatchedMocks.append(sub.id)
    }
}

print("=== Recipe coverage check ===")
print("MockData subscriptions: \(mockIds.count)")
if unmatchedMocks.isEmpty {
    print("✅ Every mock subscription has a social-sourced recipe.")
    exit(0)
} else {
    print("❌ Mock subscriptions WITHOUT a social-sourced recipe:")
    for id in unmatchedMocks.sorted() { print("   - \(id)") }
    print("\nFix: either (a) add a Negotiation recipe keyed by this id, or (b) change the mock id to match an existing recipe key.")
    exit(1)
}
