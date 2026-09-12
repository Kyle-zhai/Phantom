import Foundation

/// CloudKit can't enforce uniqueness, so two devices can create the same
/// logical row. Callers keep one per key (by `prefer`) and delete the rest.
enum Dedupe {
    struct Outcome<T> {
        var keep: [T]
        var drop: [T]
    }

    static func byKey<T>(_ rows: [T], key: (T) -> String, prefer: (T, T) -> Bool = { _, _ in false }) -> Outcome<T> {
        var best: [String: T] = [:]
        var order: [String] = []
        var drop: [T] = []
        for row in rows {
            let k = key(row)
            if let cur = best[k] {
                if prefer(row, cur) {
                    drop.append(cur)
                    best[k] = row
                } else {
                    drop.append(row)
                }
            } else {
                best[k] = row
                order.append(k)
            }
        }
        return Outcome(keep: order.compactMap { best[$0] }, drop: drop)
    }
}
