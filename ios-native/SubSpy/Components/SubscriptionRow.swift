import SwiftUI

struct SubscriptionRow: View {
    let sub: Subscription
    let score: Int
    var cancelled: Bool = false
    var showScore: Bool = true

    private var tone: BadgeTone {
        if score >= 80 { return .zombie }
        if score >= 50 { return .review }
        return .keep
    }

    private var tierLabel: String {
        if score >= 80 { return "Zombie" }
        if score >= 50 { return "Review" }
        return "Keep"
    }

    var body: some View {
        HStack(spacing: 12) {
            Avatar(label: sub.name, subscriptionId: sub.id, bg: sub.brandColor, fg: Palette.white)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sub.name).font(AppFont.bodyB).foregroundStyle(Palette.ink).lineLimit(1)
                    Spacer()
                    Text(fmtUSD(sub.monthlyAmount)).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                }
                HStack(spacing: 6) {
                    if cancelled {
                        Badge("Cancelled", tone: .neutral)
                    } else if showScore {
                        Badge(tierLabel, tone: tone)
                    }
                    Text(sub.cycle == .yearly ? "\(fmtUSD(sub.amount))/yr" : "per month")
                        .font(AppFont.small).foregroundStyle(Palette.mute).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.mute2)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .opacity(cancelled ? 0.5 : 1)
        .contentShape(Rectangle())
    }
}
