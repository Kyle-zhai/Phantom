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
    @State private var storeKitUnavailable = false
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
                        // Plans render instantly using built-in price labels.
                        // StoreKit silently upgrades to localized prices (e.g. €27.99
                        // for EU users) once Apple's servers respond — no spinner.
                        await purchaseService.refresh()
                        if purchaseService.products.isEmpty {
                            storeKitUnavailable = true
                        }
                    }
                    .onAppear {
                        selectedPlanTier = .yearly
                        if selected == nil {
                            selected = purchaseService.yearly ?? purchaseService.monthly
                        }
                    }
                    .onChange(of: purchaseService.products) { _, _ in
                        // When products arrive after initial render, snap selection to
                        // whichever tier the user currently has visually highlighted.
                        if selected == nil {
                            selected = selectedPlanTier == .yearly
                                ? purchaseService.yearly
                                : purchaseService.monthly
                        }
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
        VStack(spacing: 12) {
            unifiedPlanCard(
                tier: .yearly,
                product: purchaseService.yearly,
                title: "Annual",
                fallbackPrice: "$29.99",
                subline: yearlySublineText,
                badge: "Refund within 30 days",
                best: true
            )
            unifiedPlanCard(
                tier: .monthly,
                product: purchaseService.monthly,
                title: "Monthly",
                fallbackPrice: "$3.99",
                subline: "per month · cancel anytime",
                badge: nil,
                best: false
            )
            if storeKitUnavailable {
                Text("Purchase will work on a real device. In the simulator, run from Xcode to test StoreKit.")
                    .font(AppFont.small)
                    .foregroundStyle(Palette.mute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
        }
    }

    /// Renders a plan card instantly using the fallback price label.
    /// If the StoreKit Product has loaded, uses its localized displayPrice
    /// and stores the Product reference for purchase.
    private func unifiedPlanCard(
        tier: PlanTier,
        product: Product?,
        title: String,
        fallbackPrice: String,
        subline: String,
        badge: String?,
        best: Bool
    ) -> some View {
        let active = selectedPlanTier == tier
        let displayPrice = product?.displayPrice ?? fallbackPrice
        return Button {
            selectedPlanTier = tier
            if let product { selected = product }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title).font(AppFont.h3).foregroundStyle(Palette.ink)
                    Spacer()
                    ZStack {
                        Circle().stroke(active ? Palette.ink : Palette.mute2, lineWidth: 2).frame(width: 22, height: 22)
                        if active { Circle().fill(Palette.ink).frame(width: 10, height: 10) }
                    }
                }
                Text(displayPrice).font(AppFont.display).foregroundStyle(Palette.ink).padding(.top, 8)
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

    private var yearlySublineText: String {
        if let y = purchaseService.yearly {
            return yearlySubline(y)
        }
        return "per year · ~$2.50 / month · save 37%"
    }

    private var ctaTitle: String {
        if purchasing { return "Processing…" }
        if let sel = selected {
            return "Start Pro · \(sel.displayPrice) / \(sel.id.hasSuffix("yearly") ? "year" : "month")"
        }
        // Static fallback price
        return selectedPlanTier == .yearly
            ? "Start Pro · $29.99 / year"
            : "Start Pro · $3.99 / month"
    }

    private var ctaDisabled: Bool { purchasing }

    private var ctaAction: () -> Void {
        if purchaseService.products.isEmpty {
            // StoreKit unavailable — show a friendly message rather than fail silently
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
