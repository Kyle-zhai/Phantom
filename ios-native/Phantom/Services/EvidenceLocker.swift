import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Proof that a cancel actually happened: confirmation number, date, optional
/// screenshot, notes. Stored as `PersistentEvidence` rows in the synced
/// SwiftData store (screenshot as external storage), so it follows the
/// user's iCloud account. Nothing goes to any Phantom server.
@MainActor
enum EvidenceLocker {
    struct Record: Codable, Identifiable, Hashable {
        let id: String
        var confirmationNumber: String
        var notes: String
        var cancelledAt: Date
        var method: String
        var hasScreenshot: Bool
    }

    /// Set by `AppStore.attach`. Before that (or in tests) the locker is empty.
    static var context: ModelContext?

    private static let legacyKey = "phantom.evidence.records"
    private static let legacyFolderName = "Evidence"

    private static func rows() -> [PersistentEvidence] {
        guard let context else { return [] }
        let all = (try? context.fetch(FetchDescriptor<PersistentEvidence>())) ?? []
        let deduped = Dedupe.byKey(all, key: \.id, prefer: { a, b in
            (a.screenshot != nil && b.screenshot == nil) || a.cancelledAt > b.cancelledAt
        })
        if !deduped.drop.isEmpty {
            for extra in deduped.drop { context.delete(extra) }
            try? context.save()
        }
        return deduped.keep
    }

    private static func row(_ id: String) -> PersistentEvidence? {
        rows().first { $0.id == id }
    }

    private static func record(from row: PersistentEvidence) -> Record {
        Record(id: row.id, confirmationNumber: row.confirmationNumber, notes: row.notes,
               cancelledAt: row.cancelledAt, method: row.method, hasScreenshot: row.screenshot != nil)
    }

    static func loadAll() -> [String: Record] {
        Dictionary(uniqueKeysWithValues: rows().map { ($0.id, record(from: $0)) })
    }

    static func load(_ id: String) -> Record? {
        row(id).map(record(from:))
    }

    static func save(_ record: Record) {
        guard let context else { return }
        let target = row(record.id) ?? {
            let r = PersistentEvidence(id: record.id)
            context.insert(r)
            return r
        }()
        target.confirmationNumber = record.confirmationNumber
        target.notes = record.notes
        target.cancelledAt = record.cancelledAt
        target.method = record.method
        try? context.save()
    }

    static func remove(_ id: String) {
        guard let context else { return }
        for r in rows() where r.id == id { context.delete(r) }
        try? context.save()
    }

    static func removeAll() {
        guard let context else { return }
        for r in rows() { context.delete(r) }
        try? context.save()
    }

    #if canImport(UIKit)
    static func saveScreenshot(_ image: UIImage, for id: String) -> Bool {
        guard let context, let data = image.jpegData(compressionQuality: 0.82) else { return false }
        let target = row(id) ?? {
            let r = PersistentEvidence(id: id)
            context.insert(r)
            return r
        }()
        target.screenshot = data
        try? context.save()
        return true
    }

    static func loadScreenshot(for id: String) -> UIImage? {
        row(id)?.screenshot.flatMap(UIImage.init(data:))
    }
    #endif

    /// One-time move from the pre-sync storage (UserDefaults JSON + JPEGs in
    /// Application Support) into the synced store.
    static func migrateLegacyIfNeeded() {
        guard let context,
              let data = UserDefaults.standard.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode([String: Record].self, from: data)
        else { return }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent(legacyFolderName, isDirectory: true)
        for (id, rec) in legacy where row(id) == nil {
            let r = PersistentEvidence(id: id)
            r.confirmationNumber = rec.confirmationNumber
            r.notes = rec.notes
            r.cancelledAt = rec.cancelledAt
            r.method = rec.method
            r.screenshot = try? Data(contentsOf: folder.appendingPathComponent("\(id).jpg"))
            context.insert(r)
        }
        try? context.save()
        UserDefaults.standard.removeObject(forKey: legacyKey)
        try? FileManager.default.removeItem(at: folder)
    }
}
