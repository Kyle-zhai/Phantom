import SwiftUI

/// "For you": what the user's subscriptions say about what they need, the
/// like-for-like apps that do the same job for less (or better), and the
/// complementary apps the pattern implies. All computed on this iPhone from
/// Phantom's catalog; nothing is sent anywhere and nothing is sponsored.
struct ForYouView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false
    @State private var showOwnedBundles = false

    private var recs: Recommender.Recommendations { store.recommendations }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if store.activeSubs.isEmpty {
                    emptyCard.padding(.top, 20)
                } else {
                    needsSection.padding(.top, 20)
                    replacementsSection.padding(.top, 28)
                    suggestionsSection.padding(.top, 28)
                    Text("Computed on this iPhone from Phantom's catalog. No affiliate links, no commission, no data leaves your phone.")
                        .font(AppFont.small).foregroundStyle(Palette.mute2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 28)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: String.self) { id in
            SubscriptionDetailView(subId: id)
        }
        .sheet(isPresented: $showPaywall) { PaywallView().environment(store) }
        .sheet(isPresented: $showOwnedBundles) { OwnedBundlesView().environment(store) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FOR YOU").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Text("What you\nactually need").font(AppFont.h1).foregroundStyle(Palette.ink)
            Text("Read from what you already pay for — then the same jobs done for less, and what the pattern says you're missing.")
                .font(AppFont.small).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var emptyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 28, weight: .medium)).foregroundStyle(Palette.ink)
                Text("Nothing to read yet").font(AppFont.h3).foregroundStyle(Palette.ink)
                Text("Import your subscriptions on the Radar tab. Recommendations come from what you pay for, so there's nothing to show until then.")
                    .font(AppFont.small).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Needs

    private var needsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("What you pay for", caption: recs.tags.isEmpty ? nil : recs.tags.joined(separator: " · "))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recs.needs) { need in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(need.kind.label).font(AppFont.smallB).foregroundStyle(Palette.ink)
                            Text("\(need.count) sub\(need.count == 1 ? "" : "s") · \(fmtUSD(need.monthly))/mo")
                                .font(AppFont.micro).foregroundStyle(Palette.mute)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
            }
        }
    }

    // MARK: Replacements

    private var replacementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Same job, better fit",
                          caption: recs.replacements.isEmpty
                            ? "No like-for-like alternatives in the catalog for your subscriptions yet."
                            : "For each subscription: free, cheaper, already-in-a-bundle, or simply better options.")
            ForEach(store.visibleReplacements(recs)) { group in
                replacementCard(group)
            }
            let hidden = recs.replacements.count - store.visibleReplacements(recs).count
            if hidden > 0 {
                ProLockOverlay(
                    title: "\(hidden) more subscription\(hidden == 1 ? "" : "s") with alternatives",
                    subtitle: "Pro shows every replacement — including ones that could save \(fmtUSD(recs.replacements.dropFirst().reduce(0) { $0 + $1.bestSavingMonthly * 12 })) a year.",
                    showPaywall: $showPaywall
                )
            }
        }
    }

    private func replacementCard(_ group: Recommender.Replacement) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink(value: group.sub.id) {
                    HStack(spacing: 12) {
                        Avatar(label: group.sub.name, subscriptionId: group.sub.id, bg: group.sub.brandColor, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.sub.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                            Text("You pay \(fmtUSD(group.sub.monthlyAmount))/mo · \(group.sub.kind.label)")
                                .font(AppFont.small).foregroundStyle(Palette.mute)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.mute2)
                    }
                }
                .buttonStyle(.plain)
                ForEach(Array(group.options.enumerated()), id: \.element) { i, alt in
                    Rectangle().fill(Palette.border).frame(height: 1).padding(.vertical, 12)
                    alternativeRow(alt, current: group.sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func alternativeRow(_ alt: AlternativesCatalog.Alternative, current: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Avatar(label: alt.name, subscriptionId: alt.brandId, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(alt.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                        edgeBadge(alt.edgeValue)
                    }
                    Text(priceLine(alt, current: current)).font(AppFont.small).foregroundStyle(Palette.mute)
                    if let why = alt.why, !why.isEmpty {
                        Text(why).font(AppFont.small).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            linkButtons(url: alt.url, appStoreURL: alt.appStoreURL)
        }
    }

    private func priceLine(_ alt: AlternativesCatalog.Alternative, current: Subscription) -> String {
        var parts: [String] = []
        if let p = alt.priceMonthly {
            parts.append(p == 0 ? "Free" : "\(fmtUSD(p))/mo")
            let saving = current.monthlyAmount - p
            if saving > 0.5 { parts.append("saves \(fmtUSD(saving * 12))/yr") }
        }
        if let note = alt.priceNote, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    private func edgeBadge(_ edge: AlternativesCatalog.Alternative.Edge) -> some View {
        let tone: BadgeTone = {
            switch edge {
            case .free, .cheaper: return .keep
            case .bundle: return .info
            case .better: return .review
            case .similar: return .neutral
            }
        }()
        return Badge(edge.label, tone: tone)
    }

    // MARK: Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("You might also need",
                          caption: recs.suggestions.isEmpty
                            ? "Nothing implied by your current mix."
                            : "Apps the pattern points to — each one says why.")
            ForEach(store.visibleSuggestions(recs)) { match in
                suggestionCard(match)
            }
            let hidden = recs.suggestions.count - store.visibleSuggestions(recs).count
            if hidden > 0 {
                ProLockOverlay(
                    title: "\(hidden) more suggestion\(hidden == 1 ? "" : "s") for your mix",
                    subtitle: "Pro shows every one, with the reason and the free options first.",
                    showPaywall: $showPaywall
                )
            }
        }
    }

    private func suggestionCard(_ match: Recommender.SuggestionMatch) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(match.rule.title).font(AppFont.h3).foregroundStyle(Palette.ink)
                if !match.because.isEmpty {
                    Text(Recommender.becauseText(match.because)).font(AppFont.smallB).foregroundStyle(Palette.keepFg)
                }
                Text(match.rule.reason).font(AppFont.small).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(match.apps, id: \.brandId) { app in
                    Rectangle().fill(Palette.border).frame(height: 1)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 10) {
                            Avatar(label: app.name, subscriptionId: app.brandId, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(app.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                    if let p = app.priceMonthly {
                                        Text(p == 0 ? "Free" : "\(fmtUSD(p))/mo").font(AppFont.smallB).foregroundStyle(p == 0 ? Palette.keepFg : Palette.ink)
                                    }
                                }
                                if let note = app.priceNote, !note.isEmpty {
                                    Text(note).font(AppFont.micro).foregroundStyle(Palette.mute2)
                                }
                                if let why = app.why, !why.isEmpty {
                                    Text(why).font(AppFont.small).foregroundStyle(Palette.mute)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        if app.isInternal {
                            internalButton(app.brandId)
                        } else {
                            linkButtons(url: app.url, appStoreURL: app.appStoreURL)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Buttons

    @ViewBuilder
    private func linkButtons(url: String?, appStoreURL: String?) -> some View {
        let site = url.flatMap(URL.init(string:))
        let store = appStoreURL.flatMap(URL.init(string:))
        if site != nil || store != nil {
            HStack(spacing: 8) {
                if let store {
                    Button { openURL(store) } label: { pill("App Store", filled: true) }.buttonStyle(.plain)
                }
                if let site {
                    Button { openURL(site) } label: { pill(site.host?.replacingOccurrences(of: "www.", with: "") ?? "Website", filled: false) }.buttonStyle(.plain)
                }
            }
            .padding(.leading, 46)
        }
    }

    private func internalButton(_ id: String) -> some View {
        Button {
            switch id {
            case "phantom-negotiate": store.selectedTab = 2
            case "phantom-bundles": showOwnedBundles = true
            default: break
            }
        } label: {
            pill(id == "phantom-negotiate" ? "Open Negotiate" : "Check your bundles", filled: true)
        }
        .buttonStyle(.plain)
        .padding(.leading, 46)
    }

    private func pill(_ text: String, filled: Bool) -> some View {
        Text(text).font(AppFont.smallB)
            .foregroundStyle(filled ? Palette.white : Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(filled ? Palette.ink : Palette.surface, in: Capsule())
    }
}
