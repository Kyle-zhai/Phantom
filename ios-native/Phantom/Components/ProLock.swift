import SwiftUI

/// Overlay shown on top of Pro-only content. Tapping opens the paywall.
struct ProLockOverlay: View {
    let title: String
    let subtitle: String?
    @Binding var showPaywall: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("PRO").micro()
            }
            .foregroundStyle(Palette.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Palette.ink, in: Capsule())

            Text(title).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle).font(AppFont.small).foregroundStyle(Palette.mute)
                    .multilineTextAlignment(.center)
            }
            Button { showPaywall = true } label: {
                Text("Unlock with Pro").font(AppFont.smallB)
                    .foregroundStyle(Palette.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Palette.ink, in: Capsule())
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
    }
}

/// Tiny inline "Pro" tag for use next to feature names.
struct ProTag: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: 9, weight: .bold))
            Text("PRO").font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Palette.white)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Palette.ink, in: Capsule())
    }
}
