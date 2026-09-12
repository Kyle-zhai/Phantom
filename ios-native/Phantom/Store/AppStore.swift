import Foundation
import Observation
import SwiftData
import UserNotifications
import WidgetKit
import StoreKit
import UIKit

/// Single source of truth for the app. Fully on-device: persists to SwiftData,
/// derives subscriptions from Vision OCR + on-device parsing, watches the static
/// price catalog, and schedules real local notifications. No backend, no Plaid.
@MainActor
@Observable
final class AppStore {
    enum LoadState: Equatable {
        case idle
        case loading(String)
        case error(String)
    }

    var subscriptions: [Subscription] = []
    var alerts: [PriceAlert] = []
    var cancelledIds: Set<String> = []
    var loadState: LoadState = .idle
    var lastSync: Date?
    var selectedTab: Int = 0
    var disputeUsageDates: [Date] = []

    /// Programmatic navigation path for the Radar tab's NavigationStack. Driven
    /// both by row taps and by notification deep-links (see `openSubscription`).
    var radarPath: [String] = []

    // MARK: - Notifications

    /// Whether the OS has granted notification authorization. Mirrored into an
    /// observable property so Settings can reflect the live state.
    var notificationsAuthorized = false
    /// Per-category opt-outs, persisted in UserDefaults and honored when
    /// scheduling. Default on. Toggling reschedules.
    var notifyHikes = true { didSet { UserDefaults.standard.set(notifyHikes, forKey: NotifKey.hikes) } }
    var notifyTrials = true { didSet { UserDefaults.standard.set(notifyTrials, forKey: NotifKey.trials) } }
    var notifyZombies = true { didSet { UserDefaults.standard.set(notifyZombies, forKey: NotifKey.zombies) } }
    var notifyRescan = true { didSet { UserDefaults.standard.set(notifyRescan, forKey: NotifKey.rescan) } }

    private enum NotifKey {
        static let hikes = "phantom.notif.hikes"
        static let trials = "phantom.notif.trials"
        static let zombies = "phantom.notif.zombies"
        static let rescan = "phantom.notif.rescan"
        static let didAsk = "phantom.notif.didAsk"
        static let lastImport = "phantom.lastImportAt"
        static let disputeRecords = "phantom.disputeRecords"
        static let disputeFollow = "phantom.disputeFollowUps"
        static let ownedBundles = "phantom.ownedBundles"
    }

    /// Last successful screenshot/CSV import. Drives the monthly re-scan reminder.
    var lastImportAt: Date?

    // MARK: - Catalog, bundles, coverage

    /// Tiers / alternatives / bundle-inclusion catalog. Bundled copy at launch,
    /// refreshed from GitHub Pages on cold start.
    var catalog: AlternativesCatalog = .empty

    /// Bundles / cards the user ticked in Settings ("What you already have").
    var ownedBundleIds: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(ownedBundleIds).sorted(), forKey: NotifKey.ownedBundles) }
    }

    /// A sent dispute letter, keyed by subscription id — feeds the chargeback packet.
    struct DisputeRecord: Codable, Hashable {
        var subId: String
        var reasonRaw: String
        var amount: Double
        var chargeDate: String
        var sentAt: Date
        var letter: String
    }
    var disputeRecords: [String: DisputeRecord] = [:]
    /// Absolute fire dates for "did they refund you?" follow-ups.
    var disputeFollowUps: [String: Date] = [:]

    // MARK: - Cancellation concierge

    /// A subscription the user said they cancelled at the vendor but Phantom
    /// hasn't yet confirmed gone from a statement. Surfaced so the user can
    /// verify on the next import (and backs the verification reminder).
    struct CancellationAttempt: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        let monthlyAmount: Double
        let attemptedAt: Date
    }
    var cancellationAttempts: [CancellationAttempt] = []
    private static let attemptsKey = "phantom.cancelAttempts"

    /// Cached — DateFormatter init is expensive and this was allocated once per
    /// new sub inside the import loop.
    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private(set) var profile: UserProfile?
    private(set) var purchaseService: PurchaseService

    private var modelContext: ModelContext?

    var isOnboarded: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { return true }
        if ProcessInfo.processInfo.arguments.contains("--demo") { return true }
        #endif
        return profile?.onboardedAt != nil
    }

    var isPro: Bool { purchaseService.isPro }

    init(purchaseService: PurchaseService) {
        self.purchaseService = purchaseService
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
        EvidenceLocker.context = modelContext
        EvidenceLocker.migrateLegacyIfNeeded()
        // Cloud-mirrored preferences land in UserDefaults BEFORE anything reads them.
        PrefsSync.shared.attach(modelContext)
        catalog = AlternativesCatalogLoader.best()
        migrateLegacyLedgerIfNeeded()
        loadEverything()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo") && subscriptions.isEmpty {
            seedSampleData()
        }
        #endif
        updateWidgetSnapshot()
    }

    /// Read every table + mirrored preference. Used on attach and after a
    /// CloudKit remote change (another device edited the data).
    private func loadEverything() {
        ownedBundleIds = Set(UserDefaults.standard.stringArray(forKey: NotifKey.ownedBundles) ?? [])
        loadFromDisk()
        loadDisputeUsage()
        loadNotificationPrefs()
        loadCancellationAttempts()
        loadDisputeRecords()
    }

    private var reloadScheduled = false

    /// Coalesce bursts of remote-change notifications into one reload.
    func scheduleReload() {
        guard modelContext != nil, !reloadScheduled else { return }
        reloadScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            reloadScheduled = false
            reloadFromDisk()
        }
    }

    func reloadFromDisk() {
        guard modelContext != nil else { return }
        PrefsSync.shared.applyCloudToDefaults()
        loadEverything()
        refreshInsightAlerts()
        updateWidgetSnapshot()
        Task { await rescheduleAllNotifications() }
    }

    private func loadNotificationPrefs() {
        let d = UserDefaults.standard
        notifyHikes = d.object(forKey: NotifKey.hikes) as? Bool ?? true
        notifyTrials = d.object(forKey: NotifKey.trials) as? Bool ?? true
        notifyZombies = d.object(forKey: NotifKey.zombies) as? Bool ?? true
        notifyRescan = d.object(forKey: NotifKey.rescan) as? Bool ?? true
        if let t = d.object(forKey: NotifKey.lastImport) as? Double {
            lastImportAt = Date(timeIntervalSince1970: t)
        }
    }

    private func loadDisputeRecords() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: NotifKey.disputeRecords),
           let decoded = try? JSONDecoder().decode([String: DisputeRecord].self, from: data) {
            disputeRecords = decoded
        }
        if let data = d.data(forKey: NotifKey.disputeFollow),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            disputeFollowUps = decoded
        }
    }

    private func saveDisputeRecords() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(disputeRecords) {
            d.set(data, forKey: NotifKey.disputeRecords)
        }
        if let data = try? JSONEncoder().encode(disputeFollowUps) {
            d.set(data, forKey: NotifKey.disputeFollow)
        }
    }

    func disputeRecord(for id: String) -> DisputeRecord? { disputeRecords[id] }

    func recordDisputeSent(for id: String, reason: DisputeReason, amount: Double, chargeDate: String, letter: String) {
        let rec = DisputeRecord(
            subId: id, reasonRaw: reason.rawValue, amount: amount,
            chargeDate: chargeDate, sentAt: Date(), letter: letter
        )
        disputeRecords[id] = rec
        let fire = Date().addingTimeInterval(14 * 86_400)
        disputeFollowUps[id] = fire
        saveDisputeRecords()
        Task {
            if notificationsAuthorized {
                await NotificationService.scheduleDisputeFollowUp(
                    subscriptionId: id, name: subscription(byId: id)?.name ?? "that charge", fireAt: fire
                )
            } else {
                await requestNotificationsAfterFirstImport()
            }
        }
    }

    private func loadCancellationAttempts() {
        guard let data = UserDefaults.standard.data(forKey: Self.attemptsKey),
              let decoded = try? JSONDecoder().decode([CancellationAttempt].self, from: data)
        else { return }
        cancellationAttempts = decoded
    }

    private func saveCancellationAttempts() {
        if let data = try? JSONEncoder().encode(cancellationAttempts) {
            UserDefaults.standard.set(data, forKey: Self.attemptsKey)
        }
    }

    /// Opt-in sample data path. Called from "Browse with sample data" buttons
    /// in onboarding and the empty Radar state. Also used by the `--demo`
    /// launch flag for automated UI tests.
    func seedSampleData() {
        subscriptions = MockData.subscriptions
        alerts = MockData.alerts
        persistAllSubscriptions()
        persistAllAlerts()
        ensureProfile()
        if profile?.fullName.isEmpty ?? true { profile?.fullName = "Sample User" }
        if profile?.email.isEmpty ?? true { profile?.email = "sample@phantom.app" }
        profile?.onboardedAt = Date()
        UserDefaults.standard.set(true, forKey: "phantom.sampleMode")
        save()
    }

    /// Whether the current data set was seeded from sample data (vs. real
    /// user-imported transactions). Shown as a banner in Settings + Radar.
    var isSampleMode: Bool {
        UserDefaults.standard.bool(forKey: "phantom.sampleMode")
    }

    /// Removes seeded sample data and returns the app to a clean state.
    func clearSampleData() {
        subscriptions = []
        alerts = []
        cancelledIds = []
        cancellationAttempts = []
        saveCancellationAttempts()
        clearLedger()
        clearAllPersistent()
        UserDefaults.standard.removeObject(forKey: "phantom.sampleMode")
        wipeClawbackState()
        // Keep the profile and onboardedAt — user gets to skip onboarding
        save()
    }

    var scoresById: [String: Int] {
        let hits = coverageHitsBySub
        return Dictionary(uniqueKeysWithValues: subscriptions.map { sub in
            (sub.id, ZombieScore.compute(sub, context: scoreContext(for: sub, hits: hits)).score)
        })
    }

    /// Full factor breakdown for the detail view, using the same context the
    /// Radar scores use (bundle coverage + catalog prices).
    func breakdown(for id: String) -> ScoreBreakdown? {
        guard let sub = subscription(byId: id) else { return nil }
        return ZombieScore.compute(sub, context: scoreContext(for: sub, hits: coverageHitsBySub))
    }

    func scoreContext(for sub: Subscription, hits: [String: CoverageHit]? = nil) -> ScoreContext {
        let hit = (hits ?? coverageHitsBySub)[sub.id]
        return ScoreContext(
            coverage: hit?.level ?? .none,
            cheapestTierMonthly: catalog.cheapestPaidTierMonthly(for: sub.brandId),
            kindMedianMonthly: catalog.kindMedianMonthly(sub.kind)
        )
    }

    // MARK: Bundle coverage ("you already pay for this")

    var inferredBundleIds: Set<String> {
        BundleCoverage.inferredBundleIds(activeSubs: activeSubs, catalog: catalog)
    }

    /// Every covered subscription, strongest bundle per sub, most valuable first.
    var coverageHits: [CoverageHit] {
        BundleCoverage.hits(activeSubs: activeSubs, ownedBundleIds: ownedBundleIds,
                            inferredBundleIds: inferredBundleIds, catalog: catalog)
    }

    private var coverageHitsBySub: [String: CoverageHit] {
        Dictionary(coverageHits.map { ($0.subId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Free tier sees the single most valuable "already covered" finding; Pro
    /// sees every one. The score still uses all of them — gating is UI-only.
    var visibleCoverageHits: [CoverageHit] {
        isPro ? coverageHits : Array(coverageHits.prefix(1))
    }

    var hiddenCoverageCount: Int { max(0, coverageHits.count - visibleCoverageHits.count) }

    func coverageHit(for subId: String) -> CoverageHit? { coverageHitsBySub[subId] }

    func visibleCoverageHit(for subId: String) -> CoverageHit? {
        visibleCoverageHits.first { $0.subId == subId }
    }

    /// Monthly total of subs that are literally included in something the
    /// user already pays for.
    var payingTwiceMonthly: Double {
        coverageHits.filter { $0.level == .included }.reduce(0) { $0 + $1.valueMonthly }
    }

    /// Monthly value across every coverage level (included + credits + perks).
    var coverageValueMonthly: Double {
        coverageHits.reduce(0) { $0 + $1.valueMonthly }
    }

    func setBundleOwned(_ id: String, _ owned: Bool) {
        if owned { ownedBundleIds.insert(id) } else { ownedBundleIds.remove(id) }
        refreshInsightAlerts()
        updateWidgetSnapshot()
    }

    // MARK: Cheaper plans / alternatives

    func downgrade(for sub: Subscription) -> Downgrade? { catalog.downgrade(for: sub) }

    /// Like-for-like alternatives, minus anything the user already holds.
    func alternatives(for sub: Subscription) -> [AlternativesCatalog.Alternative] {
        let held = Set(activeSubs.map { AlternativesCatalog.canonical($0.brandId) })
        return catalog.alternatives(for: sub).filter { !held.contains(AlternativesCatalog.canonical($0.brandId)) }
    }

    /// Annual savings if every sub with a cheaper tier dropped to it.
    var cheaperPlanYearlySavings: Double {
        activeSubs.compactMap { downgrade(for: $0)?.savesYearly }.reduce(0, +)
    }

    // MARK: For you (needs → replacements → complementary apps)

    var recommendations: Recommender.Recommendations {
        Recommender.build(subs: activeSubs, catalog: catalog)
    }

    /// Free tier sees the first replacement group and the first suggestion;
    /// Pro sees everything. Same rule as bundle coverage.
    func visibleReplacements(_ r: Recommender.Recommendations) -> [Recommender.Replacement] {
        isPro ? r.replacements : Array(r.replacements.prefix(1))
    }

    func visibleSuggestions(_ r: Recommender.Recommendations) -> [Recommender.SuggestionMatch] {
        isPro ? r.suggestions : Array(r.suggestions.prefix(1))
    }

    /// Subs that have a cheaper tier, biggest saving first.
    var downgradeCandidates: [(sub: Subscription, downgrade: Downgrade)] {
        activeSubs.compactMap { sub in downgrade(for: sub).map { (sub, $0) } }
            .sorted { $0.downgrade.savesYearly > $1.downgrade.savesYearly }
    }

    var activeSubs: [Subscription] {
        subscriptions.filter { !cancelledIds.contains($0.id) }
    }

    var cancelledSubs: [Subscription] {
        subscriptions.filter { cancelledIds.contains($0.id) }
    }

    var monthlyTotal: Double {
        activeSubs.reduce(0) { $0 + $1.monthlyAmount }
    }

    var potentialSavings: Double {
        activeSubs
            .filter { (scoresById[$0.id] ?? 0) >= 80 }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    var zombieCount: Int {
        activeSubs.filter { (scoresById[$0.id] ?? 0) >= 80 }.count
    }

    /// True annual run-rate of everything still active (uses each sub's real
    /// billing cycle, so a yearly plan isn't double-counted).
    var yearlyTotal: Double {
        activeSubs.reduce(0) { $0 + $1.yearlyAmount }
    }

    /// Annualized savings still on the table if the user cancels every zombie.
    var potentialYearlySavings: Double {
        activeSubs
            .filter { (scoresById[$0.id] ?? 0) >= 80 }
            .reduce(0) { $0 + $1.yearlyAmount }
    }

    /// Annualized savings the user has already claimed by cancelling.
    var realizedYearlySavings: Double {
        cancelledSubs.reduce(0) { $0 + $1.yearlyAmount }
    }

    var unreadAlerts: Int { alerts.filter { !$0.read }.count }

    /// Notification deep-link entry point: jump to a subscription's detail from
    /// a tapped local notification.
    func openSubscription(_ id: String) {
        guard subscription(byId: id) != nil else { return }
        selectedTab = 0
        radarPath = [id]
    }

    func openDispute(_ id: String) {
        openSubscription(id)
        DeepLink.shared.pendingDisputeId = id
    }

    /// Days since the last screenshot/CSV import. Nil if the user has never imported.
    var daysSinceLastImport: Int? {
        guard let lastImportAt else { return nil }
        return Calendar.current.dateComponents([.day], from: lastImportAt, to: Date()).day
    }

    func subscription(byId id: String) -> Subscription? {
        subscriptions.first { $0.id == id }
    }

    func score(for id: String) -> Int { scoresById[id] ?? 0 }
    func tier(for id: String) -> Tier { ZombieScore.tier(for: score(for: id)) }

    // MARK: - Onboarding & Plaid

    func setProfile(name: String, email: String) {
        ensureProfile()
        profile?.fullName = name
        profile?.email = email
        save()
    }

    func completeOnboarding(viaDemo: Bool = false) {
        ensureProfile()
        profile?.onboardedAt = Date()
        if viaDemo && subscriptions.isEmpty {
            seedSampleData()
        }
        save()
    }

    func resetOnboarding() {
        profile?.onboardedAt = nil
        subscriptions = []
        alerts = []
        cancelledIds = []
        cancellationAttempts = []
        saveCancellationAttempts()
        clearLedger()
        wipeClawbackState()
        clearAllPersistent()
        save()
    }

    /// Merge subscriptions detected from OCR'd screenshots into the live list.
    /// Existing user-tweaked fields (rating, lastUsedAt) are preserved when merging by id.
    func mergeImported(subs: [Subscription], transactions: [ParsedTransaction]) {
        if !transactions.isEmpty {
            recordLedger(transactions)
        }
        // An Apple-list sub ("Netflix · $19.99/month") and a bank row
        // ("APPLE.COM/BILL $19.99") are the same money. Fold the anonymous one
        // into the named one instead of showing both.
        let recon = AppleReconciler.reconcile(existing: subscriptions, incoming: subs)
        if !recon.removeExistingIds.isEmpty {
            subscriptions.removeAll { recon.removeExistingIds.contains($0.id) }
            alerts.removeAll { recon.removeExistingIds.contains($0.subscriptionId) }
            cancelledIds.subtract(recon.removeExistingIds)
        }
        let subs = recon.incoming
        let existing = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })
        var merged = subscriptions
        var newlyAdded: [Subscription] = []
        for new in subs {
            if let cur = existing[new.id] {
                // Update price/cycle/dates, keep user data
                let updated = Subscription(
                    id: cur.id, name: new.name, vendor: new.vendor, rawDescriptor: new.rawDescriptor ?? cur.rawDescriptor,
                    brandHex: cur.brandHex, category: cur.category,
                    amount: new.amount, cycle: new.cycle,
                    nextBilling: new.nextBilling,
                    startedAt: min(cur.startedAt, new.startedAt),
                    lastUsedAt: cur.lastUsedAt,
                    sessionsLast30d: cur.sessionsLast30d,
                    userRating: cur.userRating,
                    marketAverage: cur.marketAverage > 0 ? cur.marketAverage : new.marketAverage,
                    trialEndsAt: cur.trialEndsAt,
                    // A hike seen on the statement itself beats a stale one.
                    hasPriceHike: new.hasPriceHike ?? cur.hasPriceHike,
                    hasOverlapWith: cur.hasOverlapWith,
                    notes: new.notes,
                    billedVia: new.billedVia ?? cur.billedVia
                )
                if let idx = merged.firstIndex(where: { $0.id == cur.id }) {
                    merged[idx] = updated
                }
            } else {
                merged.append(new)
                newlyAdded.append(new)
            }
        }
        subscriptions = merged
        recomputeOverlaps()
        persistAllSubscriptions()
        ensureProfile()
        profile?.onboardedAt = profile?.onboardedAt ?? Date()

        // Surface the new subs in the Alerts tab so the user has something
        // to act on (and so the tab isn't empty right after their first import).
        for sub in newlyAdded {
            let dateStr = Self.mediumDateFormatter.string(from: sub.startedAt)
            let alert = PriceAlert(
                id: "newcharge-\(sub.id)-\(Int(sub.startedAt.timeIntervalSince1970))",
                subscriptionId: sub.id,
                type: .newCharge,
                title: "New subscription detected: \(sub.name)",
                message: "First seen \(dateStr) for \(fmtUSD(sub.amount)). Tap to review the details or generate a dispute letter if it's not yours.",
                createdAt: Date(),
                read: false
            )
            if !alerts.contains(where: { $0.id == alert.id }) {
                alerts.append(alert)
                persist(alert: alert)
            }
        }
        refreshInsightAlerts()
        save()
        recordLastImport()
        Task {
            await refreshPriceAlerts()
            await requestNotificationsAfterFirstImport()
        }
    }

    /// "Already covered" and "cheaper plan" findings surface in the Alerts
    /// feed once each; re-running is idempotent.
    func refreshInsightAlerts() {
        var added = false
        for hit in coverageHits where hit.level >= .credit {
            guard let sub = subscription(byId: hit.subId) else { continue }
            let id = "covered-\(hit.subId)-\(hit.bundleId)"
            guard !alerts.contains(where: { $0.id == id }) else { continue }
            let what = hit.level == .included ? "is included in" : "is reimbursed by"
            let alert = PriceAlert(
                id: id, subscriptionId: sub.id, type: .covered,
                title: "\(sub.name) \(what) \(hit.bundleName)",
                message: (hit.note.map { $0 + " " } ?? "") + "That's \(fmtUSD(hit.valueYearly)) a year you may be paying twice.",
                createdAt: Date(), read: false
            )
            alerts.append(alert)
            persist(alert: alert)
            added = true
        }
        for (sub, d) in downgradeCandidates where d.savesYearly >= 24 {
            let id = "cheaper-\(sub.id)-\(RecurrenceDetector.slug(d.cheaper.name))"
            guard !alerts.contains(where: { $0.id == id }) else { continue }
            let alert = PriceAlert(
                id: id, subscriptionId: sub.id, type: .cheaperTier,
                title: "Keep \(sub.name) for \(fmtUSD(d.savesYearly)) less a year",
                message: "You look to be on \(d.current.name) (\(fmtUSD(d.current.priceMonthly))/mo). \(d.cheaper.name) is \(fmtUSD(d.cheaper.priceMonthly))/mo.",
                createdAt: Date(), read: false
            )
            alerts.append(alert)
            persist(alert: alert)
            added = true
        }
        if added { save() }
    }

    func recordLastImport() {
        lastImportAt = Date()
        UserDefaults.standard.set(lastImportAt!.timeIntervalSince1970, forKey: NotifKey.lastImport)
    }

    /// Consume share-extension / Open-in files sitting in the App Group inbox.
    /// Returns whether anything was waiting (so the UI can present the importer).
    @discardableResult
    func consumeIncomingInbox() -> IncomingInbox.Payload {
        IncomingInbox.consume()
    }

    /// Files / Share Sheet / custom URL scheme `phantom://import`.
    func handleIncomingURL(_ url: URL) async {
        if url.scheme == "phantom" {
            DeepLink.shared.pendingImport = true
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            DeepLink.shared.pendingImport = true
            return
        }
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let isCSV = ["csv", "txt", "tsv"].contains(ext)
        IncomingInbox.write(data: data, suggestedName: name, isCSV: isCSV)
        DeepLink.shared.pendingImport = true
    }

    func flagIncomingImportIfNeeded() {
        if IncomingInbox.hasItems {
            DeepLink.shared.pendingImport = true
        }
    }

    /// Permanently remove a subscription from the user's library. Called when
    /// the user swipes-to-delete a row that was mis-detected (e.g. an Uber ride
    /// that looked recurring). Wipes:
    ///   - in-memory subscriptions + cancelledIds + related alerts
    ///   - SwiftData persistent row + persistent alerts
    ///   - any scheduled local notifications for that sub
    func removeSubscription(_ id: String) {
        subscriptions.removeAll { $0.id == id }
        cancelledIds.remove(id)
        alerts.removeAll { $0.subscriptionId == id }

        if let ctx = modelContext {
            for row in ((try? ctx.fetch(FetchDescriptor<PersistentSubscription>())) ?? []) where row.id == id {
                ctx.delete(row)
            }
            if let alertRows = try? ctx.fetch(FetchDescriptor<PersistentAlert>()) {
                for a in alertRows where a.subscriptionId == id { ctx.delete(a) }
            }
            try? ctx.save()
        }
        clearCancellationAttempt(id)
        EvidenceLocker.remove(id)
        disputeRecords.removeValue(forKey: id)
        disputeFollowUps.removeValue(forKey: id)
        saveDisputeRecords()
        Task { await NotificationService.cancel(for: id) }
        updateWidgetSnapshot()
    }

    /// One-button data wipe — clears all imported subscriptions, alerts,
    /// cancellation history, dispute-letter usage, and the sample-mode flag,
    /// then drops the persistent SwiftData rows. Keeps the user signed in
    /// (profile + onboarded state preserved) and keeps any Pro entitlement
    /// active, so the user can re-import without going through onboarding
    /// again or losing their subscription. Notifications scheduled for the
    /// wiped subs are cancelled.
    func clearAllData() async {
        await NotificationService.cancelAll()
        subscriptions = []
        alerts = []
        cancelledIds = []
        disputeUsageDates = []
        cancellationAttempts = []
        saveCancellationAttempts()
        UserDefaults.standard.removeObject(forKey: "phantom.sampleMode")
        clearLedger()
        wipeClawbackState()
        clearAllPersistent()
        updateWidgetSnapshot()
    }

    /// Sign out of the Apple account inside Phantom. Data is left alone: it
    /// lives on this iPhone and in the user's own iCloud, and signing out
    /// must never be the thing that loses it.
    func signOut() async {
        AccountService.shared.signOut()
    }

    /// App Store Review Guideline 5.1.1(v): delete the account and everything
    /// it holds. Rows deleted here propagate to CloudKit, so the data is gone
    /// from every device, then the Apple ID is forgotten and onboarding shows.
    func deleteAccount() async {
        await NotificationService.cancelAll()
        subscriptions = []
        alerts = []
        cancelledIds = []
        cancellationAttempts = []
        saveCancellationAttempts()
        clearLedger()
        ownedBundleIds = []
        wipeClawbackState()
        clearAllPersistent()
        if let ctx = modelContext {
            for p in (try? ctx.fetch(FetchDescriptor<UserProfile>())) ?? [] { ctx.delete(p) }
            profile = nil
            try? ctx.save()
        }
        PrefsSync.shared.wipe()
        for key in PrefsSync.trackedKeys { UserDefaults.standard.removeObject(forKey: key) }
        // Nothing to delete in the CloudKit *public* database: Picks was parked
        // before release, so no user ever published anything. Keeping the call
        // would link the public database into the shipping app and contradict
        // the privacy policy's "no part of Phantom is public". If Picks is ever
        // revived, restore `await PicksService.shared.deleteMySubmissions()`
        // here — App Review guideline 5.1.1(v) requires it.
        AccountService.shared.signOut()
        updateWidgetSnapshot()
    }

    // MARK: - Transaction ledger (synced)

    /// Every charge ever imported, newest first.
    func ledgerTransactions() -> [ParsedTransaction] {
        ledgerEntries().map { $0.toTransaction() }
    }

    private func ledgerEntries() -> [TransactionLedger.Entry] {
        guard let ctx = modelContext else { return [] }
        let rows = (try? ctx.fetch(FetchDescriptor<PersistentTransaction>())) ?? []
        let deduped = Dedupe.byKey(rows, key: \.dedupeKey)
        if !deduped.drop.isEmpty {
            for extra in deduped.drop { ctx.delete(extra) }
            try? ctx.save()
        }
        return deduped.keep.map { $0.toEntry() }
            .sorted { ($0.date ?? $0.importedAt) > ($1.date ?? $1.importedAt) }
    }

    /// Merge an import into the ledger (dedupe, prune, cap — see TransactionLedger.merged).
    func recordLedger(_ txs: [ParsedTransaction]) {
        guard let ctx = modelContext else { return }
        let before = ledgerEntries()
        let after = TransactionLedger.merged(existing: before, incoming: txs)
        let keep = Set(after.map(\.dedupeKey))
        let rows = (try? ctx.fetch(FetchDescriptor<PersistentTransaction>())) ?? []
        var have = Set<String>()
        for row in rows {
            if keep.contains(row.dedupeKey) { have.insert(row.dedupeKey) } else { ctx.delete(row) }
        }
        for entry in after where !have.contains(entry.dedupeKey) {
            ctx.insert(PersistentTransaction(entry: entry))
        }
        try? ctx.save()
    }

    func clearLedger() {
        guard let ctx = modelContext else { return }
        for row in (try? ctx.fetch(FetchDescriptor<PersistentTransaction>())) ?? [] { ctx.delete(row) }
        try? ctx.save()
        TransactionLedger.clear()
    }

    /// Pre-sync installs kept the ledger in a JSON file; fold it in once.
    private func migrateLegacyLedgerIfNeeded() {
        let legacy = TransactionLedger.load()
        guard !legacy.isEmpty else { return }
        recordLedger(legacy.map { $0.toTransaction() })
        TransactionLedger.clear()
    }

    /// Periodic refresh — re-fetches the public price catalog, recomputes hike alerts.
    /// No-op for transactions (those come from on-device OCR).
    func sync() async {
        await refreshPriceAlerts()
        lastSync = Date()
    }

    // MARK: - Price hikes

    func refreshPriceAlerts() async {
        do {
            let prices = try await PriceMonitor.refresh()
            let matches = PriceMonitor.matches(in: activeSubs, catalog: prices)
            for m in matches {
                let a = PriceMonitor.alert(for: m)
                // Merge without dupes by subscriptionId+type+message
                guard !alerts.contains(where: { $0.subscriptionId == a.subscriptionId && $0.type == a.type && $0.message == a.message }) else { continue }
                alerts.append(a)
                persist(alert: a)
                // The catalog hike is now a fact about this sub: it feeds the
                // zombie score and the detail view, and (unlike a 7-day-ahead
                // trigger for a date already past) is announced right away.
                applyPriceHike(PriceHike(from: m.previous, to: m.current, effective: m.hikedAt ?? Date()), to: m.subId)
                if notifyHikes && notificationsAuthorized {
                    await NotificationService.postNow(
                        identifier: "hikenow-\(m.subId)-\(Int((m.hikedAt ?? Date()).timeIntervalSince1970))",
                        title: "\(m.subName) raised its price",
                        body: String(format: "$%.2f → $%.2f / month. Downgrade, negotiate, or cancel.", m.previous, m.current),
                        route: "subscription", id: m.subId
                    )
                }
            }
        } catch {
            // non-fatal — keep existing alerts
        }
        refreshInsightAlerts()
        await rescheduleAllNotifications()
        updateWidgetSnapshot()
    }

    /// Record a price hike on a sub (in memory + SwiftData).
    func applyPriceHike(_ hike: PriceHike, to id: String) {
        guard let i = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        let s = subscriptions[i]
        subscriptions[i] = Subscription(
            id: s.id, name: s.name, vendor: s.vendor, rawDescriptor: s.rawDescriptor,
            brandHex: s.brandHex, category: s.category, amount: s.amount, cycle: s.cycle,
            nextBilling: s.nextBilling, startedAt: s.startedAt, lastUsedAt: s.lastUsedAt,
            sessionsLast30d: s.sessionsLast30d, userRating: s.userRating, marketAverage: s.marketAverage,
            trialEndsAt: s.trialEndsAt, hasPriceHike: hike,
            hasOverlapWith: s.hasOverlapWith, notes: s.notes, billedVia: s.billedVia
        )
        if let idx = persistentSubs?.firstIndex(where: { $0.id == id }) {
            persistentSubs?[idx].hikeFrom = hike.from
            persistentSubs?[idx].hikeTo = hike.to
            persistentSubs?[idx].hikeEffective = hike.effective
        }
        save()
    }

    // MARK: - Notifications

    /// Called once per cold launch from `PhantomApp`. Refreshes the price
    /// catalog (which also reschedules notifications) and syncs auth state.
    /// Previously this only ran behind a Plaid token that never existed, so the
    /// entire alert/notification loop never fired on launch.
    func onLaunch() async {
        await refreshNotificationAuthorization()
        catalog = await AlternativesCatalogLoader.refresh(current: catalog)
        await refreshPriceAlerts()
        lastSync = Date()
    }

    func refreshNotificationAuthorization() async {
        let status = await NotificationService.currentAuthorization()
        notificationsAuthorized = (status == .authorized || status == .provisional)
    }

    /// Request OS permission (shows the system prompt if still undetermined).
    /// Returns whether notifications are now allowed.
    @discardableResult
    func enableNotifications() async -> Bool {
        let granted = await NotificationService.requestPermission()
        notificationsAuthorized = granted
        await rescheduleAllNotifications()
        return granted
    }

    /// Right after the first import is the highest-intent moment to ask for
    /// notification permission — the user just saw their subscriptions. Ask at
    /// most once; afterwards just sync state and reschedule.
    func requestNotificationsAfterFirstImport() async {
        let status = await NotificationService.currentAuthorization()
        if status == .notDetermined && !UserDefaults.standard.bool(forKey: NotifKey.didAsk) {
            UserDefaults.standard.set(true, forKey: NotifKey.didAsk)
            await enableNotifications()
        } else {
            await refreshNotificationAuthorization()
            await rescheduleAllNotifications()
        }
    }

    /// Single source of truth for what's scheduled. RECONCILES (adds missing,
    /// removes stale) rather than wiping and re-adding everything: relative-
    /// countdown triggers (zombie nudge, cancellation check) are left alone when
    /// already pending, so their clocks aren't reset on every launch/toggle —
    /// which previously meant they never fired. No-op if unauthorized.
    func rescheduleAllNotifications() async {
        guard notificationsAuthorized else {
            await NotificationService.cancelAll()
            return
        }
        let pending = await NotificationService.pendingIdentifiers()
        var desired = Set<String>()

        for sub in activeSubs {
            if notifyTrials, let trial = sub.trialEndsAt {
                desired.insert("trial-\(sub.id)")
                // Absolute-date trigger — safe to re-add (replaces in place).
                await NotificationService.scheduleTrialEnd(subscriptionId: sub.id, name: sub.name, trialEndsAt: trial)
            }
            if notifyHikes, let hike = sub.hasPriceHike {
                desired.insert("hike-\(sub.id)")
                await NotificationService.schedulePriceHike(
                    subscriptionId: sub.id, name: sub.name,
                    from: hike.from, to: hike.to, effective: hike.effective
                )
            }
            if notifyZombies {
                let s = score(for: sub.id)
                if s >= 80 {
                    let id = "zombie-\(sub.id)"
                    desired.insert(id)
                    // Only arm a NEW nudge; leave a running countdown intact.
                    if !pending.contains(id) {
                        await NotificationService.scheduleZombieNudge(subscriptionId: sub.id, name: sub.name, score: s)
                    }
                }
            }
        }
        // Verification reminders for pending cancellations, anchored to their
        // absolute ~35-day target so a reschedule doesn't slide them forward.
        for attempt in cancellationAttempts {
            let id = "cancelcheck-\(attempt.id)"
            desired.insert(id)
            if !pending.contains(id) {
                let target = attempt.attemptedAt.addingTimeInterval(35 * 86_400)
                await NotificationService.scheduleCancellationCheck(subscriptionId: attempt.id, name: attempt.name, fireAt: target)
            }
        }

        if notifyRescan, let last = lastImportAt {
            desired.insert("rescan")
            if !pending.contains("rescan") {
                let target = last.addingTimeInterval(28 * 86_400)
                await NotificationService.scheduleRescan(fireAt: target)
            }
        }

        for (subId, fireAt) in disputeFollowUps {
            let id = "disputefollow-\(subId)"
            desired.insert(id)
            if !pending.contains(id) {
                await NotificationService.scheduleDisputeFollowUp(
                    subscriptionId: subId,
                    name: subscription(byId: subId)?.name ?? "that charge",
                    fireAt: fireAt
                )
            }
        }

        // Re-engagement: nudge imported-but-unrated users to rate their subs (the
        // signal the score needs). Drops out the moment anything is rated.
        if notifyZombies, !activeSubs.isEmpty, activeSubs.allSatisfy({ $0.userRating == nil }) {
            desired.insert("ratenudge")
            if !pending.contains("ratenudge") {
                await NotificationService.scheduleRatingNudge()
            }
        }

        // Drop anything we scheduled before that's no longer wanted (sub cancelled,
        // toggle turned off, hike/trial cleared, a sub got rated). Leaves
        // unrelated ids untouched.
        let managedPrefixes = ["trial-", "hike-", "zombie-", "cancelcheck-", "disputefollow-"]
        let stale = pending.filter { id in
            (id == "ratenudge" || id == "rescan" || managedPrefixes.contains(where: { id.hasPrefix($0) })) && !desired.contains(id)
        }
        await NotificationService.remove(identifiers: Array(stale))
    }

    // MARK: - Mutations

    func cancel(_ id: String) {
        cancelledIds.insert(id)
        if let idx = persistentSubs?.firstIndex(where: { $0.id == id }) {
            persistentSubs?[idx].cancelled = true
            save()
        }
        Task { await NotificationService.cancel(for: id) }
    }

    /// The concierge path: mark cancelled AND start the verification loop (a
    /// reminder to re-scan next statement). This is what answers the "they said
    /// cancel but kept charging me" complaint.
    func confirmCancellation(_ id: String) {
        cancel(id)
        recordCancellationAttempt(for: id)
        // A realized cancel is a genuine win — the right (and only) moment to ask
        // for a rating. Fires at most once, never on launch or mid-flow.
        maybeRequestReview()
    }

    private static let didAskReviewKey = "phantom.didAskReview"

    /// Ask for an App Store rating once, after a positive outcome. Guarded by a
    /// one-time flag like the notification ask, so we never burn the prompt.
    private func maybeRequestReview() {
        guard !UserDefaults.standard.bool(forKey: Self.didAskReviewKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.didAskReviewKey)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    func reactivate(_ id: String) {
        cancelledIds.remove(id)
        if let idx = persistentSubs?.firstIndex(where: { $0.id == id }) {
            persistentSubs?[idx].cancelled = false
            save()
        }
    }

    /// Recompute same-kind overlap across the whole library. Two or more active
    /// subs sharing a substitutable kind (video + video, music + music) flag
    /// each other — this is what lets the zombie score surface duplicate
    /// streaming / AI / news subscriptions. Kinds are finer than categories on
    /// purpose: Netflix and Spotify are both "Entertainment" but not duplicates.
    func recomputeOverlaps() {
        let overlaps = Overlaps.compute(subscriptions, cancelledIds: cancelledIds)
        for i in subscriptions.indices {
            subscriptions[i].hasOverlapWith = overlaps[subscriptions[i].id] ?? []
        }
    }

    /// Persist the user's 1–5 rating for a sub. This is the strongest signal the
    /// zombie score has on imported subs (usage data is unavailable on-device),
    /// so collecting it is what turns a flat import into a real ranking.
    func setRating(_ rating: Int?, for id: String) {
        guard let i = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        let s = subscriptions[i]
        subscriptions[i] = Subscription(
            id: s.id, name: s.name, vendor: s.vendor, rawDescriptor: s.rawDescriptor,
            brandHex: s.brandHex, category: s.category, amount: s.amount, cycle: s.cycle,
            nextBilling: s.nextBilling, startedAt: s.startedAt, lastUsedAt: s.lastUsedAt,
            sessionsLast30d: s.sessionsLast30d, userRating: rating, marketAverage: s.marketAverage,
            trialEndsAt: s.trialEndsAt, hasPriceHike: s.hasPriceHike,
            hasOverlapWith: s.hasOverlapWith, notes: s.notes, billedVia: s.billedVia
        )
        if let idx = persistentSubs?.firstIndex(where: { $0.id == id }) {
            persistentSubs?[idx].userRating = rating
        }
        save()
        Task { await rescheduleAllNotifications() }
    }

    func markAlertRead(_ id: String) {
        if let idx = alerts.firstIndex(where: { $0.id == id }) {
            alerts[idx].read = true
        }
        if let p = try? modelContext?.fetch(FetchDescriptor<PersistentAlert>()).first(where: { $0.id == id }) {
            p.read = true
            save()
        }
    }

    func togglePro() {
        // Only used as debug shortcut — real Pro state comes from PurchaseService
    }

    // MARK: - SwiftData glue

    private var persistentSubs: [PersistentSubscription]?

    private func loadFromDisk() {
        guard let ctx = modelContext else { return }
        // Profile (single row)
        let profileFetch = FetchDescriptor<UserProfile>()
        let profiles = (try? ctx.fetch(profileFetch)) ?? []
        // Two devices can each create the "default" profile before they sync;
        // keep the one that finished onboarding / has a name.
        let profileDedupe = Dedupe.byKey(profiles, key: \.id, prefer: { a, b in
            (a.onboardedAt != nil && b.onboardedAt == nil) || (!a.fullName.isEmpty && b.fullName.isEmpty)
        })
        var dirty = false
        for extra in profileDedupe.drop { ctx.delete(extra); dirty = true }
        if let existing = profileDedupe.keep.first {
            profile = existing
        } else {
            let new = UserProfile()
            ctx.insert(new)
            profile = new
            dirty = true
        }
        // Subscriptions — CloudKit can't enforce unique ids, so drop dupes here.
        let subFetch = FetchDescriptor<PersistentSubscription>()
        let subRows = (try? ctx.fetch(subFetch)) ?? []
        let subDedupe = Dedupe.byKey(subRows, key: \.id, prefer: { $0.updatedAt > $1.updatedAt })
        for extra in subDedupe.drop { ctx.delete(extra); dirty = true }
        let subs = subDedupe.keep
        persistentSubs = subs
        subscriptions = subs.map { $0.toDomain() }
        cancelledIds = Set(subs.filter { $0.cancelled }.map { $0.id })
        recomputeOverlaps()
        // Alerts
        let alertFetch = FetchDescriptor<PersistentAlert>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let aRows = (try? ctx.fetch(alertFetch)) ?? []
        let alertDedupe = Dedupe.byKey(aRows, key: \.id)
        for extra in alertDedupe.drop { ctx.delete(extra); dirty = true }
        alerts = alertDedupe.keep.map { $0.toDomain() }
        if dirty { try? ctx.save() }
    }

    private func ensureProfile() {
        guard let ctx = modelContext else { return }
        if profile == nil {
            let p = UserProfile()
            ctx.insert(p)
            profile = p
        }
    }

    /// Upsert by id (not wipe-and-rewrite): CloudKit syncs row changes, so
    /// rewriting everything on each import would churn every record on every
    /// device and could delete a row another device just added.
    private func persistAllSubscriptions() {
        guard let ctx = modelContext else { return }
        let existing = (try? ctx.fetch(FetchDescriptor<PersistentSubscription>())) ?? []
        var byId: [String: PersistentSubscription] = [:]
        for row in existing {
            if byId[row.id] == nil { byId[row.id] = row } else { ctx.delete(row) }
        }
        let wanted = Set(subscriptions.map(\.id))
        for (id, row) in byId where !wanted.contains(id) { ctx.delete(row) }
        for sub in subscriptions {
            let cancelled = cancelledIds.contains(sub.id)
            if let row = byId[sub.id] {
                row.apply(sub, cancelled: cancelled)
            } else {
                ctx.insert(PersistentSubscription(from: sub, cancelled: cancelled))
            }
        }
        try? ctx.save()
        persistentSubs = try? ctx.fetch(FetchDescriptor<PersistentSubscription>())
    }

    private func persistAllAlerts() {
        guard let ctx = modelContext else { return }
        let existing = (try? ctx.fetch(FetchDescriptor<PersistentAlert>())) ?? []
        var byId: [String: PersistentAlert] = [:]
        for row in existing {
            if byId[row.id] == nil { byId[row.id] = row } else { ctx.delete(row) }
        }
        let wanted = Set(alerts.map(\.id))
        for (id, row) in byId where !wanted.contains(id) { ctx.delete(row) }
        for a in alerts where byId[a.id] == nil { ctx.insert(PersistentAlert(from: a)) }
        try? ctx.save()
    }

    private func persist(alert: PriceAlert) {
        guard let ctx = modelContext else { return }
        ctx.insert(PersistentAlert(from: alert))
        try? ctx.save()
    }

    private func clearAllPersistent() {
        guard let ctx = modelContext else { return }
        if let subs = try? ctx.fetch(FetchDescriptor<PersistentSubscription>()) {
            for row in subs { ctx.delete(row) }
        }
        if let als = try? ctx.fetch(FetchDescriptor<PersistentAlert>()) {
            for row in als { ctx.delete(row) }
        }
        try? ctx.save()
    }

    private func wipeClawbackState() {
        lastImportAt = nil
        UserDefaults.standard.removeObject(forKey: NotifKey.lastImport)
        disputeRecords = [:]
        disputeFollowUps = [:]
        saveDisputeRecords()
        EvidenceLocker.removeAll()
    }

    private func save() {
        try? modelContext?.save()
        updateWidgetSnapshot()
    }

    // MARK: - Cancellation concierge

    /// Record that the user said they cancelled at the vendor. Schedules a
    /// one-time verification reminder ~one billing cycle out and surfaces the
    /// sub in the "pending verification" list until confirmed gone.
    func recordCancellationAttempt(for id: String) {
        guard let sub = subscription(byId: id) else { return }
        let attempt = CancellationAttempt(id: sub.id, name: sub.name, monthlyAmount: sub.monthlyAmount, attemptedAt: Date())
        cancellationAttempts.removeAll { $0.id == sub.id }
        cancellationAttempts.append(attempt)
        saveCancellationAttempts()
        Task {
            if notificationsAuthorized {
                let target = attempt.attemptedAt.addingTimeInterval(35 * 86_400)
                await NotificationService.scheduleCancellationCheck(subscriptionId: sub.id, name: sub.name, fireAt: target)
            } else {
                await requestNotificationsAfterFirstImport()
            }
        }
    }

    func clearCancellationAttempt(_ id: String) {
        cancellationAttempts.removeAll { $0.id == id }
        saveCancellationAttempts()
        Task { await NotificationService.cancelCancellationCheck(for: id) }
    }

    // MARK: - Widget

    /// Write the denormalized snapshot the Home/Lock Screen widget reads, then
    /// ask WidgetKit to refresh. Called on every data change via `save()`.
    func updateWidgetSnapshot() {
        // Soonest UPCOMING charge — filter out dates already in the past, else the
        // widget headlines the oldest (overdue) sub once a billing cycle elapses.
        let now = Date()
        let next = activeSubs
            .filter { $0.nextBilling >= now }
            .min { $0.nextBilling < $1.nextBilling }
        let snapshot = SharedStore.Snapshot(
            monthlyTotal: monthlyTotal,
            yearlyTotal: yearlyTotal,
            activeCount: activeSubs.count,
            zombieCount: zombieCount,
            potentialYearlySavings: potentialYearlySavings,
            realizedYearlySavings: realizedYearlySavings,
            nextChargeName: next?.name,
            nextChargeAmount: next?.amount,
            nextChargeDate: next?.nextBilling,
            updatedAt: Date()
        )
        SharedStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
