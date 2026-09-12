import Foundation
import SwiftData

/// SwiftData-backed persistent models. The in-memory `Subscription` struct in
/// `Models.swift` is the view-layer type; `PersistentSubscription` mirrors it
/// for on-device storage. We keep them separate so unit tests / mock data don't
/// need SwiftData to construct.
///
/// CloudKit rules (the store syncs to the user's private iCloud database):
/// no `@Attribute(.unique)`, every stored property optional or defaulted, no
/// required relationships. Uniqueness by `id` / `key` is enforced in code
/// (`Dedupe`) because two devices can legitimately create the same row offline.
@Model
final class PersistentSubscription {
    var id: String = ""
    var name: String = ""
    var vendor: String = ""
    /// Raw merchant text as seen on the bank statement. Optional with a
    /// default so existing SwiftData stores from before this column existed
    /// don't break migration — SwiftData treats nil as "missing column".
    var rawDescriptor: String? = nil
    var brandHex: String = "000000"
    var categoryRaw: String = Category.other.rawValue
    var amount: Double = 0
    var cycleRaw: String = BillingCycle.monthly.rawValue
    var nextBilling: Date = Date()
    var startedAt: Date = Date()
    var lastUsedAt: Date? = nil
    var sessionsLast30d: Int = 0
    var userRating: Int? = nil
    var marketAverage: Double = 0
    var trialEndsAt: Date? = nil
    var hikeFrom: Double? = nil
    var hikeTo: Double? = nil
    var hikeEffective: Date? = nil
    var overlapWith: [String] = []
    var notes: String? = nil
    var cancelled: Bool = false
    /// Optional with a default (see rawDescriptor) so stores created before
    /// this column existed migrate without a schema version.
    var billedViaRaw: String? = nil
    /// Newest wins when two devices produced the same `id`.
    var updatedAt: Date = Date()

    init(from sub: Subscription, cancelled: Bool = false) {
        apply(sub, cancelled: cancelled)
    }

    func apply(_ sub: Subscription, cancelled: Bool) {
        self.id = sub.id
        self.name = sub.name
        self.vendor = sub.vendor
        self.rawDescriptor = sub.rawDescriptor
        self.brandHex = sub.brandHex
        self.categoryRaw = sub.category.rawValue
        self.amount = sub.amount
        self.cycleRaw = sub.cycle.rawValue
        self.nextBilling = sub.nextBilling
        self.startedAt = sub.startedAt
        self.lastUsedAt = sub.lastUsedAt
        self.sessionsLast30d = sub.sessionsLast30d
        self.userRating = sub.userRating
        self.marketAverage = sub.marketAverage
        self.trialEndsAt = sub.trialEndsAt
        self.hikeFrom = sub.hasPriceHike?.from
        self.hikeTo = sub.hasPriceHike?.to
        self.hikeEffective = sub.hasPriceHike?.effective
        self.overlapWith = sub.hasOverlapWith
        self.notes = sub.notes
        self.cancelled = cancelled
        self.billedViaRaw = sub.billedVia?.rawValue
        self.updatedAt = Date()
    }

    func toDomain() -> Subscription {
        let cat = Category(rawValue: categoryRaw) ?? .other
        let cyc = BillingCycle(rawValue: cycleRaw) ?? .monthly
        let hike: PriceHike? = {
            if let f = hikeFrom, let t = hikeTo, let e = hikeEffective {
                return PriceHike(from: f, to: t, effective: e)
            }
            return nil
        }()
        return Subscription(
            id: id, name: name, vendor: vendor, rawDescriptor: rawDescriptor, brandHex: brandHex,
            category: cat, amount: amount, cycle: cyc,
            nextBilling: nextBilling, startedAt: startedAt,
            lastUsedAt: lastUsedAt, sessionsLast30d: sessionsLast30d,
            userRating: userRating, marketAverage: marketAverage,
            trialEndsAt: trialEndsAt, hasPriceHike: hike,
            hasOverlapWith: overlapWith, notes: notes,
            billedVia: billedViaRaw.flatMap(BillingSource.init(rawValue:))
        )
    }
}

@Model
final class PersistentAlert {
    var id: String = ""
    var subscriptionId: String = ""
    var typeRaw: String = AlertType.unused.rawValue
    var title: String = ""
    var message: String = ""
    var createdAt: Date = Date()
    var read: Bool = false

    init(from alert: PriceAlert) {
        self.id = alert.id
        self.subscriptionId = alert.subscriptionId
        self.typeRaw = alert.type.rawValue
        self.title = alert.title
        self.message = alert.message
        self.createdAt = alert.createdAt
        self.read = alert.read
    }

    func toDomain() -> PriceAlert {
        let t = AlertType(rawValue: typeRaw) ?? .unused
        return PriceAlert(
            id: id, subscriptionId: subscriptionId,
            type: t, title: title, message: message,
            createdAt: createdAt, read: read
        )
    }
}

@Model
final class UserProfile {
    var id: String = "default"
    var fullName: String = ""
    var email: String = ""
    var onboardedAt: Date? = nil
    var plaidConnected: Bool = false

    init(id: String = "default", fullName: String = "", email: String = "") {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.onboardedAt = nil
        self.plaidConnected = false
    }
}

/// One imported charge. The ledger is what confirms recurrence across months
/// and detects hikes on the statement; syncing it means a re-scan on the
/// iPad confirms what the iPhone saw.
@Model
final class PersistentTransaction {
    var dedupeKey: String = ""
    var merchant: String = ""
    var amount: Double = 0
    var date: Date? = nil
    var recurringHint: Bool = false
    var rawRow: String = ""
    var importedAt: Date = Date()

    init(entry: TransactionLedger.Entry) {
        self.dedupeKey = entry.dedupeKey
        self.merchant = entry.merchant
        self.amount = entry.amount
        self.date = entry.date
        self.recurringHint = entry.recurringHint
        self.rawRow = entry.rawRow
        self.importedAt = entry.importedAt
    }

    func toEntry() -> TransactionLedger.Entry {
        TransactionLedger.Entry(merchant: merchant, amount: amount, date: date,
                                recurringHint: recurringHint, rawRow: rawRow, importedAt: importedAt)
    }
}

/// Cancel proof (confirmation number, notes, screenshot). External storage
/// keeps the JPEG out of the row; CloudKit carries it as an asset.
@Model
final class PersistentEvidence {
    var id: String = ""
    var confirmationNumber: String = ""
    var notes: String = ""
    var cancelledAt: Date = Date()
    var method: String = ""
    @Attribute(.externalStorage) var screenshot: Data? = nil

    init(id: String) {
        self.id = id
    }
}

/// Small preferences that used to live only in UserDefaults (owned bundles,
/// cancellation attempts, dispute records, notification toggles). Mirrored
/// here so they follow the user's iCloud account. `value` is a plist blob.
@Model
final class PersistentSetting {
    var key: String = ""
    var value: Data = Data()
    var updatedAt: Date = Date()

    init(key: String, value: Data) {
        self.key = key
        self.value = value
        self.updatedAt = Date()
    }
}
