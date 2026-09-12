import SwiftUI

struct RadarView: View {
    @Environment(AppStore.self) private var store
    @State private var showImport = false
    @State private var showManual = false
    @State private var showPaywall = false
    @State private var showAppleGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if store.isSampleMode {
                    sampleBanner.padding(.top, 14)
                }
                heroPanel.padding(.top, 20)
                if store.subscriptions.isEmpty {
                    emptyStateCard.padding(.top, 16)
                } else if let days = store.daysSinceLastImport, days >= 21 {
                    rescanBanner.padding(.top, 16)
                }
                if shownPotentialMonthly > 0 {
                    savingsCard.padding(.top, 16)
                } else if showRatePrompt {
                    ratePromptCard.padding(.top, 16)
                }
                if showSignInNudge {
                    signInNudge.padding(.top, 16)
                }
                if !store.coverageHits.isEmpty {
                    coverageCard.padding(.top, 16)
                }
                if store.cheaperPlanYearlySavings > 0 {
                    cheaperPlansCard.padding(.top, 16)
                }
                if !store.subscriptions.isEmpty {
                    longPressTip.padding(.top, 16)
                }
                ScoreSection(
                    title: "Zombies",
                    caption: "These have been silent. Score ≥ 80.",
                    tone: .zombie,
                    subs: zombies()
                ).padding(.top, 28)
                ScoreSection(
                    title: "Worth a second look",
                    caption: "Use is dropping. Score 50–79.",
                    tone: .review,
                    subs: review()
                ).padding(.top, 28)
                ScoreSection(
                    title: "In active use",
                    caption: "You're getting value here.",
                    tone: nil,
                    subs: keep()
                ).padding(.top, 28)
                if !store.cancelledSubs.isEmpty {
                    cancelledSection.padding(.top, 28)
                }
                if hiddenCount > 0 {
                    lockedMoreCard.padding(.top, 28)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: String.self) { id in
            SubscriptionDetailView(subId: id)
        }
        .sheet(isPresented: $showImport) {
            ImportScreenshotView().environment(store)
        }
        .sheet(isPresented: $showManual) {
            ManualAddSubscriptionView().environment(store)
        }
        .sheet(isPresented: $showAppleGuide) {
            AppleSubscriptionsGuideView().environment(store)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environment(store)
        }
    }

    /// Hero/savings figures computed over the SAME set the Zombies section shows
    /// (free tier is capped to the top-N by spend), so the "N zombies / cancel
    /// them below" copy never references rows that aren't on screen.
    private var shownZombies: [Subscription] { zombies() }
    private var shownPotentialMonthly: Double { shownZombies.reduce(0) { $0 + $1.monthlyAmount } }
    private var shownPotentialYearly: Double { shownZombies.reduce(0) { $0 + $1.yearlyAmount } }

    /// When we have subs but nothing's flagged yet and the user hasn't rated
    /// anything, point them at the one action that makes the score meaningful.
    private var showRatePrompt: Bool {
        !store.activeSubs.isEmpty && store.activeSubs.allSatisfy { $0.userRating == nil }
    }

    private var ratePromptCard: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "star.leadinghalf.filled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.warn)
                    .frame(width: 44, height: 44)
                    .background(Palette.warnSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find your zombies").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                    Text("Open a subscription and rate how much you use it. Low-rated and duplicate subs surface here as zombies you can cancel.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Number of active subs hidden from free users.
    private var hiddenCount: Int {
        guard !store.isPro else { return 0 }
        let total = store.activeSubs.count
        return max(0, total - Entitlements.freeSubscriptionLimit)
    }

    private var lockedMoreCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ProTag()
                    Spacer()
                }
                Text("\(hiddenCount) more subscription\(hiddenCount == 1 ? "" : "s") detected")
                    .font(AppFont.h3).foregroundStyle(Palette.ink)
                Text("Free tier shows the top \(Entitlements.freeSubscriptionLimit) by spend. Unlock Pro to see all \(store.activeSubs.count) — and get Zombie Scores, price-hike alerts, and unlimited dispute letters.")
                    .font(AppFont.small).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                Button { showPaywall = true } label: {
                    Text("Unlock with Pro").font(AppFont.smallB)
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Palette.ink, in: Capsule())
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RADAR").font(AppFont.smallB).foregroundStyle(Palette.mute)
                Text("Your subscriptions").font(AppFont.h1).foregroundStyle(Palette.ink)
            }
            Spacer()
            HStack(spacing: 10) {
                Menu {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAppleGuide = true
                    } label: {
                        Label("Apple subscriptions", systemImage: "applelogo")
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showImport = true
                    } label: {
                        Label("Screenshot or CSV", systemImage: "photo.on.rectangle.angled")
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showManual = true
                    } label: {
                        Label("Add manually", systemImage: "pencil.line")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.white)
                        .frame(width: 40, height: 40)
                        .background(Palette.ink, in: Circle())
                }
                .accessibilityLabel("Add subscription")

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.selectedTab = 4
                } label: {
                    Image(systemName: "person")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 40, height: 40)
                        .background(Palette.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Account and settings")
            }
        }
        .padding(.top, 4)
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EVERY MONTH").font(AppFont.smallB).foregroundStyle(Palette.mute2)
            Text(fmtUSD(store.monthlyTotal)).font(AppFont.display).foregroundStyle(Palette.white).padding(.top, 8)
            if store.monthlyTotal > 0 {
                Text("\(fmtUSD(store.yearlyTotal)) per year at this rate")
                    .font(AppFont.smallB).foregroundStyle(Palette.mute2).padding(.top, 6)
            }
            if store.payingTwiceMonthly > 0 {
                Text("\(fmtUSD(store.payingTwiceMonthly))/mo may be paid twice — already in a bundle you own")
                    .font(AppFont.smallB).foregroundStyle(Palette.warn).padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 0) {
                stat("ACTIVE", "\(store.activeSubs.count)", color: Palette.white)
                divider
                stat("ZOMBIES", "\(shownZombies.count)", color: Palette.danger)
                divider
                stat("ALERTS", "\(store.unreadAlerts)", color: Palette.white)
            }
            .padding(.top, 22)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.black, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private func stat(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFont.smallB).foregroundStyle(Palette.mute2)
            Text(value).font(AppFont.h3).foregroundStyle(color).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle().fill(Color(red: 0.16, green: 0.16, blue: 0.16)).frame(width: 1, height: 36).padding(.horizontal, 8)
    }

    private var sampleBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Palette.warn).frame(width: 36, height: 36)
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Palette.white)
                    .font(.system(size: 16, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("These aren't your subscriptions").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                Text("You're in sample mode — \(store.subscriptions.count) example subscriptions Phantom uses to demo the app. Tap Clear to start fresh, or scan your real bank screenshots.")
                    .font(AppFont.small).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button { store.clearSampleData() } label: {
                        Text("Clear sample").font(AppFont.smallB)
                            .foregroundStyle(Palette.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Palette.ink, in: Capsule())
                    }
                    Button { showImport = true } label: {
                        Text("Scan real bank").font(AppFont.smallB)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Palette.white, in: Capsule())
                            .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.warnSoft, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private var rescanBanner: some View {
        Button { showImport = true } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Re-scan your latest statement").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                    Text("Last import was \(store.daysSinceLastImport ?? 0) days ago. A new screenshot or CSV catches charges that started — or didn't stop — after a cancel.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Palette.warnSoft, in: RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
    }

    private var emptyStateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("Nothing here yet")
                    .font(AppFont.h3)
                    .foregroundStyle(Palette.ink)
                Text("Start with the Apple subscriptions list iOS already keeps — about 30 seconds — or scan a statement / CSV. No bank login.")
                    .font(AppFont.small)
                    .foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 10) {
                    Button { showAppleGuide = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "applelogo")
                            Text("Apple subscriptions").font(AppFont.smallB)
                        }
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Palette.ink, in: Capsule())
                    }
                    HStack(spacing: 10) {
                        Button { showImport = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Screenshot / CSV").font(AppFont.smallB)
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Palette.surface, in: Capsule())
                        }
                        Button { showManual = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil.line")
                                Text("Add manually").font(AppFont.smallB)
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Palette.surface, in: Capsule())
                        }
                    }
                }
                .padding(.top, 4)
                Button { store.seedSampleData() } label: {
                    Text("or browse with sample data →")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var longPressTip: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.mute)
            Text("Tap a row to see details · long-press for delete & quick actions")
                .font(AppFont.small)
                .foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
    }

    private var savingsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.success)
                        .frame(width: 44, height: 44)
                        .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("POTENTIAL SAVINGS").font(AppFont.smallB).foregroundStyle(Palette.success)
                        Text("\(fmtUSD(shownPotentialMonthly))/mo").font(AppFont.h1).foregroundStyle(Palette.ink)
                        Text("That's \(fmtUSD(shownPotentialYearly)) a year across \(shownZombies.count) zombie \(shownZombies.count == 1 ? "subscription" : "subscriptions"). Cancel them below to claim it.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                SavingsShareButton(amountYearly: shownPotentialYearly, kind: .found)
            }
        }
    }

    @State private var account = AccountService.shared
    @State private var signInNudgeDismissed = UserDefaults.standard.bool(forKey: "phantom.signinNudgeDismissed")

    private var showSignInNudge: Bool {
        !account.isSignedIn && !store.activeSubs.isEmpty && !signInNudgeDismissed && !store.isSampleMode
    }

    /// Data only exists on this phone until the user signs in.
    private var signInNudge: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 6) {
                    Text("This only lives on this iPhone").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                    Text("Sign in with Apple to save your subscriptions, ratings and cancel proof to your iCloud.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button { store.selectedTab = 4 } label: {
                            Text("Sign in").font(AppFont.smallB)
                                .foregroundStyle(Palette.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Palette.ink, in: Capsule())
                        }
                        Button {
                            signInNudgeDismissed = true
                            UserDefaults.standard.set(true, forKey: "phantom.signinNudgeDismissed")
                        } label: {
                            Text("Not now").font(AppFont.smallB).foregroundStyle(Palette.mute)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// "You already pay for this elsewhere" — free sees the biggest finding.
    private var coverageCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.success)
                        .frame(width: 44, height: 44)
                        .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ALREADY COVERED").font(AppFont.smallB).foregroundStyle(Palette.success)
                        Text("\(fmtUSD(store.coverageValueMonthly * 12))/yr").font(AppFont.h1).foregroundStyle(Palette.ink)
                        Text("\(store.coverageHits.count) subscription\(store.coverageHits.count == 1 ? " is" : "s are") included in — or reimbursed by — something you already pay for.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                VStack(spacing: 0) {
                    ForEach(store.visibleCoverageHits) { hit in
                        if let sub = store.subscription(byId: hit.subId) {
                            NavigationLink(value: sub.id) {
                                HStack(spacing: 12) {
                                    Avatar(label: sub.name, subscriptionId: sub.id, bg: sub.brandColor, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sub.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                        Text(hit.summary)
                                            .font(AppFont.small).foregroundStyle(Palette.mute)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    Text("\(fmtUSD(hit.valueYearly))/yr").font(AppFont.smallB).foregroundStyle(Palette.keepFg)
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if store.hiddenCoverageCount > 0 {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 8) {
                            ProTag()
                            Text("\(store.hiddenCoverageCount) more finding\(store.hiddenCoverageCount == 1 ? "" : "s") — unlock with Pro")
                                .font(AppFont.smallB).foregroundStyle(Palette.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// "Keep it for less" summary. Pro sees the list; free sees the total.
    private var cheaperPlansCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.info)
                        .frame(width: 44, height: 44)
                        .background(Palette.infoSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("KEEP IT FOR LESS").font(AppFont.smallB).foregroundStyle(Palette.infoFg)
                        Text("\(fmtUSD(store.cheaperPlanYearlySavings))/yr").font(AppFont.h1).foregroundStyle(Palette.ink)
                        Text("Cheaper plans of the same services you already use. Most people who dropped a tier kept the service.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                if store.isPro {
                    VStack(spacing: 0) {
                        ForEach(store.downgradeCandidates, id: \.sub.id) { item in
                            NavigationLink(value: item.sub.id) {
                                HStack(spacing: 12) {
                                    Avatar(label: item.sub.name, subscriptionId: item.sub.id, bg: item.sub.brandColor, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.sub.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                        Text("\(item.downgrade.current.name) → \(item.downgrade.cheaper.name)")
                                            .font(AppFont.small).foregroundStyle(Palette.mute)
                                    }
                                    Spacer()
                                    Text("\(fmtUSD(item.downgrade.savesYearly))/yr").font(AppFont.smallB).foregroundStyle(Palette.keepFg)
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 8) {
                            ProTag()
                            Text("See which plan to switch to — unlock with Pro")
                                .font(AppFont.smallB).foregroundStyle(Palette.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var cancelledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Cancelled this session", caption: "You're saving \(fmtUSD(store.realizedYearlySavings)) a year.") {
                if store.realizedYearlySavings > 0 {
                    SavingsShareButton(amountYearly: store.realizedYearlySavings, kind: .saved, compact: true)
                }
            }
            VStack(spacing: 0) {
                ForEach(store.cancelledSubs) { sub in
                    NavigationLink(value: sub.id) {
                        SubscriptionRow(sub: sub, score: store.score(for: sub.id), cancelled: true, showScore: false)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.removeSubscription(sub.id)
                        } label: {
                            Label("Remove from Phantom", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
        }
    }

    /// Apply free-tier limit: keep top N by monthly cost, hide rest.
    private func visibleSubs() -> [Subscription] {
        let all = store.activeSubs.sorted { $0.monthlyAmount > $1.monthlyAmount }
        return store.isPro ? all : Array(all.prefix(Entitlements.freeSubscriptionLimit))
    }

    private func zombies() -> [Subscription] {
        visibleSubs().filter { store.score(for: $0.id) >= 80 }
            .sorted { store.score(for: $0.id) > store.score(for: $1.id) }
    }

    private func review() -> [Subscription] {
        visibleSubs().filter { let s = store.score(for: $0.id); return s >= 50 && s < 80 }
            .sorted { store.score(for: $0.id) > store.score(for: $1.id) }
    }

    private func keep() -> [Subscription] {
        visibleSubs().filter { store.score(for: $0.id) < 50 }
            .sorted { $0.monthlyAmount > $1.monthlyAmount }
    }
}

private struct ScoreSection: View {
    @Environment(AppStore.self) private var store
    let title: String
    let caption: String
    let tone: BadgeTone?
    let subs: [Subscription]

    var body: some View {
        if !subs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title, caption: caption) {
                    if let tone {
                        Badge("\(subs.count)", tone: tone)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(subs) { sub in
                        NavigationLink(value: sub.id) {
                            SubscriptionRow(sub: sub, score: store.score(for: sub.id))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.removeSubscription(sub.id)
                            } label: {
                                Label("Remove from Phantom", systemImage: "trash")
                            }
                            Button {
                                store.confirmCancellation(sub.id)
                            } label: {
                                Label("Mark as cancelled", systemImage: "checkmark.circle")
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
            }
        }
    }
}
