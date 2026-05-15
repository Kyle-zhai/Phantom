import SwiftUI

struct SubscriptionDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subId: String

    @State private var showDispute = false
    @State private var goNegotiate = false
    @State private var showCancelConfirm = false

    private var sub: Subscription? {
        store.subscription(byId: subId)
    }

    private var cancelled: Bool {
        store.cancelledIds.contains(subId)
    }

    var body: some View {
        Group {
            if let sub {
                content(for: sub)
            } else {
                VStack { Text("Not found").font(AppFont.h2).foregroundStyle(Palette.ink) }
            }
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $goNegotiate) {
            NegotiateDetailView(subId: subId)
        }
        .sheet(isPresented: $showDispute) {
            DisputeLetterView(subId: subId)
                .environment(store)
        }
        .confirmationDialog("Cancel \(sub?.name ?? "this subscription")?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            if let sub {
                let path = CancellationRegistry.path(forSubscriptionId: sub.id, fallbackName: sub.name)
                Button(path.isAppleManaged ? "Open iOS Subscriptions" : "Go to cancel page", role: .destructive) {
                    openCancelPath(path)
                    store.cancel(subId)
                    dismiss()
                }
                Button("Just mark as cancelled (no redirect)") {
                    store.cancel(subId)
                    dismiss()
                }
                Button("Keep it", role: .cancel) {}
            }
        } message: {
            if let sub {
                let path = CancellationRegistry.path(forSubscriptionId: sub.id, fallbackName: sub.name)
                Text("Saves \(fmtUSD(sub.monthlyAmount)) per month.\n\n\(path.hint ?? "We'll open the vendor's cancel page in Safari.")")
            }
        }
    }

    private func openCancelPath(_ path: CancellationRegistry.CancelPath) {
        UIApplication.shared.open(path.url, options: [:]) { _ in }
    }

    @ViewBuilder
    private func content(for sub: Subscription) -> some View {
        let breakdown = ZombieScore.compute(sub)
        let tier = ZombieScore.tier(for: breakdown.score)
        let monthly = sub.monthlyAmount
        let yearly = monthly * 12
        let since = ZombieScore.daysSince(sub.lastUsedAt)
        let accrued = (Double(since) / 30.0) * monthly

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar(category: sub.category.rawValue)

                HStack(spacing: 16) {
                    Avatar(label: sub.name, subscriptionId: sub.id, bg: sub.brandColor, fg: Palette.white, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sub.name).font(AppFont.h2).foregroundStyle(Palette.ink)
                        Text(sub.vendor).font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                    Spacer()
                }
                .padding(.top, 24)

                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("YOU PAY").font(AppFont.smallB).foregroundStyle(Palette.mute)
                                Text(fmtUSD(monthly)).font(AppFont.display).foregroundStyle(Palette.ink)
                                Text("per month\(sub.cycle == .yearly ? " · \(fmtUSD(sub.amount)) billed yearly" : "")")
                                    .font(AppFont.small).foregroundStyle(Palette.mute)
                            }
                            Spacer()
                            Badge(tier.rawValue.uppercased(), tone: tier == .zombie ? .zombie : tier == .review ? .review : .keep)
                        }
                        ZombieMeter(score: breakdown.score, size: .lg).padding(.top, 18)
                    }
                }
                .padding(.top, 22)

                if breakdown.hasUnknowns {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(Palette.warn)
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Score is approximate")
                                .font(AppFont.bodyB).foregroundStyle(Palette.ink)
                            Text("Add your last-used date and rating below to refine it.")
                                .font(AppFont.small).foregroundStyle(Palette.mute)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Palette.warnSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                    .padding(.top, 14)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Why this score")
                    VStack(spacing: 0) {
                        BreakdownRow(label: "Last opened",
                                     value: sub.lastUsedAt != nil ? "\(since)d ago" : "Never",
                                     weight: "35%", score: breakdown.recencyOfLastUse)
                        DividerH()
                        BreakdownRow(label: "Use vs price",
                                     value: "\(sub.sessionsLast30d) sessions / 30d",
                                     weight: "25%", score: breakdown.usageVsPrice)
                        DividerH()
                        BreakdownRow(label: "Overlap",
                                     value: sub.hasOverlapWith.isEmpty ? "None detected" : "\(sub.hasOverlapWith.count) similar subs",
                                     weight: "20%", score: breakdown.overlap)
                        DividerH()
                        BreakdownRow(label: "Your rating",
                                     value: sub.userRating.map { "\($0)/5" } ?? "Not rated",
                                     weight: "15%", score: breakdown.userRating)
                        DividerH()
                        BreakdownRow(label: "Vs market",
                                     value: sub.marketAverage > 0
                                        ? (monthly > sub.marketAverage
                                            ? "+\(fmtUSD(monthly - sub.marketAverage)) above avg"
                                            : "At or below market")
                                        : "—",
                                     weight: "5%", score: breakdown.priceVsMarket)
                    }
                    .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
                }
                .padding(.top, 28)

                if let hike = sub.hasPriceHike {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Palette.danger).font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Price went up").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                            Text("\(fmtUSD(hike.from)) → \(fmtUSD(hike.to)) per month")
                                .font(AppFont.small).foregroundStyle(Palette.mute)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Palette.dangerSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                    .padding(.top, 28)
                }

                if sub.trialEndsAt != nil {
                    HStack(spacing: 12) {
                        Image(systemName: "clock").foregroundStyle(Palette.warn).font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trial ending soon").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                            Text("You'll be billed in a few days unless you cancel.")
                                .font(AppFont.small).foregroundStyle(Palette.mute)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Palette.warnSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                    .padding(.top, 16)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("The numbers")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        StatTile(label: "Started", value: fmtRelDate(sub.startedAt))
                        StatTile(label: "Yearly cost", value: fmtUSD(yearly), highlight: true)
                        StatTile(label: "Next bill", value: fmtRelDate(sub.nextBilling))
                        if accrued > 0 && sub.lastUsedAt != nil {
                            StatTile(label: "Spent since last use", value: fmtUSD(accrued), highlight: breakdown.score >= 80)
                        }
                    }
                }
                .padding(.top, 28)

                if let notes = sub.notes {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle").foregroundStyle(Palette.mute).font(.system(size: 16))
                        Text(notes).font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                    .padding(14)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .padding(.top, 22)
                }

                VStack(spacing: 12) {
                    if !cancelled {
                        PrimaryButton("Cancel — save \(fmtUSD(monthly))/mo", variant: .danger) {
                            showCancelConfirm = true
                        } leading: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        PrimaryButton("Try to negotiate first", variant: .secondary) {
                            goNegotiate = true
                        } leading: {
                            Image(systemName: "bubble.left")
                        }
                        PrimaryButton("Generate dispute letter", variant: .ghost) {
                            showDispute = true
                        } leading: {
                            Image(systemName: "envelope")
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success).font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cancelled this session").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                Text("We'll log you out at the vendor on your behalf shortly.")
                                    .font(AppFont.small).foregroundStyle(Palette.mute)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                        PrimaryButton("Undo cancel", variant: .secondary) { store.reactivate(subId) }
                        PrimaryButton("Generate dispute letter for past charges", variant: .ghost) {
                            showDispute = true
                        } leading: {
                            Image(systemName: "envelope")
                        }
                    }
                }
                .padding(.top, 28)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
    }

    private func topBar(category: String) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Palette.surface, in: Circle())
            }
            Spacer()
            Text(category.uppercased()).font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }
}

private struct BreakdownRow: View {
    let label: String
    let value: String
    let weight: String
    let score: Int

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                Text("\(value) · weight \(weight)").font(AppFont.small).foregroundStyle(Palette.mute)
            }
            Spacer()
            ZombieMeter(score: score, size: .sm, showLabel: false).frame(width: 100)
        }
        .padding(16)
    }
}

private struct DividerH: View {
    var body: some View {
        Rectangle().fill(Palette.border).frame(height: 1)
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(AppFont.smallB)
                .foregroundStyle(Palette.mute)
                .lineLimit(2, reservesSpace: true)
            Text(value)
                .font(AppFont.h3)
                .foregroundStyle(highlight ? Palette.danger : Palette.ink)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    }
}
