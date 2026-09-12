import SwiftUI

// Picks — the public app leaderboard — was built but parked before release
// on 2026-09-11; tab 3 now holds the For-you recommendations. The whole
// feature is compiled out of Release so the shipping app contains no
// CloudKit *public* database code at all, which is what the privacy policy
// promises ("no part of Phantom is public"). It stays behind DEBUG rather
// than being deleted so `--screen-picks` and PickTests keep working, and so
// reviving it is a one-line change to this guard.
#if DEBUG

struct PickDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var picks = PicksService.shared
    @State private var screenshot: URL?
    @State private var loadingShot = true
    @State private var showReport = false
    @State private var reportSent = false
    @State private var counted: Bool? = nil

    let pick: AppPick

    private var live: AppPick { picks.picks.first { $0.id == pick.id } ?? pick }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.md).fill(Palette.surface)
                        Image(systemName: pick.category.symbol).font(.system(size: 26, weight: .semibold)).foregroundStyle(Palette.ink)
                    }
                    .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(live.name).font(AppFont.h2).foregroundStyle(Palette.ink)
                        Text(live.tagline).font(AppFont.body).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 20)

                HStack(spacing: 8) {
                    Badge(pick.category.rawValue, tone: .keep)
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap").font(.system(size: 11, weight: .semibold))
                        Text("\(live.clicks) opens").font(AppFont.smallB)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Palette.surface, in: Capsule())
                    Spacer()
                }
                .padding(.top, 16)

                Group {
                    if let screenshot {
                        AsyncImage(url: screenshot) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Rectangle().fill(Palette.surface).aspectRatio(9 / 16, contentMode: .fit)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
                    } else if loadingShot {
                        Rectangle().fill(Palette.surface).frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(ProgressView().tint(Palette.ink))
                    }
                }
                .padding(.top, 20)

                if !live.details.isEmpty {
                    Text(live.details).font(AppFont.body).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)
                }

                PrimaryButton("Open \(live.host)") {
                    openURL(live.url)
                    Task { counted = await picks.registerOpen(live) }
                } leading: {
                    Image(systemName: "arrow.up.right.square")
                }
                .padding(.top, 24)
                if let appStore = live.appStoreURL {
                    PrimaryButton("View on the App Store", variant: .secondary) {
                        openURL(appStore)
                        Task { counted = await picks.registerOpen(live) }
                    } leading: {
                        Image(systemName: "applelogo")
                    }
                    .padding(.top, 10)
                }
                if counted == true {
                    Text("Counted — thanks. One open per person per day.")
                        .font(AppFont.small).foregroundStyle(Palette.keepFg)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                }

                Text("Submitted by a Phantom user. Not an endorsement — Phantom takes no commission and shows no names.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)

                HStack(spacing: 10) {
                    Button { showReport = true } label: {
                        Text(reportSent ? "Reported" : "Report").font(AppFont.smallB).foregroundStyle(Palette.danger)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Palette.dangerSoft, in: Capsule())
                    }
                    .disabled(reportSent)
                    Button {
                        picks.hide(submitter: live.submitterToken)
                        dismiss()
                    } label: {
                        Text("Hide this developer's apps").font(AppFont.smallB).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Palette.surface, in: Capsule())
                    }
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .task {
            screenshot = await picks.screenshotURL(for: pick)
            loadingShot = false
        }
        .confirmationDialog("Report this listing", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(["Spam or misleading", "Not an app", "Offensive content", "Broken link"], id: \.self) { reason in
                Button(reason) { Task { try? await picks.report(live, reason: reason); reportSent = true; dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reports hide it for you right away and go to Phantom for review.")
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Palette.surface, in: Circle())
            }
            Spacer()
            Text("PICK").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }
}

#endif
