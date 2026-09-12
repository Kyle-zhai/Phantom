import SwiftUI

struct SubscriptionDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subId: String

    @State private var showDispute = false
    @State private var goNegotiate = false
    @State private var showCancelFlow = false
    @State private var showChargeback = false
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false

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
        .sheet(isPresented: $showCancelFlow) {
            CancelFlowView(subId: subId)
                .environment(store)
        }
        .sheet(isPresented: $showChargeback) {
            ChargebackGuideView(subId: subId)
                .environment(store)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environment(store)
        }
        .onAppear { consumePendingDispute() }
        .onChange(of: DeepLink.shared.pendingDisputeId) { _, _ in
            consumePendingDispute()
        }
        .confirmationDialog("Delete this subscription?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let sub { store.removeSubscription(sub.id) }
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Removes \(sub?.name ?? "this subscription") from Phantom. It will reappear if Phantom detects it again on a future import. This does NOT cancel the underlying subscription.")
        }
    }

    private func consumePendingDispute() {
        guard DeepLink.shared.pendingDisputeId == subId else { return }
        DeepLink.shared.pendingDisputeId = nil
        showDispute = true
    }

    @ViewBuilder
    private func content(for sub: Subscription) -> some View {
        let breakdown = store.breakdown(for: sub.id) ?? ZombieScore.compute(sub)
        let tier = ZombieScore.tier(for: breakdown.score)
        let monthly = sub.monthlyAmount
        let yearly = sub.yearlyAmount
        let since = ZombieScore.daysSince(sub.lastUsedAt)
        let accrued = (Double(since) / 30.0) * monthly

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar(category: sub.category.rawValue)

                HStack(spacing: 16) {
                    Avatar(label: sub.name, subscriptionId: sub.id, bg: sub.brandColor, fg: Palette.white, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sub.name).font(AppFont.h2).foregroundStyle(Palette.ink)
                        // Show the raw bank-statement text so the user can
                        // verify the brand match against their actual bill.
                        // Falls back to the vendor field for manually-added
                        // subs that have no rawDescriptor.
                        if let raw = sub.rawDescriptor, raw != sub.name {
                            Text("On your statement").font(AppFont.smallB)
                                .foregroundStyle(Palette.mute)
                                .padding(.top, 2)
                            Text(raw).font(AppFont.small).foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(sub.vendor).font(AppFont.small).foregroundStyle(Palette.mute)
                        }
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
                            Text("Rate how much you use it below to sharpen it.")
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
                    SectionHeader("Why this score", caption: breakdown.usageKnown
                        ? "Full weighting — real usage data is available."
                        : "Weighted over the signals Phantom has for an imported charge.")
                    VStack(spacing: 0) {
                        let factors = ScoreFactor.allCases.filter { breakdown.weight($0) > 0 }
                        ForEach(Array(factors.enumerated()), id: \.element) { i, factor in
                            if i > 0 { DividerH() }
                            BreakdownRow(
                                label: factor.label,
                                value: factorValueText(factor, sub: sub, breakdown: breakdown, since: since),
                                weight: "\(Int((breakdown.weight(factor) * 100).rounded()))%",
                                score: breakdown.value(factor)
                            )
                        }
                    }
                    .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
                }
                .padding(.top, 28)

                coverageSection(for: sub)
                cheaperSection(for: sub)

                // Let the user supply the single strongest score signal we can
                // collect on-device. Two taps here move a flat import into a real
                // ranking (and feed the zombie flag).
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("How much do you use it?", caption: "Rate it to sharpen the zombie score.")
                    RatingControl(rating: sub.userRating) { store.setRating($0, for: sub.id) }
                }
                .padding(.top, 24)

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
                    SectionHeader("The numbers", caption: "Dates reflect what Phantom observed in your imports — they may not match the actual sign-up or vendor billing schedule.")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        StatTile(label: "First charge seen", value: fmtRelDate(sub.startedAt))
                        StatTile(label: "Billing cycle", value: sub.cycleLabel)
                        StatTile(label: "Yearly at this rate", value: fmtUSD(yearly), highlight: true)
                        StatTile(label: "Est. next charge", value: fmtRelDate(sub.nextBilling))
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
                            showCancelFlow = true
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
                                Text("Marked as cancelled · saving \(fmtUSD(sub.yearlyAmount))/yr").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                Text("Phantom can't watch the vendor, so re-scan your next statement to confirm it actually stopped — we'll remind you in about 5 weeks.")
                                    .font(AppFont.small).foregroundStyle(Palette.mute)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                        EvidenceLockerView(subId: subId)
                            .padding(.top, 8)
                        SavingsShareButton(amountYearly: sub.yearlyAmount, kind: .saved)
                        PrimaryButton("Charged after cancelling? Dispute it", variant: .secondary) {
                            showDispute = true
                        } leading: {
                            Image(systemName: "envelope")
                        }
                        PrimaryButton("If they ignore you — chargeback packet", variant: .ghost) {
                            showChargeback = true
                        } leading: {
                            Image(systemName: "creditcard")
                        }
                        PrimaryButton("Undo cancel", variant: .ghost) { store.reactivate(subId) }
                    }

                    // Always-available "remove from Phantom" — separate from the
                    // vendor-cancel flow above. This is what users want when the
                    // charge was misdetected (e.g. an Uber Eats order parsed as a
                    // subscription) and shouldn't be in the list at all.
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                            Text("Remove from Phantom").font(AppFont.smallB)
                        }
                        .foregroundStyle(Palette.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.dangerSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.top, 28)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
    }

    private func factorValueText(_ factor: ScoreFactor, sub: Subscription, breakdown: ScoreBreakdown, since: Int) -> String {
        switch factor {
        case .recency: return sub.lastUsedAt != nil ? "\(since)d ago" : "Never"
        case .usage: return "\(sub.sessionsLast30d) sessions / 30d"
        case .overlap:
            let n = sub.hasOverlapWith.count
            return n == 0 ? "No duplicates" : "\(n) other \(sub.kind.label.lowercased()) sub\(n == 1 ? "" : "s")"
        case .rating: return sub.userRating.map { "\($0)/5" } ?? "Not rated"
        case .price:
            if let d = store.downgrade(for: sub) {
                return "\(fmtUSD(d.cheaper.priceMonthly)) tier exists"
            }
            if sub.marketAverage > 0 {
                return sub.monthlyAmount > sub.marketAverage ? "+\(fmtUSD(sub.monthlyAmount - sub.marketAverage)) above avg" : "At or below market"
            }
            return "vs similar services"
        case .coverage: return store.coverageHit(for: sub.id).map { "In \($0.bundleName)" } ?? "—"
        case .hike: return sub.hasPriceHike.map { "\(fmtUSD($0.from)) → \(fmtUSD($0.to))" } ?? "—"
        }
    }

    /// "You already pay for this" — the first finding is free, the rest are Pro.
    @ViewBuilder
    private func coverageSection(for sub: Subscription) -> some View {
        if let hit = store.coverageHit(for: sub.id) {
            if let visible = store.visibleCoverageHit(for: sub.id) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Already covered", caption: visible.level.label)
                    Card(background: Palette.successSoft, borderColor: Palette.successSoft) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.success).font(.system(size: 20))
                                Text(visible.headline(subName: sub.name))
                                    .font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let note = visible.note, !note.isEmpty {
                                Text(note).font(AppFont.small).foregroundStyle(Palette.mute)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if visible.inferred {
                                Text("Detected from your own imports. Confirm the exact plan in Settings › What you already have.")
                                    .font(AppFont.small).foregroundStyle(Palette.mute2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(visible.level == .discounted && visible.inferred
                                 ? "Up to \(fmtUSD(visible.valueYearly)) a year if your plan includes it."
                                 : "Worth \(fmtUSD(visible.valueYearly)) a year.")
                                .font(AppFont.h3).foregroundStyle(Palette.keepFg).padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 28)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Already covered?")
                    ProLockOverlay(
                        title: "Something you already pay for may include \(sub.name)",
                        subtitle: "Worth about \(fmtUSD(hit.valueYearly)) a year. Free shows the single biggest finding; Pro shows every one.",
                        showPaywall: $showPaywall
                    )
                }
                .padding(.top, 28)
            }
        }
    }

    /// Cheaper tier / pause / like-for-like alternatives. Pro; free sees the
    /// headline saving.
    @ViewBuilder
    private func cheaperSection(for sub: Subscription) -> some View {
        let downgrade = store.downgrade(for: sub)
        let alternatives = store.alternatives(for: sub)
        let pause = store.catalog.pause(for: sub)
        if sub.kind == .platformBilled || sub.billedVia == .apple {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Billed through the App Store",
                              caption: sub.kind == .platformBilled
                                ? "The statement only shows the biller, not the app. Scan your Apple subscriptions list to name it."
                                : "\(sub.name) is on your Apple subscriptions list.")
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(sub.kind == .platformBilled
                             ? "Open Settings › Subscriptions to see which app this is, cancel it there, or ask Apple for a refund — Apple, not the app maker, handles both."
                             : "Cancel it in Settings › Subscriptions, or ask Apple for a refund — Apple handles both, not \(sub.name).")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                Text("Apple subscriptions").font(AppFont.smallB)
                                    .foregroundStyle(Palette.white)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(Palette.ink, in: Capsule())
                            }
                            Link(destination: URL(string: "https://reportaproblem.apple.com")!) {
                                Text("Request a refund").font(AppFont.smallB)
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(Palette.surface, in: Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 28)
        }
        if sub.kind != .platformBilled && (downgrade != nil || !alternatives.isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Keep it for less", caption: "Same service, cheaper plan — or a like-for-like swap. Phantom takes no commission.")
                if store.isPro {
                    if let d = downgrade {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("You look to be on \(d.current.name) at \(fmtUSD(d.current.priceMonthly))/mo.")
                                    .font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(d.cheaper.name) is \(fmtUSD(d.cheaper.priceMonthly))/mo" + (d.cheaper.note.map { " — \($0)" } ?? ""))
                                    .font(AppFont.small).foregroundStyle(Palette.mute)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Save \(fmtUSD(d.savesYearly)) a year")
                                    .font(AppFont.h3).foregroundStyle(Palette.keepFg)
                                if let pause, pause.supported, let note = pause.note {
                                    Text("Or pause: " + note).font(AppFont.small).foregroundStyle(Palette.mute)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else if let pause, pause.supported, let note = pause.note {
                        Card {
                            Text("Pause instead of cancelling: " + note)
                                .font(AppFont.small).foregroundStyle(Palette.mute)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if !alternatives.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(alternatives.enumerated()), id: \.element) { i, alt in
                                if i > 0 { DividerH() }
                                HStack(alignment: .top, spacing: 12) {
                                    Avatar(label: alt.name, subscriptionId: alt.brandId, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(alt.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                            Spacer()
                                            if let p = alt.priceMonthly {
                                                Text(p == 0 ? "Free" : "\(fmtUSD(p))/mo").font(AppFont.smallB).foregroundStyle(Palette.ink)
                                            }
                                        }
                                        if let why = alt.why {
                                            Text(why).font(AppFont.small).foregroundStyle(Palette.mute)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(14)
                            }
                        }
                        .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
                    }
                } else {
                    ProLockOverlay(
                        title: downgrade.map { "A cheaper \(sub.name) plan could save \(fmtUSD($0.savesYearly)) a year" }
                            ?? "\(alternatives.count) like-for-like alternative\(alternatives.count == 1 ? "" : "s") found",
                        subtitle: "Pro shows the exact plan to switch to, pause options, and alternatives at the same or lower price.",
                        showPaywall: $showPaywall
                    )
                }
                if sub.kind == .video {
                    Link(destination: URL(string: "https://www.justwatch.com/us")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "tv")
                            Text("See what's streaming where (JustWatch)").font(AppFont.smallB)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(14)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
            }
            .padding(.top, 28)
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

/// Compact 1–5 rating. Low stars = "barely use it" (more zombie); tapping the
/// current rating again clears it. Writes straight through to the store.
private struct RatingControl: View {
    let rating: Int?
    let onChange: (Int?) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { i in
                let filled = (rating ?? 0) >= i
                Button {
                    onChange(rating == i ? nil : i)
                } label: {
                    Image(systemName: filled ? "star.fill" : "star")
                        .font(.system(size: 26))
                        .foregroundStyle(filled ? Palette.warn : Palette.mute2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
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
