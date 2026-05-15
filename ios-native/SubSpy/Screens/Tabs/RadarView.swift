import SwiftUI

struct RadarView: View {
    @Environment(AppStore.self) private var store
    @State private var showImport = false
    @State private var showManual = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                heroPanel.padding(.top, 20)
                if store.subscriptions.isEmpty {
                    emptyStateCard.padding(.top, 16)
                }
                if store.potentialSavings > 0 {
                    savingsCard.padding(.top, 16)
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
        .sheet(isPresented: $showImport) {
            ImportScreenshotView().environment(store)
        }
        .sheet(isPresented: $showManual) {
            ManualAddSubscriptionView().environment(store)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environment(store)
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
                        showImport = true
                    } label: {
                        Label("Scan from screenshots", systemImage: "photo.on.rectangle.angled")
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
                    store.selectedTab = 3
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
            HStack(spacing: 0) {
                stat("ACTIVE", "\(store.activeSubs.count)", color: Palette.white)
                divider
                stat("ZOMBIES", "\(store.zombieCount)", color: Palette.danger)
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

    private var emptyStateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("Nothing here yet")
                    .font(AppFont.h3)
                    .foregroundStyle(Palette.ink)
                Text("Snap a screenshot of your bank app or Apple Wallet — we'll auto-detect every recurring charge.")
                    .font(AppFont.small)
                    .foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { showImport = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Scan").font(AppFont.smallB)
                        }
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Palette.ink, in: Capsule())
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

    private var savingsCard: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.success)
                    .frame(width: 44, height: 44)
                    .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 4) {
                    Text("POTENTIAL MONTHLY SAVINGS").font(AppFont.smallB).foregroundStyle(Palette.success)
                    Text(fmtUSD(store.potentialSavings)).font(AppFont.h1).foregroundStyle(Palette.ink)
                    Text("Cancel the \(store.zombieCount) zombie \(store.zombieCount == 1 ? "subscription" : "subscriptions") below to claim it.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var cancelledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Cancelled this session") {
                Badge(fmtUSD(store.cancelledSubs.reduce(0) { $0 + $1.monthlyAmount }), tone: .keep)
            }
            VStack(spacing: 0) {
                ForEach(store.cancelledSubs) { sub in
                    NavigationLink(value: sub.id) {
                        SubscriptionRow(sub: sub, score: store.score(for: sub.id), cancelled: true, showScore: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
        }
        .navigationDestination(for: String.self) { id in
            SubscriptionDetailView(subId: id)
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
                    }
                }
                .padding(.horizontal, 12)
                .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
            }
            .navigationDestination(for: String.self) { id in
                SubscriptionDetailView(subId: id)
            }
        }
    }
}
