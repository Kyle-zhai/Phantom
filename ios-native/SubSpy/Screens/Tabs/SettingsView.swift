import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var hikeAlerts = true
    @State private var trialAlerts = true
    @State private var usageAnalysis = true
    @State private var showPaywall = false
    @State private var showManageSubs = false
    @State private var showImport = false
    @State private var showManual = false
    @State private var confirmDisconnect = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOU").font(AppFont.smallB).foregroundStyle(Palette.mute)
                    Text("Jordan Lee").font(AppFont.h1).foregroundStyle(Palette.ink)
                    Text("jordan@subspy.com").font(AppFont.body).foregroundStyle(Palette.mute)
                }
                .padding(.top, 4)

                if !store.isPro {
                    proUpsell.padding(.top, 20)
                } else {
                    proActive.padding(.top, 20)
                }

                SectionWrap(title: "Subscriptions") {
                    Button { showImport = true } label: {
                        SettingsRow(icon: "photo.on.rectangle.angled", label: "Scan from screenshots")
                    }.buttonStyle(.plain)
                    DividerLine()
                    Button { showManual = true } label: {
                        SettingsRow(icon: "pencil.line", label: "Add manually")
                    }.buttonStyle(.plain)
                }
                .padding(.top, 28)

                SectionWrap(title: "Notifications") {
                    SettingsRow(icon: "chart.line.uptrend.xyaxis", label: "Price-hike alerts", toggle: $hikeAlerts)
                    DividerLine()
                    SettingsRow(icon: "clock", label: "Trial-ending alerts", toggle: $trialAlerts)
                    DividerLine()
                    SettingsRow(icon: "moon", label: "Zombie-subscription analysis", toggle: $usageAnalysis)
                }
                .padding(.top, 28)

                SectionWrap(title: "Connected accounts") {
                    SettingsRow(icon: "link", label: "Chase ····4218", value: "Connected")
                    DividerLine()
                    SettingsRow(icon: "plus.circle", label: "Add another bank")
                }
                .padding(.top, 28)

                SectionWrap(title: "Privacy", caption: "The three things SubSpy will never do.") {
                    VStack(alignment: .leading, spacing: 12) {
                        privacyRow("never sell", suffix: "your data to anyone.")
                        privacyRow("never push", suffix: "loans or credit cards.")
                        privacyRow("never store", suffix: "your card number — read-only via Plaid.")
                    }
                    .padding(18)
                    .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.top, 28)

                SectionWrap(title: "Support") {
                    SettingsRow(icon: "questionmark.circle", label: "Help center")
                    DividerLine()
                    SettingsRow(icon: "ellipsis.message", label: "Contact us")
                    DividerLine()
                    SettingsRow(icon: "doc.text", label: "Terms & Privacy")
                }
                .padding(.top, 28)

                SectionWrap(title: "Account") {
                    if store.isPro {
                        Button { showManageSubs = true } label: {
                            SettingsRow(icon: "creditcard", label: "Manage subscription")
                        }.buttonStyle(.plain)
                        DividerLine()
                    }
                    if store.profile?.plaidConnected == true {
                        Button { confirmDisconnect = true } label: {
                            SettingsRow(icon: "link.badge.plus", label: "Disconnect bank")
                        }.buttonStyle(.plain)
                        DividerLine()
                    }
                    Button { confirmSignOut = true } label: {
                        SettingsRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign out")
                    }.buttonStyle(.plain)
                    DividerLine()
                    Button { confirmDelete = true } label: {
                        SettingsRow(icon: "trash", label: "Delete account", destructive: true)
                    }.buttonStyle(.plain)
                }
                .padding(.top, 28)

                #if DEBUG
                SectionWrap(title: "Developer", caption: "Visible in Debug builds only.") {
                    Button { store.togglePro() } label: {
                        SettingsRow(icon: "rosette", label: store.isPro ? "Disable Pro (debug)" : "Enable Pro (debug)")
                    }.buttonStyle(.plain)
                    DividerLine()
                    Button { store.resetOnboarding() } label: {
                        SettingsRow(icon: "arrow.clockwise", label: "Restart onboarding")
                    }.buttonStyle(.plain)
                }
                .padding(.top, 28)
                #endif

                Text("SubSpy · v1.0 · Made for people who hate losing money.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(store)
        }
        .sheet(isPresented: $showImport) {
            ImportScreenshotView().environment(store)
        }
        .sheet(isPresented: $showManual) {
            ManualAddSubscriptionView().environment(store)
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubs)
        .confirmationDialog(
            "Disconnect from your bank?",
            isPresented: $confirmDisconnect,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) { store.disconnectBank() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll stop syncing transactions. Your dispute letters, ratings, and cancelled list stay on this device.")
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the bank connection and clears local data on this device. Your App Store Pro subscription is unaffected.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete forever", role: .destructive) { Task { await store.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Permanent — your Plaid item is revoked, server-side data is purged, and you'll be signed out. To stop a paid subscription, also use 'Manage subscription' first.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var proUpsell: some View {
        Card(background: Palette.black, borderColor: Palette.black) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                    Text("UNLOCK PRO").micro()
                }
                .foregroundStyle(Palette.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.white.opacity(0.12), in: Capsule())

                Text("Save $47/mo on average.").font(AppFont.h2).foregroundStyle(Palette.white).padding(.top, 12)
                Text("Unlimited dispute letters, price-hike alerts, negotiation scripts.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2).padding(.top, 8)

                PrimaryButton("See plans", variant: .light, fullWidth: false) { showPaywall = true }
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var proActive: some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Palette.success).frame(width: 36, height: 36)
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("SubSpy Pro is active").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                    Text("Annual · renews next year").font(AppFont.small).foregroundStyle(Palette.mute)
                }
                Spacer()
            }
        }
    }

    private func privacyRow(_ verb: String, suffix: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(Palette.success).font(.system(size: 18))
            (Text("We ") + Text(verb).fontWeight(.bold) + Text(" \(suffix)"))
                .font(AppFont.small).foregroundStyle(Palette.ink)
        }
    }
}

private struct SectionWrap<Content: View>: View {
    let title: String
    var caption: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title, caption: caption)
            VStack(spacing: 0) { content() }
                .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let label: String
    var value: String? = nil
    var toggle: Binding<Bool>? = nil
    var destructive: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(destructive ? Palette.danger : Palette.ink)
                .frame(width: 36, height: 36)
                .background(destructive ? Palette.dangerSoft : Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
            Text(label).font(AppFont.body).foregroundStyle(destructive ? Palette.danger : Palette.ink)
            Spacer()
            if let toggle {
                Toggle("", isOn: toggle).labelsHidden().tint(Palette.ink)
            } else if let value {
                Text(value).font(AppFont.small).foregroundStyle(Palette.mute)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.mute2)
            } else {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.mute2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle().fill(Palette.border).frame(height: 1).padding(.leading, 66)
    }
}
