import SwiftUI
import StoreKit

private let perks = [
    "Unlimited subscription scans",
    "Zombie Score on every subscription",
    "7-day price-hike alerts",
    "Unlimited dispute letters",
    "Retention negotiation scripts",
    "Priority chat support",
]

struct PaywallView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Product?
    @State private var purchasing = false
    @State private var purchaseError: String?
    @State private var loadTimedOut = false
    @State private var selectedPlanTier: PlanTier = .yearly

    private enum PlanTier { case monthly, yearly }

    private var purchaseService: PurchaseService { store.purchaseService }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 40, height: 40)
                            .background(Palette.surface, in: Circle())
                    }
                    Spacer()
                    Button("Restore") {
                        Task { await purchaseService.restore() }
                    }
                    .font(AppFont.smallB)
                    .foregroundStyle(Palette.mute)
                }
                .padding(.top, 4)

                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.lg).fill(Palette.black).frame(width: 72, height: 72)
                        Image(systemName: "sparkles").font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.white)
                    }
                    Text("Phantom Pro").font(AppFont.h1).foregroundStyle(Palette.ink).padding(.top, 22)
                    Text("Most Pro users save $47/month on average. Pro pays for itself in week one.")
                        .font(AppFont.body).foregroundStyle(Palette.mute)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320).padding(.top, 8)
                }
                .padding(.top, 8)

                planSection
                    .padding(.top, 30)
                    .task {
                        // Kick off product load in parallel with a 2-second timer.
                        // If StoreKit hasn't returned products by then (e.g. running
                        // outside Xcode without the .storekit config), fall back to
                        // static plan cards so the screen is usable.
                        Task { await purchaseService.refresh() }
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if purchaseService.products.isEmpty {
                            loadTimedOut = true
                        }
                    }
                    .onAppear {
                        if selected == nil { selected = purchaseService.yearly ?? purchaseService.monthly }
                    }

                VStack(spacing: 14) {
                    ForEach(perks, id: \.self) { perk in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Palette.success).frame(width: 22, height: 22)
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.white)
                            }
                            Text(perk).font(AppFont.body).foregroundStyle(Palette.ink)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.top, 30)

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(Palette.success).font(.system(size: 18))
                    (Text("We ") + Text("never").fontWeight(.bold) + Text(" sell your data and ") + Text("never").fontWeight(.bold) + Text(" push loans. Cancel any time."))
                        .font(AppFont.small).foregroundStyle(Palette.ink)
                }
                .padding(16)
                .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                .padding(.top, 24)

                if let err = purchaseError {
                    Text(err).font(AppFont.small).foregroundStyle(Palette.danger).padding(.top, 12)
                }

                PrimaryButton(ctaTitle, variant: .primary, action: ctaAction)
                    .disabled(ctaDisabled)
                    .padding(.top, 24)
                PrimaryButton("Continue with Free", variant: .ghost) { dismiss() }
                    .padding(.top, 12)

                Text("Auto-renews. Cancel any time in Settings.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
        .background(Palette.white)
        .onChange(of: purchaseService.purchasedProductIds) { _, _ in
            if purchaseService.isPro { dismiss() }
        }
    }

    @ViewBuilder
    private var planSection: some View {
        if !purchaseService.products.isEmpty {
            // Real StoreKit products loaded
            VStack(spacing: 12) {
                if let yearly = purchaseService.yearly {
                    planCard(product: yearly,
                             title: "Annual",
                             subline: yearlySubline(yearly),
                             badge: "Refund within 30 days",
                             best: true)
                }
                if let monthly = purchaseService.monthly {
                    planCard(product: monthly,
                             title: "Monthly",
                             subline: "per month · cancel anytime",
                             badge: nil,
                             best: false)
                }
            }
        } else if loadTimedOut {
            // Fallback: display static plan info if StoreKit unavailable
            VStack(spacing: 12) {
                staticPlanCard(tier: .yearly,
                               title: "Annual",
                               price: "$29.99",
                               subline: "per year · ~$2.50 / month · save 37%",
                               badge: "Refund within 30 days",
                               best: true)
                staticPlanCard(tier: .monthly,
                               title: "Monthly",
                               price: "$3.99",
                               subline: "per month · cancel anytime",
                               badge: nil,
                               best: false)
                Text("Purchase available on real device. In the simulator, run from Xcode to enable StoreKit testing.")
                    .font(AppFont.small)
                    .foregroundStyle(Palette.mute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
        } else {
            // Initial loading state
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading plans…").font(AppFont.small).foregroundStyle(Palette.mute)
            }
            .padding(.vertical, 30)
        }
    }

    private func staticPlanCard(tier: PlanTier, title: String, price: String, subline: String, badge: String?, best: Bool) -> some View {
        let active = selectedPlanTier == tier
        return Button { selectedPlanTier = tier } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title).font(AppFont.h3).foregroundStyle(Palette.ink)
                    Spacer()
                    ZStack {
                        Circle().stroke(active ? Palette.ink : Palette.mute2, lineWidth: 2).frame(width: 22, height: 22)
                        if active { Circle().fill(Palette.ink).frame(width: 10, height: 10) }
                    }
                }
                Text(price).font(AppFont.display).foregroundStyle(Palette.ink).padding(.top, 8)
                Text(subline).font(AppFont.small).foregroundStyle(Palette.mute).padding(.top, 2)
                if let badge { Badge(badge, tone: .keep).padding(.top, 12) }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(active ? Palette.ink : Palette.border, lineWidth: active ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if best {
                    Text("BEST VALUE").micro()
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Palette.ink, in: Capsule())
                        .offset(x: -16, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var ctaTitle: String {
        if purchasing { return "Processing…" }
        if let sel = selected {
            return "Start Pro · \(sel.displayPrice) / \(sel.id.hasSuffix("yearly") ? "year" : "month")"
        }
        if loadTimedOut {
            return selectedPlanTier == .yearly
                ? "Start Pro · $29.99 / year"
                : "Start Pro · $3.99 / month"
        }
        return "Start Pro"
    }

    private var ctaDisabled: Bool {
        purchasing || (selected == nil && !loadTimedOut)
    }

    private var ctaAction: () -> Void {
        if purchaseService.products.isEmpty && loadTimedOut {
            // No StoreKit — show informational error rather than fail silently
            return { purchaseError = "Purchases unavailable in this build. Run from Xcode or install via TestFlight to test." }
        }
        return { Task { await purchase() } }
    }

    private func yearlySubline(_ y: Product) -> String {
        let monthly = (y.price as NSDecimalNumber).dividing(by: 12)
        let priceFormatter = NumberFormatter()
        priceFormatter.numberStyle = .currency
        priceFormatter.locale = y.priceFormatStyle.locale
        let mPretty = priceFormatter.string(from: monthly) ?? "$2.50"
        return "per year · ~\(mPretty) / month"
    }

    private func planCard(product: Product, title: String, subline: String, badge: String?, best: Bool) -> some View {
        let active = selected?.id == product.id
        return Button { selected = product } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title).font(AppFont.h3).foregroundStyle(Palette.ink)
                    Spacer()
                    ZStack {
                        Circle().stroke(active ? Palette.ink : Palette.mute2, lineWidth: 2).frame(width: 22, height: 22)
                        if active { Circle().fill(Palette.ink).frame(width: 10, height: 10) }
                    }
                }
                Text(product.displayPrice).font(AppFont.display).foregroundStyle(Palette.ink).padding(.top, 8)
                Text(subline).font(AppFont.small).foregroundStyle(Palette.mute).padding(.top, 2)
                if let badge { Badge(badge, tone: .keep).padding(.top, 12) }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(active ? Palette.ink : Palette.border, lineWidth: active ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if best {
                    Text("BEST VALUE").micro()
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Palette.ink, in: Capsule())
                        .offset(x: -16, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func purchase() async {
        guard let sel = selected else { return }
        purchasing = true
        purchaseError = nil
        defer { purchasing = false }
        let ok = await purchaseService.purchase(sel)
        if !ok, let e = purchaseService.lastError { purchaseError = e }
    }
}
