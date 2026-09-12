import Foundation
import CloudKit
import Observation

// Picks — the public app leaderboard — was built but parked before release
// on 2026-09-11; tab 3 now holds the For-you recommendations. The whole
// feature is compiled out of Release so the shipping app contains no
// CloudKit *public* database code at all, which is what the privacy policy
// promises ("no part of Phantom is public"). It stays behind DEBUG rather
// than being deleted so `--screen-picks` and PickTests keep working, and so
// reviving it is a one-line change to this guard.
#if DEBUG

/// CloudKit public-database client for the Picks leaderboard. Reads are
/// anonymous; submitting, opening (counted) and reporting need an iCloud
/// account on the device. Submissions are `pending` until approved in the
/// CloudKit Console (docs/CLOUDKIT_SETUP.md) — that is the moderation step
/// App Review expects for user-generated content.
///
/// Every CloudKit touch goes through the optional `db`: it is nil when the
/// binary has no iCloud entitlement (unsigned builds), because creating a
/// `CKContainer` without one aborts the process.
@Observable
@MainActor
final class PicksService {
    static let shared = PicksService()

    enum LoadState: Equatable {
        case idle, loading, loaded
        case error(String)
    }

    private(set) var picks: [AppPick] = []
    private(set) var myPicks: [AppPick] = []
    private(set) var state: LoadState = .idle
    private(set) var lastLoadedAt: Date?
    private(set) var userToken: String?
    private(set) var hiddenSubmitters: Set<String>
    private(set) var hiddenPicks: Set<String>
    private var clickedKeys: Set<String>
    private var screenshotCache: [String: URL] = [:]

    private static let hiddenSubmittersKey = "phantom.picks.hiddenSubmitters"
    private static let hiddenPicksKey = "phantom.picks.hiddenPicks"
    private static let clickedKey = "phantom.picks.clicked"
    private static let noEntitlement = "This build can't reach iCloud (no CloudKit entitlement). Run a signed build."

    /// Nil when the binary has no CloudKit entitlement.
    private let container: CKContainer?
    private var db: CKDatabase? { container?.publicCloudDatabase }

    init(container: CKContainer? = CloudEntitlements.hasCloudKit ? CKContainer(identifier: AppConfig.cloudKitContainerID) : nil) {
        self.container = container
        hiddenSubmitters = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenSubmittersKey) ?? [])
        hiddenPicks = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenPicksKey) ?? [])
        clickedKeys = Set(UserDefaults.standard.stringArray(forKey: Self.clickedKey) ?? [])
        picks = Self.loadCache()
        if !picks.isEmpty { state = .loaded }
    }

    var isAvailable: Bool { db != nil }

    // MARK: - Reading

    /// Approved, not hidden, in one category (or all), ranked.
    func visible(category: PickCategory?) -> [AppPick] {
        let filtered = picks.filter {
            $0.status == .approved
                && !hiddenSubmitters.contains($0.submitterToken)
                && !hiddenPicks.contains($0.id)
                && (category == nil || $0.category == category)
        }
        return PickRanking.ranked(filtered)
    }

    func refresh() async {
        guard db != nil else {
            state = picks.isEmpty ? .error(Self.noEntitlement) : .loaded
            return
        }
        if picks.isEmpty { state = .loading }
        do {
            let predicate = NSPredicate(format: "status == %@", PickStatus.approved.rawValue)
            let fetched = try await query(predicate: predicate)
            picks = fetched
            lastLoadedAt = Date()
            state = .loaded
            Self.saveCache(fetched)
        } catch {
            state = picks.isEmpty ? .error(Self.describe(error)) : .loaded
        }
        await ensureUserToken()
        await loadMine()
    }

    func loadMine() async {
        guard let token = userToken else { return }
        let predicate = NSPredicate(format: "submitterToken == %@", token)
        if let mine = try? await query(predicate: predicate) {
            myPicks = mine.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func query(predicate: NSPredicate) async throws -> [AppPick] {
        guard let db else { throw PicksError.cloud(Self.noEntitlement) }
        let q = CKQuery(recordType: AppPick.recordType, predicate: predicate)
        var out: [AppPick] = []
        var (matches, cursor) = try await db.records(matching: q, desiredKeys: AppPick.listKeys, resultsLimit: 200)
        out += matches.compactMap { try? $0.1.get() }.compactMap(AppPick.init(record:))
        while let c = cursor, out.count < 1000 {
            (matches, cursor) = try await db.records(continuingMatchFrom: c, desiredKeys: AppPick.listKeys, resultsLimit: 200)
            out += matches.compactMap { try? $0.1.get() }.compactMap(AppPick.init(record:))
        }
        return await attachCounts(out)
    }

    /// Open counts are separate `PickCounter` records (one per pick, record
    /// name "counter-<pick id>"); fetch them by id in batches of 200.
    private func attachCounts(_ picks: [AppPick]) async -> [AppPick] {
        guard let db else { return picks }
        var result = picks
        let ids = picks.map(\.counterRecordID)
        var counts: [String: Int] = [:]
        for chunk in stride(from: 0, to: ids.count, by: 200).map({ Array(ids[$0..<min($0 + 200, ids.count)]) }) {
            guard let fetched = try? await db.records(for: chunk, desiredKeys: ["clicks"]) else { continue }
            for (id, res) in fetched {
                if let rec = try? res.get() { counts[id.recordName] = Int(rec["clicks"] as? Int64 ?? 0) }
            }
        }
        for i in result.indices {
            result[i].clicks = counts[result[i].counterRecordID.recordName] ?? 0
        }
        return result
    }

    /// Screenshot asset, fetched on demand and cached for the session.
    func screenshotURL(for pick: AppPick) async -> URL? {
        if let cached = screenshotCache[pick.id] { return cached }
        guard let db, let record = try? await db.record(for: pick.recordID),
              let asset = record["screenshot"] as? CKAsset, let url = asset.fileURL
        else { return nil }
        // CloudKit's temp file can be purged; copy it somewhere stable for the session.
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("pick-\(pick.id).jpg")
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)
        screenshotCache[pick.id] = dest
        return dest
    }

    // MARK: - Identity

    func ensureUserToken() async {
        guard userToken == nil, let container else { return }
        guard let status = try? await container.accountStatus(), status == .available,
              let id = try? await container.userRecordID()
        else { return }
        userToken = PickClickKey.token(fromUserRecordName: id.recordName)
    }

    // MARK: - Submitting

    func submit(_ submission: PickSubmission) async throws -> AppPick {
        let validated = try submission.validate()
        guard let db else { throw PicksError.cloud(Self.noEntitlement) }
        await ensureUserToken()
        guard let token = userToken else { throw PicksError.notSignedInToICloud }
        let record = CKRecord(recordType: AppPick.recordType, recordID: CKRecord.ID(recordName: UUID().uuidString))
        let pick = AppPick(
            id: record.recordID.recordName,
            name: submission.name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: submission.category,
            tagline: submission.tagline.trimmingCharacters(in: .whitespacesAndNewlines),
            details: submission.details.trimmingCharacters(in: .whitespacesAndNewlines),
            url: validated.url, appStoreURL: validated.appStoreURL,
            clicks: 0, status: .pending, submitterToken: token, createdAt: Date(), reports: 0
        )
        pick.apply(to: record)
        if let data = submission.screenshot {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("submit-\(pick.id).jpg")
            try data.write(to: tmp, options: .atomic)
            record["screenshot"] = CKAsset(fileURL: tmp)
        }
        do {
            _ = try await db.save(record)
        } catch {
            throw PicksError.cloud(Self.describe(error))
        }
        myPicks.insert(pick, at: 0)
        return pick
    }

    // MARK: - Opens (the vote)

    /// Count one open per person per app per day. Returns true when counted.
    @discardableResult
    func registerOpen(_ pick: AppPick, now: Date = Date()) async -> Bool {
        await ensureUserToken()
        guard let db, let token = userToken else { return false }
        let key = PickClickKey.key(pickID: pick.id, userToken: token, day: now)
        guard !clickedKeys.contains(key) else { return false }
        let click = CKRecord(recordType: AppPick.clickRecordType, recordID: CKRecord.ID(recordName: key))
        click["pick"] = CKRecord.Reference(recordID: pick.recordID, action: .deleteSelf)
        click["day"] = String(key.split(separator: "|").last ?? "") as CKRecordValue
        do {
            _ = try await db.save(click)
        } catch let error as CKError where error.code == .serverRecordChanged {
            rememberClick(key)
            return false   // already counted from another device today
        } catch {
            return false
        }
        rememberClick(key)
        await incrementClicks(pick)
        return true
    }

    /// Optimistic-locking increment with retry on the pick's counter record:
    /// fetch (or create), +1, save only if unchanged, otherwise re-fetch.
    private func incrementClicks(_ pick: AppPick) async {
        guard let db else { return }
        for _ in 0..<4 {
            let record: CKRecord
            if let existing = try? await db.record(for: pick.counterRecordID) {
                record = existing
            } else {
                record = CKRecord(recordType: AppPick.counterRecordType, recordID: pick.counterRecordID)
                record["pick"] = CKRecord.Reference(recordID: pick.recordID, action: .deleteSelf)
            }
            let current = record["clicks"] as? Int64 ?? 0
            record["clicks"] = (current + 1) as CKRecordValue
            let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            op.savePolicy = .ifServerRecordUnchanged
            op.qualityOfService = .userInitiated
            let saved: Bool = await withCheckedContinuation { cont in
                op.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success: cont.resume(returning: true)
                    case .failure: cont.resume(returning: false)
                    }
                }
                db.add(op)
            }
            if saved {
                if let i = picks.firstIndex(where: { $0.id == pick.id }) { picks[i].clicks = Int(current + 1) }
                Self.saveCache(picks)
                return
            }
        }
    }

    private func rememberClick(_ key: String) {
        clickedKeys.insert(key)
        // Keep the local memory small; the server-side record is the real guard.
        let trimmed = Array(clickedKeys).sorted().suffix(500)
        clickedKeys = Set(trimmed)
        UserDefaults.standard.set(Array(clickedKeys), forKey: Self.clickedKey)
    }

    // MARK: - Moderation (App Review 1.2: report + block)

    func report(_ pick: AppPick, reason: String) async throws {
        guard let db else { throw PicksError.cloud(Self.noEntitlement) }
        await ensureUserToken()
        let record = CKRecord(recordType: AppPick.reportRecordType)
        record["pick"] = CKRecord.Reference(recordID: pick.recordID, action: .deleteSelf)
        record["reason"] = reason as CKRecordValue
        record["reporterToken"] = (userToken ?? "anonymous") as CKRecordValue
        do {
            _ = try await db.save(record)
        } catch {
            throw PicksError.cloud(Self.describe(error))
        }
        hiddenPicks.insert(pick.id)
        UserDefaults.standard.set(Array(hiddenPicks), forKey: Self.hiddenPicksKey)
    }

    /// Account deletion: remove every submission that belongs to this user
    /// (the `_creator` role allows deleting your own records; counters and
    /// clicks reference the pick with deleteSelf, so CloudKit cascades).
    func deleteMySubmissions() async {
        guard let db else { return }
        await ensureUserToken()
        guard let token = userToken else { return }
        let predicate = NSPredicate(format: "submitterToken == %@", token)
        guard let mine = try? await query(predicate: predicate), !mine.isEmpty else { return }
        _ = try? await db.modifyRecords(saving: [], deleting: mine.map(\.recordID))
        myPicks = []
        picks.removeAll { pick in mine.contains { $0.id == pick.id } }
        Self.saveCache(picks)
    }

    func hide(submitter token: String) {
        guard !token.isEmpty else { return }
        hiddenSubmitters.insert(token)
        UserDefaults.standard.set(Array(hiddenSubmitters), forKey: Self.hiddenSubmittersKey)
    }

    // MARK: - Cache & errors

    private static var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Phantom", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("picks-cache.json")
    }

    private static func loadCache() -> [AppPick] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([AppPick].self, from: data)) ?? []
    }

    private static func saveCache(_ picks: [AppPick]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(picks) { try? data.write(to: cacheURL, options: .atomic) }
    }

    nonisolated static func describe(_ error: Error) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }
        switch ck.code {
        case .notAuthenticated: return "Sign in to iCloud in iOS Settings to use Picks."
        case .networkUnavailable, .networkFailure: return "You're offline. Showing the last list we saw."
        case .unknownItem, .invalidArguments: return "Picks isn't set up on the server yet."
        case .quotaExceeded: return "iCloud storage is full."
        case .permissionFailure: return "Not allowed — try signing in to iCloud again."
        default: return ck.localizedDescription
        }
    }
}

enum PicksError: LocalizedError {
    case notSignedInToICloud
    case cloud(String)

    var errorDescription: String? {
        switch self {
        case .notSignedInToICloud: return "Sign in to iCloud in iOS Settings first — submissions and opens are tied to your account."
        case .cloud(let msg): return msg
        }
    }
}

#endif
