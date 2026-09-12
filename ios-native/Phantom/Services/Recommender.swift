import Foundation

/// Turns the user's own subscription list into recommendations — entirely on
/// device, from the static catalog, with a stated reason for every item.
///
/// Three layers:
///   1. `needs`   — what they demonstrably pay for, grouped by `Kind`, with spend.
///   2. `replacements` — for each sub, like-for-like options that are free,
///      cheaper, already in a bundle, or simply better (catalog `edge`).
///   3. `suggestions`  — complementary apps implied by the pattern (fitness sub
///      but no food log, two AI assistants but no notes app…), from catalog rules.
///
/// No affiliate links, no ranking by payment — the catalog is hand-curated and
/// every entry carries its own `why`.
enum Recommender {
    struct Need: Identifiable, Hashable {
        let kind: Kind
        let subs: [Subscription]
        var id: String { kind.rawValue }
        var count: Int { subs.count }
        var monthly: Double { subs.reduce(0) { $0 + $1.monthlyAmount } }
    }

    struct Replacement: Identifiable, Hashable {
        let sub: Subscription
        let options: [AlternativesCatalog.Alternative]
        var id: String { sub.id }
        /// Best monthly saving on offer among the options (0 when none is cheaper).
        var bestSavingMonthly: Double {
            options.compactMap { $0.priceMonthly }.map { max(0, sub.monthlyAmount - $0) }.max() ?? 0
        }
    }

    struct SuggestionMatch: Identifiable, Hashable {
        let rule: AlternativesCatalog.Suggestion
        /// The user's subs that triggered the rule (≤ 3, highest spend first).
        let because: [Subscription]
        let score: Int
        var id: String { rule.id }
        var apps: [AlternativesCatalog.SuggestedApp] { rule.apps }
    }

    struct Recommendations {
        var needs: [Need]
        var tags: [String]
        var replacements: [Replacement]
        var suggestions: [SuggestionMatch]

        static let empty = Recommendations(needs: [], tags: [], replacements: [], suggestions: [])
        var isEmpty: Bool { needs.isEmpty && replacements.isEmpty && suggestions.isEmpty }
    }

    static func build(subs: [Subscription], catalog: AlternativesCatalog) -> Recommendations {
        let active = subs
        let needs = needs(active)
        return Recommendations(
            needs: needs,
            tags: tags(needs, total: active.count),
            replacements: replacements(active, catalog: catalog),
            suggestions: suggestions(active, catalog: catalog)
        )
    }

    // MARK: Needs

    /// Group by kind, highest spend first. Platform-billed / unknown charges
    /// aren't a "need" we can name, so they're left out.
    static func needs(_ subs: [Subscription]) -> [Need] {
        var byKind: [Kind: [Subscription]] = [:]
        for s in subs where s.kind != .other && s.kind != .platformBilled {
            byKind[s.kind, default: []].append(s)
        }
        return byKind.map { Need(kind: $0.key, subs: $0.value.sorted { $0.monthlyAmount > $1.monthlyAmount }) }
            .sorted { $0.monthly != $1.monthly ? $0.monthly > $1.monthly : $0.kind.rawValue < $1.kind.rawValue }
    }

    /// Short, honest labels for the pattern. Deterministic, no ML.
    static func tags(_ needs: [Need], total: Int) -> [String] {
        var out: [String] = []
        let spend = needs.reduce(0) { $0 + $1.monthly }
        func share(_ kinds: [Kind]) -> Double {
            guard spend > 0 else { return 0 }
            return needs.filter { kinds.contains($0.kind) }.reduce(0) { $0 + $1.monthly } / spend
        }
        func has(_ kinds: [Kind]) -> Bool { needs.contains { kinds.contains($0.kind) } }
        if share([.video, .liveTV, .sports, .music, .audiobooks, .podcasts]) >= 0.4 { out.append("Entertainment-first") }
        if has([.aiAssistant, .aiCoding, .devTools, .webHosting]) { out.append("Builder") }
        if has([.fitness, .meditation, .health]) { out.append("Wellness") }
        if has([.news, .learning, .audiobooks, .podcasts]) { out.append("Reader & learner") }
        if has([.passwordManager, .vpn, .cloudStorage, .security, .email]) { out.append("Security-minded") }
        if has([.delivery, .retailMembership, .mealKit]) { out.append("Convenience") }
        if has([.sports]) { out.append("Sports fan") }
        if has([.gaming]) { out.append("Gamer") }
        if has([.kids]) { out.append("Family") }
        if has([.creatorSupport, .socialMedia]) { out.append("Supports creators") }
        if has([.homeSecurity, .auto]) { out.append("Home & car") }
        if has([.finance]) { out.append("Money-minded") }
        if has([.dating]) { out.append("Dating") }
        if total >= 8 { out.append("Subscription-heavy") }
        // A wide library can light up most of the list; a caption of fourteen
        // tags says nothing. Keep the first few, and never drop the one tag
        // that is actually actionable.
        guard out.count > 5 else { return out }
        let heavy = out.last == "Subscription-heavy"
        return heavy ? Array(out.prefix(4)) + ["Subscription-heavy"] : Array(out.prefix(5))
    }

    // MARK: Replacements

    static func replacements(_ subs: [Subscription], catalog: AlternativesCatalog) -> [Replacement] {
        let held = heldBrands(subs)
        var out: [Replacement] = []
        for sub in subs where sub.kind != .platformBilled {
            let options = catalog.alternatives(for: sub)
                .filter { !held.contains(AlternativesCatalog.canonical($0.brandId)) }
                .sorted { a, b in
                    if a.edgeValue.rank != b.edgeValue.rank { return a.edgeValue.rank < b.edgeValue.rank }
                    return (a.priceMonthly ?? .greatestFiniteMagnitude) < (b.priceMonthly ?? .greatestFiniteMagnitude)
                }
            if !options.isEmpty { out.append(Replacement(sub: sub, options: Array(options.prefix(4)))) }
        }
        return out.sorted { $0.bestSavingMonthly != $1.bestSavingMonthly ? $0.bestSavingMonthly > $1.bestSavingMonthly : $0.sub.monthlyAmount > $1.sub.monthlyAmount }
    }

    // MARK: Suggestions

    static func suggestions(_ subs: [Subscription], catalog: AlternativesCatalog) -> [SuggestionMatch] {
        let held = heldBrands(subs)
        let kinds = Set(subs.map(\.kind).map(\.rawValue))
        var out: [SuggestionMatch] = []
        for rule in catalog.allSuggestions {
            let w = rule.when
            if let notBrands = w.notBrands, notBrands.contains(where: { held.contains($0) }) { continue }
            if let notKinds = w.notKinds, notKinds.contains(where: { kinds.contains($0) }) { continue }
            let byKind = subs.filter { (w.anyKinds ?? []).contains($0.kind.rawValue) }
            let byBrand = subs.filter { (w.anyBrands ?? []).contains(AlternativesCatalog.canonical($0.brandId)) }
            let hasTargets = !(w.anyKinds ?? []).isEmpty || !(w.anyBrands ?? []).isEmpty
            let matched = Set((byKind + byBrand).map(\.id)).count
            // `minSubs` counts matching subs when the rule names kinds/brands
            // ("2+ video services"), and ALL subs when it doesn't ("8+ subscriptions").
            let minSubsMet: Bool
            let triggered: Bool
            if hasTargets {
                minSubsMet = false
                triggered = matched >= max(1, w.minSubs ?? 1)
            } else {
                minSubsMet = (w.minSubs ?? 0) > 0 && subs.count >= (w.minSubs ?? 0)
                triggered = minSubsMet
            }
            guard triggered else { continue }
            // Every suggested app the user already holds is a non-suggestion.
            let apps = rule.apps.filter { !held.contains($0.brandId) }
            guard !apps.isEmpty else { continue }
            var because = Array((byKind + byBrand)
                .reduce(into: [String: Subscription]()) { $0[$1.id] = $1 }.values
                .sorted { $0.monthlyAmount > $1.monthlyAmount }.prefix(3))
            if because.isEmpty, minSubsMet { because = Array(subs.sorted { $0.monthlyAmount > $1.monthlyAmount }.prefix(3)) }
            let score = byKind.count + byBrand.count * 2 + (minSubsMet ? 1 : 0)
            out.append(SuggestionMatch(rule: rule, because: because, score: score))
        }
        return out.sorted { $0.score > $1.score }.prefix(8).map { $0 }
    }

    static func heldBrands(_ subs: [Subscription]) -> Set<String> {
        Set(subs.map { AlternativesCatalog.canonical($0.brandId) })
    }

    /// "Because you pay for Peloton and Headspace"
    static func becauseText(_ subs: [Subscription]) -> String {
        let names = subs.map(\.name)
        switch names.count {
        case 0: return ""
        case 1: return "Because you pay for \(names[0])"
        case 2: return "Because you pay for \(names[0]) and \(names[1])"
        default: return "Because you pay for \(names[0]), \(names[1]) and \(names[2])"
        }
    }
}
