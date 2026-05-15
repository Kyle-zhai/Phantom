import Foundation

enum NegotiationChannel: String {
    case phone, chat, web
}

struct NegotiationOffer: Identifiable, Hashable {
    let id: String
    let vendor: String
    let successRate: Int
    /// Real annual saving computed from the specific offer (not a flat percentage).
    let yearlySaving: Double
    let expectedDiscount: String
    let script: String
    let channel: NegotiationChannel
    let contact: String?
    /// True until we have ≥ 50 SubSpy users' outcomes for this vendor. Until then
    /// the success-rate is an estimate drawn from public reports.
    let successRateEstimated: Bool
}

/// Per-vendor recipe. `savingForYear(sub)` returns the *real* annual saving that
/// the offer in `expectedDiscount` actually delivers — derived from the
/// subscription's own pricing, not a flat percentage.
private struct Recipe {
    let successRate: Int
    let expectedDiscount: String
    let channel: NegotiationChannel
    let contact: String
    let script: String
    let savingForYear: (Subscription) -> Double
}

private let recipes: [String: Recipe] = [
    "hulu": Recipe(
        successRate: 68,
        expectedDiscount: "50% off for 6 months",
        channel: .chat,
        contact: "help.hulu.com/chat",
        script: "Hi — I've been a Hulu subscriber for a while, but my budget is getting tight and I'm comparing it with Netflix and Disney+. Before I cancel, is there any retention offer or discount you can apply to my account? I'd love to stay if there's something that brings the cost down.",
        savingForYear: { sub in sub.monthlyAmount * 0.5 * 6 }
    ),
    "spotify": Recipe(
        successRate: 32,
        expectedDiscount: "3 months at $4.99/mo",
        channel: .chat,
        contact: "support.spotify.com",
        script: "Hi — I'm thinking about pausing Spotify and switching to YouTube Music for the family plan pricing. Before I do, is there a loyalty discount or promotional rate you can offer existing customers?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 4.99) * 3 }
    ),
    "sirius": Recipe(
        successRate: 87,
        expectedDiscount: "$5–9 / month for 12 months",
        channel: .phone,
        contact: "1-866-635-2349",
        script: "Hi — I'd like to cancel my SiriusXM subscription. The current rate is more than I want to pay. Before I cancel, is there a long-term promotional rate you can offer? I've seen offers around $5/month for a year.",
        savingForYear: { sub in max(0, sub.monthlyAmount - 7.0) * 12 }
    ),
    "planet-fitness": Recipe(
        successRate: 22,
        expectedDiscount: "Pause for 3 months",
        channel: .phone,
        contact: "Your home club",
        script: "Hi — I haven't been using my membership and would like to either pause it or step down to the basic tier. Can you walk me through my options?",
        savingForYear: { sub in sub.monthlyAmount * 3 }
    ),
    "audible": Recipe(
        successRate: 78,
        expectedDiscount: "3 months at $7.95/mo",
        channel: .chat,
        contact: "audible.com/help",
        script: "Hi — I'm thinking about cancelling Audible because I'm not finishing the credits each month. Before I do, is there a retention offer or a less expensive plan available?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 7.95) * 3 }
    ),
    "adobe-cc": Recipe(
        successRate: 71,
        expectedDiscount: "2 months free",
        channel: .chat,
        contact: "helpx.adobe.com/contact",
        script: "Hi — I'd like to cancel my Creative Cloud subscription. Before I confirm, are there any loyalty or retention offers available for long-term customers?",
        savingForYear: { sub in sub.monthlyAmount * 2 }
    ),
    "amazon-prime": Recipe(
        successRate: 12,
        expectedDiscount: "Free month",
        channel: .chat,
        contact: "amazon.com/contact-us",
        script: "Hi — I'm re-evaluating my Prime subscription. Is there any loyalty offer for long-time customers?",
        savingForYear: { sub in sub.monthlyAmount }
    ),
]

enum Negotiation {
    static func offer(for sub: Subscription) -> NegotiationOffer? {
        guard let r = recipes[sub.id] else { return nil }
        let saving = (r.savingForYear(sub) * 100).rounded() / 100
        return NegotiationOffer(
            id: sub.id,
            vendor: sub.name,
            successRate: r.successRate,
            yearlySaving: saving,
            expectedDiscount: r.expectedDiscount,
            script: r.script,
            channel: r.channel,
            contact: r.contact,
            successRateEstimated: true
        )
    }

    static func all(in subs: [Subscription]) -> [NegotiationOffer] {
        subs.compactMap { offer(for: $0) }
            .sorted { $0.yearlySaving > $1.yearlySaving }
    }
}
