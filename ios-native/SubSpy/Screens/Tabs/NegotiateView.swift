import SwiftUI

struct NegotiateView: View {
    @Environment(AppStore.self) private var store

    private var offers: [NegotiationOffer] {
        Negotiation.all(in: store.activeSubs)
    }

    private var totalPotential: Double {
        offers.reduce(0) { $0 + $1.yearlySaving }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NEGOTIATE").font(AppFont.smallB).foregroundStyle(Palette.mute)
                    Text("Save without cancelling.").font(AppFont.h1).foregroundStyle(Palette.ink)
                    Text("Some services hand out retention discounts when asked the right way. We give you the script.")
                        .font(AppFont.body).foregroundStyle(Palette.mute)
                }
                .padding(.top, 4)

                Card(background: Palette.black, borderColor: Palette.black) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ESTIMATED ANNUAL SAVINGS").font(AppFont.smallB).foregroundStyle(Palette.mute2)
                        Text(fmtUSD(totalPotential)).font(AppFont.display).foregroundStyle(Palette.white)
                        Text("If every retention offer below is accepted. Estimates — see each card for details.")
                            .font(AppFont.small).foregroundStyle(Palette.mute2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 20)

                VStack(spacing: 12) {
                    ForEach(offers) { offer in
                        if let sub = store.subscription(byId: offer.id) {
                            NavigationLink(value: NegotiateRoute(subId: sub.id)) {
                                offerRow(offer: offer, sub: sub)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .navigationDestination(for: NegotiateRoute.self) { route in
            NegotiateDetailView(subId: route.subId)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func offerRow(offer: NegotiationOffer, sub: Subscription) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Avatar(label: offer.vendor, bg: sub.brandColor, fg: Palette.white)
            VStack(alignment: .leading, spacing: 6) {
                Text(offer.vendor)
                    .font(AppFont.bodyB)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Badge("~\(offer.successRate)%", tone: offer.successRate >= 60 ? .keep : .review)
                    Text(offer.expectedDiscount)
                        .font(AppFont.small)
                        .foregroundStyle(Palette.mute)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("SAVE UP TO")
                    .font(AppFont.micro)
                    .tracking(0.4)
                    .foregroundStyle(Palette.mute)
                Text("\(fmtUSD(offer.yearlySaving))/yr")
                    .font(AppFont.bodyB)
                    .foregroundStyle(Palette.success)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .fixedSize(horizontal: true, vertical: false)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.mute2)
        }
        .padding(14)
        .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
    }
}

struct NegotiateRoute: Hashable {
    let subId: String
}
