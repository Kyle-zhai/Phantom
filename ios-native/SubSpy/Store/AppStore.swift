import Foundation
import Observation
import SwiftData
import UserNotifications

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

    private(set) var profile: UserProfile?
    private(set) var purchaseService: PurchaseService

    private var modelContext: ModelContext?

    var isOnboarded: Bool {
        if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { return true }
        if ProcessInfo.processInfo.arguments.contains("--demo") { return true }
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
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo") && subscriptions.isEmpty {
            subscriptions = MockData.subscriptions
            alerts = MockData.alerts
            persistAllSubscriptions()
            persistAllAlerts()
            ensureProfile()
            profile?.fullName = profile?.fullName.isEmpty ?? true ? "Demo User" : profile!.fullName
            profile?.email = profile?.email.isEmpty ?? true ? "demo@subspy.app" : profile!.email
            profile?.onboardedAt = Date()
            save()
        }
        #endif
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

    var unreadAlerts: Int { alerts.filter { !$0.read }.count }

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
        #if DEBUG
        if viaDemo && subscriptions.isEmpty {
            subscriptions = MockData.subscriptions
            alerts = MockData.alerts
            persistAllSubscriptions()
            persistAllAlerts()
        }
        #endif
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
            }
        }
        subscriptions = merged
        persistAllSubscriptions()
        ensureProfile()
        profile?.onboardedAt = profile?.onboardedAt ?? Date()
        save()
        Task { await refreshPriceAlerts() }
    }

    /// Disconnect bank only — keep account, history, ratings.
    func disconnectBank() {
        Keychain.clear(.plaidAccessToken)
        Keychain.clear(.plaidItemId)
        profile?.plaidConnected = false
        save()
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
        clearAllPersistent()
        if let ctx = modelContext, let p = profile {
            ctx.delete(p)
            profile = nil
            try? ctx.save()
        }
    }

    /// Hard delete — same as sign out plus a server-side request to forget the user.
    /// Required by App Store Review Guideline 5.1.1(v) for any app that creates accounts.
    func deleteAccount() async {
        // Best-effort backend delete — if it fails, still wipe local data
        if let userId = Keychain.get(.userId) {
            struct Req: Encodable { let userId: String }
            struct Empty: Decodable {}
            _ = try? await APIClient.shared.post("/account/delete", body: Req(userId: userId), as: Empty.self)
        }
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
            await scheduleNotificationsForUpcomingHikes(catalog: catalog)
        } catch {
            // non-fatal — keep existing alerts
        }
    }

    private func scheduleNotificationsForUpcomingHikes(catalog: [PriceMonitor.RemotePrice]) async {
        for sub in activeSubs {
            if let trial = sub.trialEndsAt {
                await NotificationService.scheduleTrialEnd(subscriptionId: sub.id, name: sub.name, trialEndsAt: trial)
            }
            if let hike = sub.hasPriceHike {
                await NotificationService.schedulePriceHike(
                    subscriptionId: sub.id, name: sub.name,
                    from: hike.from, to: hike.to, effective: hike.effective
                )
            }
            let s = score(for: sub.id)
            if s >= 80 {
                await NotificationService.scheduleZombieNudge(subscriptionId: sub.id, name: sub.name, score: s)
            }
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
    }
}
