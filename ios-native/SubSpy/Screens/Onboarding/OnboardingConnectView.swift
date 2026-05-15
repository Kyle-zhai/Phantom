import SwiftUI

struct OnboardingConnectView: View {
    @Environment(AppStore.self) private var store
    @State private var showImport = false
    @State private var showManual = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("3 / 3").font(AppFont.smallB).foregroundStyle(Palette.mute).padding(.top, 12)
                Text("How should we find\nyour subscriptions?")
                    .font(AppFont.h1).foregroundStyle(Palette.ink)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
                Text("SubSpy never talks to your bank or stores your credentials. Pick whichever method you prefer.")
                    .font(AppFont.body).foregroundStyle(Palette.mute).padding(.top, 10)

                // Primary path: screenshots
                Button { showImport = true } label: {
                    methodCard(
                        icon: "photo.on.rectangle.angled",
                        title: "Scan from screenshots",
                        body: "Snap your bank app, Apple Wallet, or credit-card statement. We read it on-device with Vision OCR. Nothing leaves your phone.",
                        accent: Palette.black,
                        accentFg: Palette.white,
                        recommended: true
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 28)

                // Manual fallback
                Button { showManual = true } label: {
                    methodCard(
                        icon: "pencil.line",
                        title: "Add manually",
                        body: "Type in your subscriptions one by one. Best if you already know what you want to track.",
                        accent: Palette.surface,
                        accentFg: Palette.ink,
                        recommended: false
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 10) {
                    privacyRow("OCR runs on your iPhone with Apple Vision")
                    privacyRow("No bank login, no Plaid, no credentials")
                    privacyRow("Delete everything any time in Settings")
                }
                .padding(16)
                .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                .padding(.top, 24)

                PrimaryButton("Skip — explore with demo data", variant: .ghost) {
                    store.completeOnboarding(viaDemo: true)
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showImport) {
            ImportScreenshotView()
                .environment(store)
        }
        .sheet(isPresented: $showManual) {
            ManualAddSubscriptionView()
                .environment(store)
        }
    }

    private func methodCard(icon: String, title: String, body: String, accent: Color, accentFg: Color, recommended: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm).fill(accent).frame(width: 52, height: 52)
                Image(systemName: icon).foregroundStyle(accentFg).font(.system(size: 22, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                if recommended {
                    Badge("RECOMMENDED", tone: .keep)
                }
                Text(body)
                    .font(AppFont.small).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.mute2)
                .padding(.top, 16)
        }
        .padding(16)
        .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
    }

    private func privacyRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(Palette.success)
            Text(text).font(AppFont.smallB).foregroundStyle(Palette.ink)
        }
    }
}
