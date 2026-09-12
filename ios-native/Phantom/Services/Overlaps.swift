import Foundation

/// Same-kind overlap across the library. Pure so it can be unit-tested without
/// the store: two or more active subs sharing a substitutable kind flag each
/// other; cancelled subs and non-substitutable kinds (telecom, platform-billed)
/// never participate.
enum Overlaps {
    static func compute(_ subs: [Subscription], cancelledIds: Set<String>) -> [String: [String]] {
        var byKind: [Kind: [String]] = [:]
        for s in subs where !cancelledIds.contains(s.id) && s.kind.participatesInOverlap {
            byKind[s.kind, default: []].append(s.id)
        }
        var out: [String: [String]] = [:]
        for s in subs {
            out[s.id] = s.kind.participatesInOverlap
                ? (byKind[s.kind] ?? []).filter { $0 != s.id }
                : []
        }
        return out
    }
}
