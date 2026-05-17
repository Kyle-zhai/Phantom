import Foundation
import SwiftUI

enum Category: String, Codable, CaseIterable {
    case entertainment = "Entertainment"
    case tools = "Tools"
    case health = "Health"
    case shopping = "Shopping"
    case news = "News"
    case other = "Other"
}

enum BillingCycle: String, Codable {
    case monthly, yearly, weekly
}

struct PriceHike: Codable, Hashable {
    let from: Double
    let to: Double
    let effective: Date
}

struct Subscription: Identifiable, Codable, Hashable {
    let id: String
    /// Clean, brand-aware display name shown in list views (e.g. "Netflix",
    /// "Apple Music", "Amazon Prime"). Derived from `brandId` when a known
    /// brand was matched; falls back to the normalized merchant text.
    let name: String
    let vendor: String
    /// The raw merchant string as it appeared on the user's bank statement
    /// after normalization (e.g. "APL*APPLE MUSIC", "GOOGLE *YouTube Music",
    /// "AMZN PRIME*RT3JK 866-216-1072 WA"). Shown only in the detail view
    /// so users can confirm the match against their actual statement.
    /// Optional for backwards compatibility with subs persisted before this
    /// field existed and with manually-added subs where it has no meaning.
    var rawDescriptor: String? = nil
    let brandHex: String
    let category: Category
    let amount: Double
    let cycle: BillingCycle
    let nextBilling: Date
    let startedAt: Date
    let lastUsedAt: Date?
    let sessionsLast30d: Int
    let userRating: Int?
    let marketAverage: Double
    let trialEndsAt: Date?
    let hasPriceHike: PriceHike?
    let hasOverlapWith: [String]
    let notes: String?

    var brandColor: Color {
        Color(hex: brandHex) ?? Palette.ink
    }

    var monthlyAmount: Double {
        switch cycle {
        case .yearly: return amount / 12
        case .weekly: return amount * 4.33
        case .monthly: return amount
        }
    }

    /// True annual cost based on the actual billing cycle — avoids the
    /// rounding artifact you get from monthlyAmount * 12 when cycle is yearly
    /// (199.99 / 12 * 12 → 199.989999…).
    var yearlyAmount: Double {
        switch cycle {
        case .yearly:  return amount
        case .weekly:  return amount * 52
        case .monthly: return amount * 12
        }
    }

    var cycleLabel: String {
        switch cycle {
        case .yearly:  return "Yearly"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

enum AlertType: String, Codable {
    case hike, trialEnding, newCharge, unused
}

struct PriceAlert: Identifiable, Codable, Hashable {
    var id: String
    let subscriptionId: String
    let type: AlertType
    let title: String
    let message: String
    let createdAt: Date
    var read: Bool
}

extension Color {
    init?(hex: String) {
        var s = hex.uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v & 0xFF0000) >> 16) / 255.0
        let g = Double((v & 0x00FF00) >> 8) / 255.0
        let b = Double(v & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
