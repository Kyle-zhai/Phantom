import SwiftUI

struct NegotiateDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subId: String
    @State private var copied = false

    private var sub: Subscription? { store.subscription(byId: subId) }
    private var offer: NegotiationOffer? { sub.flatMap { Negotiation.offer(for: $0) } }

    var body: some View {
        Group {
            if let sub, let offer {
                content(sub: sub, offer: offer)
            } else if let sub {
                noOfferView(sub: sub)
            } else {
                Text("Not found").font(AppFont.h2).foregroundStyle(Palette.ink)
            }
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func topBar(label: String) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Palette.surface, in: Circle())
            }
            Spacer()
            Text(label).font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func content(sub: Subscription, offer: NegotiationOffer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar(label: "NEGOTIATE")
                HStack(spacing: 14) {
                    Avatar(label: sub.name, bg: sub.brandColor, fg: Palette.white, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sub.name).font(AppFont.h2).foregroundStyle(Palette.ink)
                        Text("Up to \(fmtUSD(offer.yearlySaving))/yr if you ask the right way.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 22)

                Card {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("SUCCESS RATE").font(AppFont.smallB).foregroundStyle(Palette.mute)
                                if offer.successRateEstimated {
                                    Badge("EST", tone: .neutral)
                                }
                            }
                            Text("~\(offer.successRate)%").font(AppFont.display).foregroundStyle(Palette.success)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Rectangle().fill(Palette.border).frame(width: 1, height: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UP TO").font(AppFont.smallB).foregroundStyle(Palette.mute)
                            Text(fmtUSD(offer.yearlySaving)).font(AppFont.h2).foregroundStyle(Palette.ink)
                            Text("per year if accepted").font(AppFont.small).foregroundStyle(Palette.mute)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 20)

                if offer.successRateEstimated {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle").foregroundStyle(Palette.mute).font(.system(size: 14))
                        Text("Estimated from public reports (Reddit r/personalfinance, Consumer Reports, Rocket Money transparency data). SubSpy will replace this with real outcomes once 50+ users have tried this vendor.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                    .padding(12)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .padding(.top, 10)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("How to reach them")
                    Card {
                        HStack(spacing: 14) {
                            Image(systemName: offer.channel == .phone ? "phone" : "bubble.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 44, height: 44)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.channel.rawValue.uppercased()).font(AppFont.smallB).foregroundStyle(Palette.mute)
                                Text(offer.contact ?? "—").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                            }
                            Spacer(minLength: 0)
                            Badge(offer.expectedDiscount, tone: .keep)
                        }
                    }
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Your script", caption: "Tap to copy. Read it almost verbatim.")
                    Button { copy(offer.script) } label: {
                        Card(background: Palette.surface, borderColor: Palette.surface) {
                            Text("\"\(offer.script)\"")
                                .font(AppFont.body)
                                .foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Tips for this call")
                    VStack(spacing: 14) {
                        tip("1", "Be polite — agents have discretion. Hostility kills retention offers.")
                        tip("2", "Mention a competitor by name. It triggers their retention script.")
                        tip("3", "If the first offer is small, ask: 'Is that the best you can do?'")
                        tip("4", "Confirm the new rate in writing (email or chat transcript).")
                    }
                }
                .padding(.top, 28)

                PrimaryButton(copied ? "Copied!" : "Copy script") { copy(offer.script) } leading: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .padding(.top, 24)

                PrimaryButton("It didn't work — cancel instead", variant: .ghost) { dismiss() }
                    .padding(.top, 12)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
    }

    private func tip(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Palette.ink).frame(width: 26, height: 26)
                Text(n).font(AppFont.smallB).foregroundStyle(Palette.white)
            }
            .padding(.top, 2)
            Text(text).font(AppFont.body).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
    }

    private func noOfferView(sub: Subscription) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                topBar(label: "NEGOTIATE")
                Spacer().frame(height: 60)
                Image(systemName: "bubble.left").font(.system(size: 40)).foregroundStyle(Palette.mute2)
                Text("No retention script yet").font(AppFont.h2).foregroundStyle(Palette.ink).padding(.top, 16)
                Text("We don't have a proven negotiation playbook for \(sub.name) yet. Try the script below — it works for most subscriptions.")
                    .font(AppFont.body).foregroundStyle(Palette.mute)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320).padding(.top, 8)
                Card {
                    Text("\"Hi — I'd like to cancel my subscription. Before I do, are there any loyalty discounts, retention offers, or downgrade options I should know about?\"")
                        .font(AppFont.body).foregroundStyle(Palette.ink)
                }
                .padding(.top, 24)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func copy(_ s: String) {
        UIPasteboard.general.string = s
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { copied = false }
    }
}
