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

/// Fine-grained product kind. `Category` is the coarse, user-facing bucket
/// persisted on each sub; `Kind` is derived from the brand id at runtime and is
/// what overlap / bundle-coverage / alternatives reason about. Two subs only
/// "overlap" when they share a kind (Netflix + Hulu), never merely a category
/// (Netflix + Spotify are both Entertainment but are not substitutes).
enum Kind: String, Codable, CaseIterable {
    case video, liveTV, sports, music, audiobooks, podcasts, news
    case cloudStorage, passwordManager, vpn, security, email
    case aiAssistant, aiCoding, devTools, webHosting, productivity, creative
    case learning, kids
    case fitness, meditation, health, mealKit
    case delivery, retailMembership, telecom, gaming
    case dating, socialMedia, creatorSupport
    case homeSecurity, auto, finance
    /// App Store / Google Play-billed charge whose product we can't tell from
    /// the statement (APPLE.COM/BILL, GOOGLE *). Never overlaps and never gets
    /// an alternative — the user is pointed at the platform's subscription list.
    case platformBilled
    case other

    /// Kinds where two active subs are plausible substitutes for each other.
    /// Excluded: telecom (internet + wireless are not duplicates), generic
    /// buckets, and kinds whose members do genuinely different jobs — two
    /// creators, X Premium vs LinkedIn Premium, therapy vs a prescription
    /// service, a car wash vs connected-car data, two kids' apps a family
    /// keeps on purpose.
    var participatesInOverlap: Bool {
        switch self {
        case .telecom, .platformBilled, .other, .devTools,
             .creatorSupport, .socialMedia, .health, .auto, .kids: return false
        default: return true
        }
    }

    /// Coarse bucket used by the persisted `Category`. Keeps one source of
    /// truth as the kind list grows instead of a second hand-maintained map.
    var category: Category {
        switch self {
        case .video, .liveTV, .sports, .music, .audiobooks, .podcasts,
             .gaming, .creatorSupport, .kids:
            return .entertainment
        case .news:
            return .news
        case .cloudStorage, .passwordManager, .vpn, .security, .email,
             .aiAssistant, .aiCoding, .devTools, .webHosting, .productivity,
             .creative, .learning, .finance:
            return .tools
        case .fitness, .meditation, .health:
            return .health
        case .delivery, .retailMembership, .mealKit, .telecom, .homeSecurity, .auto:
            return .shopping
        case .dating, .socialMedia, .platformBilled, .other:
            return .other
        }
    }

    var label: String {
        switch self {
        case .video: return "Video streaming"
        case .liveTV: return "Live TV"
        case .sports: return "Sports"
        case .podcasts: return "Podcasts"
        case .music: return "Music"
        case .audiobooks: return "Audiobooks & reading"
        case .news: return "News"
        case .cloudStorage: return "Cloud storage"
        case .passwordManager: return "Password manager"
        case .vpn: return "VPN"
        case .security: return "Antivirus & identity"
        case .email: return "Email"
        case .aiAssistant: return "AI assistant"
        case .aiCoding: return "AI coding"
        case .devTools: return "Developer tools"
        case .webHosting: return "Website & domains"
        case .productivity: return "Productivity"
        case .creative: return "Creative software"
        case .learning: return "Learning"
        case .kids: return "Kids & family"
        case .fitness: return "Fitness"
        case .meditation: return "Meditation"
        case .health: return "Health & therapy"
        case .mealKit: return "Meal kits"
        case .delivery: return "Delivery membership"
        case .retailMembership: return "Retail membership"
        case .telecom: return "Internet & wireless"
        case .gaming: return "Gaming"
        case .dating: return "Dating"
        case .socialMedia: return "Social"
        case .creatorSupport: return "Creators you support"
        case .homeSecurity: return "Home security"
        case .auto: return "Car"
        case .finance: return "Money & taxes"
        case .platformBilled: return "App Store / Play billed"
        case .other: return "Other"
        }
    }
}

enum BillingCycle: String, Codable, CaseIterable {
    case weekly, biweekly, monthly, quarterly, semiannual, yearly

    /// Number of charges per year — the single source for monthly/yearly math.
    var chargesPerYear: Double {
        switch self {
        case .weekly:     return 52
        case .biweekly:   return 26
        case .monthly:    return 12
        case .quarterly:  return 4
        case .semiannual: return 2
        case .yearly:     return 1
        }
    }

    var label: String {
        switch self {
        case .weekly:     return "Weekly"
        case .biweekly:   return "Every 2 weeks"
        case .monthly:    return "Monthly"
        case .quarterly:  return "Quarterly"
        case .semiannual: return "Every 6 months"
        case .yearly:     return "Yearly"
        }
    }
}

/// Who actually bills the card. `apple` means the charge appears on the
/// statement as APPLE.COM/BILL and is managed / refunded through Apple, not
/// the vendor — regardless of which brand the subscription is for.
enum BillingSource: String, Codable {
    case apple
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
    /// Ids of other active subscriptions of the same kind — recomputed by the
    /// store whenever the library changes, so the zombie score can surface
    /// duplicates.
    var hasOverlapWith: [String]
    let notes: String?
    /// Set when the sub came from the user's Apple subscriptions list (or was
    /// reconciled with an APPLE.COM/BILL charge). Declared last, with a
    /// default, so every existing memberwise call keeps compiling.
    var billedVia: BillingSource? = nil

    var brandColor: Color {
        Color(hex: brandHex) ?? Palette.ink
    }

    /// Brand id the detection pipeline assigned. Multi-charge billers (Apple,
    /// Google Play) get one sub per distinct amount with an id suffix, so the
    /// brand is the id with that suffix removed.
    var brandId: String {
        MerchantNormalizer.brandId(fromSubscriptionId: id)
    }

    var kind: Kind {
        BrandRegistry.kind(for: brandId)
    }

    var monthlyAmount: Double {
        amount * cycle.chargesPerYear / 12
    }

    /// True annual cost based on the actual billing cycle — avoids the
    /// rounding artifact you get from monthlyAmount * 12 when cycle is yearly
    /// (199.99 / 12 * 12 → 199.989999…).
    var yearlyAmount: Double {
        amount * cycle.chargesPerYear
    }

    var cycleLabel: String { cycle.label }
}

enum AlertType: String, Codable {
    case hike, trialEnding, newCharge, unused
    /// A bundle / card perk the user already pays for includes this sub.
    case covered
    /// A cheaper tier of the same service (or a pause) would keep it for less.
    case cheaperTier
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
