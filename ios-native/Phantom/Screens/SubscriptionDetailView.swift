import SwiftUI

struct SubscriptionDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let subId: String

    @State private var showDispute = false
    @State private var goNegotiate = false
    @State private var showCancelConfirm = false
    @State private var showDeleteConfirm = false
    /// Set when we send the user to the vendor's cancel page; on return to the
    /// app we ask whether it worked.
    @State private var awaitingCancelReturn = false
    @State private var showReturnConfirm = false

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
        .confirmationDialog("Delete this subscription?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let sub { store.removeSubscription(sub.id) }
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Removes \(sub?.name ?? "this subscription") from Phantom. It will reappear if Phantom detects it again on a future import. This does NOT cancel the underlying subscription.")
        }
        .confirmationDialog("Cancel \(sub?.name ?? "this subscription")?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            if let sub {
                let path = CancellationRegistry.path(forSubscriptionId: sub.id, fallbackName: sub.name)
                // Only offer "open" when there's actually a URL/dialer to open.
                // In-person / certified-letter vendors (url == nil) get instructions
                // via the message + the manual "I've already cancelled it" action.
                if path.url != nil {
                    Button(path.isAppleManaged ? "Open iOS Subscriptions" : "Open cancel page") {
                        if openCancelPath(path) {
                            awaitingCancelReturn = true
                        }
                    }
                }
                Button("I've already cancelled it") {
                    store.confirmCancellation(subId)
                    dismiss()
                }
                Button("Keep it", role: .cancel) {}
            }
        } message: {
            if let sub {
                let path = CancellationRegistry.path(forSubscriptionId: sub.id, fallbackName: sub.name)
                Text("Saves \(fmtUSD(sub.monthlyAmount)) per month.\n\n\(path.hint ?? "We'll open \(sub.name)'s official cancel page. Come back when you're done and we'll confirm it.")")
            }
        }
        .confirmationDialog("Did the \(sub?.name ?? "") cancellation go through?", isPresented: $showReturnConfirm, titleVisibility: .visible) {
            Button("Yes — it's cancelled") {
                store.confirmCancellation(subId)
                dismiss()
            }
            Button("It didn't work — dispute it") {
                showDispute = true
            }
            Button("Still deciding", role: .cancel) {}
        } message: {
            Text("Vendors don't always stop on the first try. If you get charged again, a dispute letter gets your money back — and Phantom will remind you to re-scan your next statement to confirm.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && awaitingCancelReturn {
                awaitingCancelReturn = false
                showReturnConfirm = true
            }
        }
    }

    /// Opens the cancel URL if there is one. Returns whether we actually launched
    /// something — the caller only arms the "did it go through?" return prompt when
    /// an external app (Safari/dialer/iOS Settings) was opened.
    @discardableResult
    private func openCancelPath(_ path: CancellationRegistry.CancelPath) -> Bool {
        guard let url = path.url else { return false }
        UIApplication.shared.open(url, options: [:]) { _ in }
        return true
    }

    @ViewBuilder
    private func content(for sub: Subscription) -> some View {
        let breakdown = ZombieScore.compute(sub)
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
                                Text("Marked as cancelled · saving \(fmtUSD(sub.yearlyAmount))/yr").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                Text("Phantom can't watch the vendor, so re-scan your next statement to confirm it actually stopped — we'll remind you in about 5 weeks.")
                                    .font(AppFont.small).foregroundStyle(Palette.mute)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                        SavingsShareButton(amountYearly: sub.yearlyAmount, kind: .saved)
                        PrimaryButton("Undo cancel", variant: .secondary) { store.reactivate(subId) }
                        PrimaryButton("Charged after cancelling? Dispute it", variant: .ghost) {
                            showDispute = true
                        } leading: {
                            Image(systemName: "envelope")
                        }
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
