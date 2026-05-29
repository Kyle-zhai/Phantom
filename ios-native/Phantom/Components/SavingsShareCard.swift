import SwiftUI
import UIKit

/// A shareable "money win" card. Phantom has no growth loop today, so this turns
/// a cancel/found moment into something a user will post — the cheapest possible
/// acquisition channel at 11 users.
enum SavingsKind {
    case found   // potential — zombies spotted but not yet cancelled
    case saved   // realized — already cancelled

    var headline: String { self == .saved ? "I SAVED" : "I FOUND" }
    var tail: String {
        self == .saved
            ? "a year by killing subscriptions I forgot about"
            : "a year in subscriptions I'd forgotten about"
    }
}

/// The rendered 1080×1350 image. Built off-screen via ImageRenderer.
struct SavingsCardView: View {
    let amountYearly: Double
    let kind: SavingsKind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(.white).frame(width: 64, height: 64)
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.black)
                }
                Text("Phantom").font(.system(size: 44, weight: .heavy)).foregroundStyle(.white)
            }
            Spacer()
            Text(kind.headline).font(.system(size: 36, weight: .heavy)).foregroundStyle(Color(white: 0.55))
            Text(fmtUSD(amountYearly))
                .font(.system(size: 140, weight: .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.top, 4)
            Text(kind.tail)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color(white: 0.72))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Spacer()
            Text("Find your zombie subscriptions.\nNothing ever leaves your phone.")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(80)
        .frame(width: 1080, height: 1350, alignment: .leading)
        .background(Color.black)
    }
}

/// Drop-in share button. Renders the card lazily; falls back to text-only share
/// if rendering ever fails.
struct SavingsShareButton: View {
    let amountYearly: Double
    let kind: SavingsKind
    var compact: Bool = false

    @State private var rendered: Image?

    private var message: String {
        let amt = fmtUSD(amountYearly)
        return kind == .saved
            ? "I just cancelled \(amt)/year of subscriptions I forgot about — with Phantom, the private subscription finder. Nothing leaves your phone."
            : "I just found \(amt)/year in subscriptions I'd forgotten about — with Phantom, the private subscription finder. Nothing leaves your phone."
    }

    var body: some View {
        Group {
            if let rendered {
                ShareLink(
                    item: rendered,
                    subject: Text("My Phantom savings"),
                    message: Text(message),
                    preview: SharePreview("My Phantom savings", image: rendered)
                ) { labelView }
            } else {
                ShareLink(item: message) { labelView }
            }
        }
        .task { rendered = Self.render(amountYearly: amountYearly, kind: kind) }
    }

    @ViewBuilder private var labelView: some View {
        if compact {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                Text("Share").font(AppFont.smallB)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Palette.surface, in: Capsule())
            .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
        } else {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text(kind == .saved ? "Share this win" : "Share what you found").font(AppFont.bodyB)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.xl))
            .overlay(RoundedRectangle(cornerRadius: Radius.xl).stroke(Palette.border, lineWidth: 1))
        }
    }

    @MainActor static func render(amountYearly: Double, kind: SavingsKind) -> Image? {
        let renderer = ImageRenderer(content: SavingsCardView(amountYearly: amountYearly, kind: kind))
        renderer.scale = 2
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}
