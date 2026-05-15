import SwiftUI

private struct AlertStyle {
    let icon: String
    let bg: Color
    let fg: Color
    let chip: String
}

private func style(for type: AlertType) -> AlertStyle {
    switch type {
    case .hike:        return AlertStyle(icon: "chart.line.uptrend.xyaxis", bg: Palette.dangerSoft, fg: Palette.zombieFg, chip: "Price hike")
    case .trialEnding: return AlertStyle(icon: "clock", bg: Palette.warnSoft, fg: Palette.reviewFg, chip: "Trial ending")
    case .newCharge:   return AlertStyle(icon: "creditcard", bg: Palette.infoSoft, fg: Palette.infoFg, chip: "New charge")
    case .unused:      return AlertStyle(icon: "moon", bg: Palette.surface, fg: Palette.ink, chip: "Unused")
    }
}

struct AlertsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ALERTS").font(AppFont.smallB).foregroundStyle(Palette.mute)
                    Text("\(store.unreadAlerts) need your attention")
                        .font(AppFont.h1).foregroundStyle(Palette.ink)
                    Text("We monitor 2,000+ services and ping you 7 days before any price hike.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                }
                .padding(.top, 4)

                VStack(spacing: 12) {
                    ForEach(store.alerts) { alert in
                        if let sub = store.subscription(byId: alert.subscriptionId) {
                            AlertCard(alert: alert, sub: sub)
                        }
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .navigationDestination(for: String.self) { id in
            SubscriptionDetailView(subId: id)
        }
        .navigationDestination(for: DisputeRoute.self) { route in
            DisputeLetterView(subId: route.subId)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct DisputeRoute: Hashable {
    let subId: String
}

private struct AlertCard: View {
    @Environment(AppStore.self) private var store
    let alert: PriceAlert
    let sub: Subscription

    var body: some View {
        let s = style(for: alert.type)
        Card {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: s.icon).font(.system(size: 10, weight: .bold))
                        Text(s.chip).micro()
                    }
                    .foregroundStyle(s.fg)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(s.bg, in: Capsule())
                    Spacer()
                    if !alert.read {
                        Circle().fill(Palette.danger).frame(width: 8, height: 8)
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    Avatar(label: sub.name, bg: sub.brandColor, fg: Palette.white, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.title).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                        Text(alert.message).font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                }
                .padding(.top, 14)

                HStack {
                    let isRefund = alert.type == .unused || alert.type == .newCharge
                    NavigationLink(value: isRefund ? AnyHashable(DisputeRoute(subId: sub.id)) : AnyHashable(sub.id)) {
                        Text(isRefund ? "Get refund" : "Take action")
                            .font(AppFont.smallB)
                            .foregroundStyle(Palette.white)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Palette.black, in: Capsule())
                    }
                    .simultaneousGesture(TapGesture().onEnded { store.markAlertRead(alert.id) })
                    Spacer()
                    Button { store.markAlertRead(alert.id) } label: {
                        Text("Dismiss").font(AppFont.smallB).foregroundStyle(Palette.mute)
                    }
                }
                .padding(.top, 16)
            }
        }
        .opacity(alert.read ? 0.7 : 1)
    }
}
