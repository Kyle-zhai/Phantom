import Foundation
import Observation
import SwiftData
import UserNotifications
import WidgetKit

/// Single source of truth for the app. Persists to SwiftData, pulls real data
/// from Plaid (via backend) and the price monitor, schedules real notifications.
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

    private enum NotifKey {
        static let hikes = "phantom.notif.hikes"
        static let trials = "phantom.notif.trials"
        static let zombies = "phantom.notif.zombies"
        static let didAsk = "phantom.notif.didAsk"
    }

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
        loadFromDisk()
        loadDisputeUsage()
        loadNotificationPrefs()
        loadCancellationAttempts()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo") && subscriptions.isEmpty {
            seedSampleData()
        }
        #endif
        updateWidgetSnapshot()
    }

    private func loadNotificationPrefs() {
        let d = UserDefaults.standard
        notifyHikes = d.object(forKey: NotifKey.hikes) as? Bool ?? true
        notifyTrials = d.object(forKey: NotifKey.trials) as? Bool ?? true
        notifyZombies = d.object(forKey: NotifKey.zombies) as? Bool ?? true
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
        clearAllPersistent()
        UserDefaults.standard.removeObject(forKey: "phantom.sampleMode")
        // Keep the profile and onboardedAt — user gets to skip onboarding
        save()
    }

    var scoresById: [String: Int] {
        Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, ZombieScore.compute($0).score) })
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
        clearAllPersistent()
        Keychain.clear(.plaidAccessToken)
        Keychain.clear(.plaidItemId)
        save()
    }

    /// Merge subscriptions detected from OCR'd screenshots into the live list.
    /// Existing user-tweaked fields (rating, lastUsedAt) are preserved when merging by id.
    func mergeImported(subs: [Subscription], transactions: [ParsedTransaction]) {
        let existing = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })
        var merged = subscriptions
        var newlyAdded: [Subscription] = []
        for new in subs {
            if let cur = existing[new.id] {
                // Update price/cycle/dates, keep user data
                let updated = Subscription(
                    id: cur.id, name: new.name, vendor: new.vendor,
                    brandHex: cur.brandHex, category: cur.category,
                    amount: new.amount, cycle: new.cycle,
                    nextBilling: new.nextBilling,
                    startedAt: min(cur.startedAt, new.startedAt),
                    lastUsedAt: cur.lastUsedAt,
                    sessionsLast30d: cur.sessionsLast30d,
                    userRating: cur.userRating,
                    marketAverage: cur.marketAverage > 0 ? cur.marketAverage : new.marketAverage,
                    trialEndsAt: cur.trialEndsAt,
                    hasPriceHike: cur.hasPriceHike,
                    hasOverlapWith: cur.hasOverlapWith,
                    notes: new.notes
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
        persistAllSubscriptions()
        ensureProfile()
        profile?.onboardedAt = profile?.onboardedAt ?? Date()

        // Surface the new subs in the Alerts tab so the user has something
        // to act on (and so the tab isn't empty right after their first import).
        for sub in newlyAdded {
            let dateStr: String = {
                let f = DateFormatter()
                f.dateStyle = .medium
                return f.string(from: sub.startedAt)
            }()
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
        save()
        Task {
            await refreshPriceAlerts()
            await requestNotificationsAfterFirstImport()
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
            if let row = try? ctx.fetch(FetchDescriptor<PersistentSubscription>()).first(where: { $0.id == id }) {
                ctx.delete(row)
            }
            if let alertRows = try? ctx.fetch(FetchDescriptor<PersistentAlert>()) {
                for a in alertRows where a.subscriptionId == id { ctx.delete(a) }
            }
            try? ctx.save()
        }
        clearCancellationAttempt(id)
        Task { await NotificationService.cancel(for: id) }
        updateWidgetSnapshot()
    }

    /// Disconnect bank only — keep account, history, ratings.
    func disconnectBank() {
        Keychain.clear(.plaidAccessToken)
        Keychain.clear(.plaidItemId)
        profile?.plaidConnected = false
        save()
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
        clearAllPersistent()
        updateWidgetSnapshot()
    }

    /// App Store-compliant sign out: clear everything and return to onboarding.
    func signOut() async {
        await NotificationService.cancelAll()
        Keychain.clear(.plaidAccessToken)
        Keychain.clear(.plaidItemId)
        Keychain.clear(.userId)
        subscriptions = []
        alerts = []
        cancelledIds = []
        cancellationAttempts = []
        saveCancellationAttempts()
        clearAllPersistent()
        if let ctx = modelContext, let p = profile {
            ctx.delete(p)
            profile = nil
            try? ctx.save()
        }
        updateWidgetSnapshot()
    }

    /// Hard delete — same as sign out plus a one-time backend purge. Since
    /// the current shipping app does not create server-side accounts (OCR
    /// runs entirely on-device, no signup flow populates Keychain.userId),
    /// there's nothing to purge server-side; this collapses to the local
    /// wipe. Kept as a separate method so the Settings UX language ("Delete
    /// account") matches App Store Review Guideline 5.1.1(v) terminology
    /// for any user-visible "account" concept. If a real backend lands,
    /// re-add an APIClient.post("/account/delete", …) call here.
    func deleteAccount() async {
        await signOut()
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
            let catalog = try await PriceMonitor.refresh()
            let newAlerts = PriceMonitor.detectHikes(in: activeSubs, catalog: catalog)
            // Merge without dupes by subscriptionId+type+message
            for a in newAlerts where !alerts.contains(where: { $0.subscriptionId == a.subscriptionId && $0.type == a.type && $0.message == a.message }) {
                alerts.append(a)
                persist(alert: a)
            }
        } catch {
            // non-fatal — keep existing alerts
        }
        await rescheduleAllNotifications()
        updateWidgetSnapshot()
    }

    // MARK: - Notifications

    /// Called once per cold launch from `PhantomApp`. Refreshes the price
    /// catalog (which also reschedules notifications) and syncs auth state.
    /// Previously this only ran behind a Plaid token that never existed, so the
    /// entire alert/notification loop never fired on launch.
    func onLaunch() async {
        await refreshNotificationAuthorization()
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

    /// Single source of truth for what's scheduled. Clears everything and
    /// re-adds only what the user opted into and what's still relevant. No-op
    /// scheduling if unauthorized (iOS would drop them anyway).
    func rescheduleAllNotifications() async {
        await NotificationService.cancelAll()
        guard notificationsAuthorized else { return }
        for sub in activeSubs {
            if notifyTrials, let trial = sub.trialEndsAt {
                await NotificationService.scheduleTrialEnd(subscriptionId: sub.id, name: sub.name, trialEndsAt: trial)
            }
            if notifyHikes, let hike = sub.hasPriceHike {
                await NotificationService.schedulePriceHike(
                    subscriptionId: sub.id, name: sub.name,
                    from: hike.from, to: hike.to, effective: hike.effective
                )
            }
            if notifyZombies {
                let s = score(for: sub.id)
                if s >= 80 {
                    await NotificationService.scheduleZombieNudge(subscriptionId: sub.id, name: sub.name, score: s)
                }
            }
        }
        // Verification reminders for pending cancellations survive a reschedule.
        for attempt in cancellationAttempts {
            let elapsed = Date().timeIntervalSince(attempt.attemptedAt)
            let remaining = max(1, 35 - Int(elapsed / 86_400))
            await NotificationService.scheduleCancellationCheck(subscriptionId: attempt.id, name: attempt.name, afterDays: remaining)
        }
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
    }

    func reactivate(_ id: String) {
        cancelledIds.remove(id)
        if let idx = persistentSubs?.firstIndex(where: { $0.id == id }) {
            persistentSubs?[idx].cancelled = false
            save()
        }
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
        if let existing = profiles.first {
            profile = existing
        } else {
            let new = UserProfile()
            ctx.insert(new)
            profile = new
            try? ctx.save()
        }
        // Subscriptions
        let subFetch = FetchDescriptor<PersistentSubscription>()
        let subs = (try? ctx.fetch(subFetch)) ?? []
        persistentSubs = subs
        subscriptions = subs.map { $0.toDomain() }
        cancelledIds = Set(subs.filter { $0.cancelled }.map { $0.id })
        // Alerts
        let alertFetch = FetchDescriptor<PersistentAlert>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let aRows = (try? ctx.fetch(alertFetch)) ?? []
        alerts = aRows.map { $0.toDomain() }
    }

    private func ensureProfile() {
        guard let ctx = modelContext else { return }
        if profile == nil {
            let p = UserProfile()
            ctx.insert(p)
            profile = p
        }
    }

    private func persistAllSubscriptions() {
        guard let ctx = modelContext else { return }
        // Wipe and rewrite
        if let existing = try? ctx.fetch(FetchDescriptor<PersistentSubscription>()) {
            for row in existing { ctx.delete(row) }
        }
        for sub in subscriptions {
            ctx.insert(PersistentSubscription(from: sub, cancelled: cancelledIds.contains(sub.id)))
        }
        persistentSubs = try? ctx.fetch(FetchDescriptor<PersistentSubscription>())
        try? ctx.save()
    }

    private func persistAllAlerts() {
        guard let ctx = modelContext else { return }
        if let existing = try? ctx.fetch(FetchDescriptor<PersistentAlert>()) {
            for row in existing { ctx.delete(row) }
        }
        for a in alerts { ctx.insert(PersistentAlert(from: a)) }
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
                await NotificationService.scheduleCancellationCheck(subscriptionId: sub.id, name: sub.name, afterDays: 35)
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
        let next = activeSubs.min { $0.nextBilling < $1.nextBilling }
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
