import Foundation
import SwiftData

/// SwiftData-backed persistent models. The in-memory `Subscription` struct in
/// `Models.swift` is the view-layer type; this `PersistentSubscription` mirrors it
/// for on-device storage. We keep them separate so unit tests / mock data don't
/// need SwiftData to construct.
@Model
final class PersistentSubscription {
    @Attribute(.unique) var id: String
    var name: String
    var vendor: String
    var brandHex: String
    var categoryRaw: String
    var amount: Double
    var cycleRaw: String
    var nextBilling: Date
    var startedAt: Date
    var lastUsedAt: Date?
    var sessionsLast30d: Int
    var userRating: Int?
    var marketAverage: Double
    var trialEndsAt: Date?
    var hikeFrom: Double?
    var hikeTo: Double?
    var hikeEffective: Date?
    var overlapWith: [String]
    var notes: String?
    var cancelled: Bool

    init(from sub: Subscription, cancelled: Bool = false) {
        self.id = sub.id
        self.name = sub.name
        self.vendor = sub.vendor
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
            id: id, name: name, vendor: vendor, brandHex: brandHex,
            category: cat, amount: amount, cycle: cyc,
            nextBilling: nextBilling, startedAt: startedAt,
            lastUsedAt: lastUsedAt, sessionsLast30d: sessionsLast30d,
            userRating: userRating, marketAverage: marketAverage,
            trialEndsAt: trialEndsAt, hasPriceHike: hike,
            hasOverlapWith: overlapWith, notes: notes
        )
    }
}

@Model
final class PersistentAlert {
    @Attribute(.unique) var id: String
    var subscriptionId: String
    var typeRaw: String
    var title: String
    var message: String
    var createdAt: Date
    var read: Bool

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
    @Attribute(.unique) var id: String
    var fullName: String
    var email: String
    var onboardedAt: Date?
    var plaidConnected: Bool

    init(id: String = "default", fullName: String = "", email: String = "") {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.onboardedAt = nil
        self.plaidConnected = false
    }
}
