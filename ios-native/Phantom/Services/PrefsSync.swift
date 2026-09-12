import Foundation
import SwiftData

/// Mirrors a fixed set of UserDefaults keys into `PersistentSetting` rows so
/// they ride the CloudKit sync with everything else. Existing code keeps
/// reading and writing UserDefaults; this listens for changes and copies
/// them up, and copies cloud values down on attach / remote change.
/// Last write wins per key.
@MainActor
final class PrefsSync {
    static let shared = PrefsSync()

    /// Keys worth carrying to the user's other devices.
    static let trackedKeys: [String] = [
        "phantom.notif.hikes", "phantom.notif.trials", "phantom.notif.zombies", "phantom.notif.rescan",
        "phantom.notif.didAsk", "phantom.lastImportAt", "phantom.disputeRecords", "phantom.disputeFollowUps",
        "phantom.ownedBundles", "phantom.cancelAttempts", "phantom.disputeUsageDates", "phantom.sampleMode",
        "phantom.didAskReview", "phantom.account.name", "phantom.account.email",
    ]

    private var context: ModelContext?
    private var lastMirrored: [String: Data] = [:]
    private var applying = false
    private var observer: NSObjectProtocol?

    func attach(_ context: ModelContext) {
        self.context = context
        applyCloudToDefaults()
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.mirrorChangedKeys() }
            }
        }
        mirrorChangedKeys()
    }

    /// Cloud rows → UserDefaults (called on attach and after a remote change).
    func applyCloudToDefaults() {
        guard let context else { return }
        let rows = (try? context.fetch(FetchDescriptor<PersistentSetting>())) ?? []
        let deduped = Dedupe.byKey(rows, key: \.key, prefer: { $0.updatedAt > $1.updatedAt })
        for extra in deduped.drop { context.delete(extra) }
        applying = true
        defer { applying = false }
        for row in deduped.keep where Self.trackedKeys.contains(row.key) {
            guard let value = Self.decode(row.value) else { continue }
            UserDefaults.standard.set(value, forKey: row.key)
            lastMirrored[row.key] = row.value
        }
        if !deduped.drop.isEmpty { try? context.save() }
    }

    /// UserDefaults → cloud rows for any tracked key whose plist changed.
    func mirrorChangedKeys() {
        guard !applying, let context else { return }
        var dirty = false
        let rows = (try? context.fetch(FetchDescriptor<PersistentSetting>())) ?? []
        var byKey = Dictionary(rows.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        for key in Self.trackedKeys {
            let current = UserDefaults.standard.object(forKey: key)
            let encoded = current.flatMap(Self.encode)
            if encoded == lastMirrored[key] { continue }
            if let encoded {
                if let row = byKey[key] {
                    if row.value != encoded {
                        row.value = encoded
                        row.updatedAt = Date()
                        dirty = true
                    }
                } else {
                    let row = PersistentSetting(key: key, value: encoded)
                    context.insert(row)
                    byKey[key] = row
                    dirty = true
                }
                lastMirrored[key] = encoded
            } else if let row = byKey[key] {
                context.delete(row)
                byKey[key] = nil
                lastMirrored[key] = nil
                dirty = true
            }
        }
        if dirty { try? context.save() }
    }

    /// Drop every mirrored preference (account deletion).
    func wipe() {
        guard let context else { return }
        for row in (try? context.fetch(FetchDescriptor<PersistentSetting>())) ?? [] { context.delete(row) }
        try? context.save()
        lastMirrored = [:]
    }

    // Plist round-trip wrapped in a dictionary so scalars (Bool/Double) are legal roots.
    nonisolated static func encode(_ value: Any) -> Data? {
        try? PropertyListSerialization.data(fromPropertyList: ["v": value], format: .binary, options: 0)
    }

    nonisolated static func decode(_ data: Data) -> Any? {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return root["v"]
    }
}
