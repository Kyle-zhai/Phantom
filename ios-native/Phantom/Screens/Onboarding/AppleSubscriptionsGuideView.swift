import SwiftUI

/// The lowest-friction first scan. iOS already lists every App Store-billed
/// subscription on one screen — screenshotting that is far less work than
/// digging up bank statements, which is the #1 reason people abandon
/// subscription trackers. This guides the user there, then hands off to the
/// existing OCR importer.
struct AppleSubscriptionsGuideView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showImport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar

                Text("The 30-second start")
                    .font(AppFont.h1).foregroundStyle(Palette.ink)
                    .padding(.top, 16)
                Text("Your iPhone already lists every subscription Apple bills you for. Screenshot that one screen and Phantom reads it instantly — no bank statements needed.")
                    .font(AppFont.body).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 16) {
                    step(1, "Tap “Open Apple Subscriptions” below.")
                    step(2, "Screenshot the list — press Side + Volume Up.")
                    step(3, "Come back here and tap “Scan my screenshot.”")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .padding(.top, 24)

                PrimaryButton("Open Apple Subscriptions") {
                    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } leading: {
                    Image(systemName: "applelogo")
                }
                .padding(.top, 24)

                PrimaryButton("Scan my screenshot", variant: .secondary) {
                    showImport = true
                } leading: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .padding(.top, 12)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(Palette.mute).font(.system(size: 14))
                    Text("This catches subscriptions Apple bills (Netflix, Spotify, iCloud+, and more). For anything billed straight to your card, scan a bank statement too.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showImport) {
            ImportScreenshotView().environment(store)
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
            Text("QUICK START").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Palette.ink).frame(width: 26, height: 26)
                Text("\(n)").font(AppFont.smallB).foregroundStyle(Palette.white)
            }
            Text(text).font(AppFont.body).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
