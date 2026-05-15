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
    let name: String
    let vendor: String
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
