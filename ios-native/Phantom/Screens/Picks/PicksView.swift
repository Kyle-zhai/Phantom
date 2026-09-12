import SwiftUI

// Picks — the public app leaderboard — was built but parked before release
// on 2026-09-11; tab 3 now holds the For-you recommendations. The whole
// feature is compiled out of Release so the shipping app contains no
// CloudKit *public* database code at all, which is what the privacy policy
// promises ("no part of Phantom is public"). It stays behind DEBUG rather
// than being deleted so `--screen-picks` and PickTests keep working, and so
// reviving it is a one-line change to this guard.
#if DEBUG

/// The Picks tab: apps Phantom users recommend, grouped by what you use them
/// for and ranked by how many people opened them. Anyone can submit.
struct PicksView: View {
    @Environment(AppStore.self) private var store
    @State private var picks = PicksService.shared
    @State private var account = AccountService.shared
    @State private var category: PickCategory? = nil
    @State private var selected: AppPick?
    @State private var showSubmit = false

    private var ranked: [AppPick] { picks.visible(category: category) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                categoryChips.padding(.top, 18)

                switch picks.state {
                case .loading:
                    loadingCard.padding(.top, 20)
                case .error(let msg):
                    errorCard(msg).padding(.top, 20)
                case .idle, .loaded:
                    if ranked.isEmpty {
                        emptyCard.padding(.top, 20)
                    } else {
                        list.padding(.top, 20)
                    }
                }

                PrimaryButton("Submit your app") { showSubmit = true } leading: {
                    Image(systemName: "plus.circle")
                }
                .padding(.top, 24)
                Text("Ranked purely by opens. Reviewed before listing. Phantom takes no commission and shows no names.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)

                if !picks.myPicks.isEmpty {
                    mySubmissions.padding(.top, 28)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await picks.refresh() }
        .task { await picks.refresh() }
        .sheet(item: $selected) { pick in
            PickDetailView(pick: pick).environment(store)
        }
        .sheet(isPresented: $showSubmit) {
            SubmitPickView().environment(store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PICKS").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Text("Apps people\nactually keep").font(AppFont.h1).foregroundStyle(Palette.ink)
            Text("Recommended by Phantom users, by what you use them for. The number is how many people opened each one.")
                .font(AppFont.small).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, label: "All", symbol: "trophy")
                ForEach(PickCategory.allCases) { c in
                    chip(c, label: c.rawValue, symbol: c.symbol)
                }
            }
        }
    }

    private func chip(_ c: PickCategory?, label: String, symbol: String) -> some View {
        let active = category == c
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            category = c
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                Text(label).font(AppFont.smallB)
            }
            .foregroundStyle(active ? Palette.white : Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(active ? Palette.ink : Palette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(ranked.enumerated()), id: \.element.id) { i, pick in
                if i > 0 { Rectangle().fill(Palette.border).frame(height: 1).padding(.leading, 66) }
                Button { selected = pick } label: {
                    PickRow(rank: i + 1, pick: pick)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
    }

    private var loadingCard: some View {
        Card {
            HStack(spacing: 12) {
                ProgressView().tint(Palette.ink)
                Text("Loading the leaderboard…").font(AppFont.small).foregroundStyle(Palette.mute)
                Spacer()
            }
        }
    }

    private func errorCard(_ msg: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Can't reach the leaderboard").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                Text(msg).font(AppFont.small).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                Button { Task { await picks.refresh() } } label: {
                    Text("Try again").font(AppFont.smallB).foregroundStyle(Palette.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Palette.ink, in: Capsule())
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "trophy").font(.system(size: 28, weight: .medium)).foregroundStyle(Palette.ink)
                Text(category == nil ? "Nothing here yet" : "No picks in \(category!.rawValue) yet")
                    .font(AppFont.h3).foregroundStyle(Palette.ink)
                Text("Be the first: submit an app you'd actually pay for. It goes live after a quick review.")
                    .font(AppFont.small).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mySubmissions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your submissions", caption: "Pending ones appear on the board once reviewed.")
            VStack(spacing: 0) {
                ForEach(Array(picks.myPicks.enumerated()), id: \.element.id) { i, pick in
                    if i > 0 { Rectangle().fill(Palette.border).frame(height: 1).padding(.leading, 16) }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pick.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                            Text(pick.category.rawValue).font(AppFont.small).foregroundStyle(Palette.mute)
                        }
                        Spacer()
                        statusChip(pick.status)
                        if pick.status == .approved {
                            Text("\(pick.clicks) opens").font(AppFont.smallB).foregroundStyle(Palette.ink)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
        }
    }

    private func statusChip(_ status: PickStatus) -> some View {
        let (label, tone): (String, BadgeTone) = {
            switch status {
            case .pending: return ("In review", .review)
            case .approved: return ("Live", .keep)
            case .rejected: return ("Not listed", .zombie)
            }
        }()
        return Badge(label, tone: tone)
    }
}

struct PickRow: View {
    let rank: Int
    let pick: AppPick

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(AppFont.h3).foregroundStyle(rank <= 3 ? Palette.ink : Palette.mute)
                .frame(width: 26, alignment: .center)
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm).fill(Palette.surface)
                Image(systemName: pick.category.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(pick.name).font(AppFont.bodyB).foregroundStyle(Palette.ink).lineLimit(1)
                Text(pick.tagline).font(AppFont.small).foregroundStyle(Palette.mute).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap").font(.system(size: 11, weight: .semibold))
                    Text("\(pick.clicks)").font(AppFont.smallB)
                }
                .foregroundStyle(Palette.ink)
                Text("opens").font(AppFont.micro).foregroundStyle(Palette.mute2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#endif
