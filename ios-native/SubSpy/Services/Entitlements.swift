import Foundation

/// Defines exactly what the Free tier gets vs Pro. Matches PRD §4.1.
///
/// Pro unlocks ALL of these. Free gets the limits below.
enum Entitlements {
    /// Max subscriptions visible/tracked on free tier.
    /// Beyond this, the user sees them in a locked "Unlock to see N more" state.
    static let freeSubscriptionLimit = 5

    /// Dispute letters allowed per calendar month on free tier.
    static let freeDisputesPerMonth = 1

    /// Categories of features and whether each is Pro-gated.
    enum Feature {
        case zombieScoreBreakdown   // "Why this score" detail page
        case priceHikeAlerts        // Alerts tab content
        case negotiationScripts     // Negotiate detail scripts
        case unlimitedSubscriptions
        case unlimitedDisputes
        case prioritySupport
    }

    static func isProGated(_ feature: Feature) -> Bool {
        switch feature {
        case .zombieScoreBreakdown,
             .priceHikeAlerts,
             .negotiationScripts,
             .unlimitedSubscriptions,
             .unlimitedDisputes,
             .prioritySupport:
            return true
        }
    }
}

/// Tracks dispute usage per calendar month so free users get exactly N free disputes.
extension AppStore {
    /// Number of disputes the user has generated in the current calendar month.
    var disputesThisMonth: Int {
        let cal = Calendar.current
        let now = Date()
        return disputeUsageDates.filter { cal.isDate($0, equalTo: now, toGranularity: .month) }.count
    }

    var disputesRemainingThisMonth: Int {
        isPro ? .max : max(0, Entitlements.freeDisputesPerMonth - disputesThisMonth)
    }

    var canGenerateDispute: Bool {
        isPro || disputesThisMonth < Entitlements.freeDisputesPerMonth
    }

    func recordDisputeUsage() {
        disputeUsageDates.append(Date())
        // Persist via UserDefaults (small, low value, no need for SwiftData)
        let dates = disputeUsageDates.map { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(dates, forKey: "subspy.disputeUsageDates")
    }

    func loadDisputeUsage() {
        if let dates = UserDefaults.standard.array(forKey: "subspy.disputeUsageDates") as? [Double] {
            disputeUsageDates = dates.map { Date(timeIntervalSince1970: $0) }
        }
    }
}
