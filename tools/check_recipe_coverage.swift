import Foundation

// Standalone CI-style sanity check.
//
// Two assertions:
//
// (1) Every id in the audited universe — the BrandRegistry logo table plus
//     every MockData subscription id — has either a matching Negotiation
//     recipe or an explicit, researched decision to use the generic fallback.
//     Catches the mock-id-mismatch bug class (e.g. MockData said
//     id: "sirius" but the recipe was registered under "sirius-xm" —
//     the lookup silently fell through to the generic offer, surfaced
//     visually but not by the build system).
//     The audited universe is deliberately narrower than every id the
//     taxonomy recognises: the generic script is a legitimate answer for the
//     long tail, so only the branded set is held to a researched decision.
//
// (2) Every Negotiation recipe id and alias key is reachable from a real
//     subscription id: a logo-table brand, a brand the taxonomy knows, a
//     MerchantNormalizer alias output, or a mock id. Catches recipe entries
//     that never get matched against any real subscription.
//
// Compile + run:
//   cp tools/check_recipe_coverage.swift /tmp/main.swift
//   swiftc -o /tmp/recipe_check /tmp/main.swift \
//     ios-native/Phantom/Services/{MerchantNormalizer,BrandRegistry,Negotiation,MockData,MerchantML}.swift \
//     ios-native/Phantom/Models/Models.swift \
//     ios-native/Phantom/Theme/Theme.swift \
//     -framework Foundation -framework SwiftUI
//   /tmp/recipe_check
//
// Exits 0 on success, 1 on mismatch.

// The researched "no offer exists" decisions live next to the recipes in
// Negotiation.swift so this script and NegotiationTests cannot drift apart.
// Adding an id there requires a documented search, not merely omitting a
// recipe: launch/research/negotiation-recipes-2026-09-12.md.
let intentionalGenericFallbackIds = Negotiation.researchedGenericFallbackIds

let mockIds = Set(MockData.subscriptions.map(\.id))
let allKnownIds = Set(BrandRegistry.byId.keys).union(mockIds)
let brandSpecificIds = allKnownIds.filter { Negotiation.hasBrandSpecificRecipe(for: $0) }

// Every id a real subscription can carry, so assertion (2) can prove no
// playbook is stranded behind a key nothing produces.
let reachableIds = Set(BrandRegistry.byId.keys)
    .union(BrandRegistry.knownBrandIds)
    .union(MerchantNormalizer.brandAliases.map { $0.2 })
    .union(mockIds)
let unreachableRecipeIds = Negotiation.brandSpecificRecipeIds.subtracting(reachableIds)

let uncoveredIds = allKnownIds.filter {
    !Negotiation.hasBrandSpecificRecipe(for: $0)
        && !intentionalGenericFallbackIds.contains($0)
}

let fallbackDrift = intentionalGenericFallbackIds.filter { id in
    !allKnownIds.contains(id) || Negotiation.hasBrandSpecificRecipe(for: id)
}

print("=== Recipe coverage check ===")
print("Audited ids (logo table + mocks): \(allKnownIds.count)")
print("Audited ids with a playbook: \(brandSpecificIds.count)")
print("Researched generic fallbacks: \(intentionalGenericFallbackIds.count)")
print("Recipe ids incl. aliases: \(Negotiation.brandSpecificRecipeIds.count)")
if uncoveredIds.isEmpty && fallbackDrift.isEmpty && unreachableRecipeIds.isEmpty {
    print("✅ Every audited id has a researched playbook or a researched generic fallback.")
    print("✅ Every recipe id is reachable from a real subscription id.")
    print("Researched generic fallbacks: \(intentionalGenericFallbackIds.sorted().joined(separator: ", "))")
    exit(0)
} else {
    if !uncoveredIds.isEmpty {
        print("❌ Audited ids WITHOUT a recipe or a researched fallback decision:")
        for id in uncoveredIds.sorted() { print("   - \(id)") }
    }
    if !fallbackDrift.isEmpty {
        print("❌ Researched fallback ids that no longer use the generic path:")
        for id in fallbackDrift.sorted() { print("   - \(id)") }
    }
    if !unreachableRecipeIds.isEmpty {
        print("❌ Recipe ids no real subscription can ever carry (typo or dead entry):")
        for id in unreachableRecipeIds.sorted() { print("   - \(id)") }
    }
    exit(1)
}
