import SwiftUI
import StoreKit
import AuthenticationServices

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false
    @State private var showManageSubs = false
    @State private var showImport = false
    @State private var showManual = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var confirmClearAll = false
    @State private var showEditProfile = false
    @State private var showAppleGuide = false
    @State private var showOwnedBundles = false
    @State private var account = AccountService.shared

    private var profileDisplayName: String {
        let n = store.profile?.fullName ?? ""
        return n.isEmpty ? "Add your name" : n
    }
    private var profileDisplayEmail: String {
        let e = store.profile?.email ?? ""
        return e.isEmpty ? "Tap Edit profile to add your email" : e
    }

    var body: some View {
        @Bindable var bindable = store
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOU").font(AppFont.smallB).foregroundStyle(Palette.mute)
                    Text(profileDisplayName)
                        .font(AppFont.h1).foregroundStyle(Palette.ink)
                    Text(profileDisplayEmail)
                        .font(AppFont.body).foregroundStyle(Palette.mute)
                    Button {
                        showEditProfile = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Edit profile").font(AppFont.smallB)
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Palette.surface, in: Capsule())
                        .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(.top, 4)

                if store.isSampleMode {
                    sampleModeBanner.padding(.top, 16)
                }

                if !store.isPro {
                    proUpsell.padding(.top, 20)
                } else {
                    proActive.padding(.top, 20)
                }

                SectionWrap(title: "Subscriptions") {
                    Button { showAppleGuide = true } label: {
                        SettingsRow(icon: "applelogo", label: "Apple subscriptions")
                    }.buttonStyle(.plain)
                    DividerLine()
                    Button { showImport = true } label: {
                        SettingsRow(icon: "photo.on.rectangle.angled", label: "Screenshot or CSV")
                    }.buttonStyle(.plain)
                    DividerLine()
                    Button { showManual = true } label: {
                        SettingsRow(icon: "pencil.line", label: "Add manually")
                    }.buttonStyle(.plain)
                    if !store.subscriptions.isEmpty || !store.alerts.isEmpty {
                        DividerLine()
                        Button { confirmClearAll = true } label: {
                            SettingsRow(icon: "trash", label: "Clear all subscriptions", destructive: true)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.top, 28)

                SectionWrap(
                    title: "Already covered",
                    caption: "Tell Phantom what you already pay for — Prime, Apple One, your carrier plan, a premium card — and it flags subscriptions those already include."
                ) {
                    Button { showOwnedBundles = true } label: {
                        SettingsRow(
                            icon: "checkmark.seal",
                            label: "What you already have",
                            value: store.ownedBundleIds.union(store.inferredBundleIds).isEmpty
                                ? nil
                                : "\(store.ownedBundleIds.union(store.inferredBundleIds).count) selected"
                        )
                    }.buttonStyle(.plain)
                }
                .padding(.top, 28)

                SectionWrap(
                    title: "Notifications",
                    caption: store.notificationsAuthorized ? nil : "Turn these on to catch trials and price hikes before they bill you."
                ) {
                    if !store.notificationsAuthorized {
                        Button { Task { await enableOrOpenSettings() } } label: {
                            SettingsRow(icon: "bell.badge", label: "Turn on notifications")
                        }.buttonStyle(.plain)
                        DividerLine()
                    }
                    SettingsRow(icon: "chart.line.uptrend.xyaxis", label: "Price-hike alerts", toggle: $bindable.notifyHikes)
                    DividerLine()
                    SettingsRow(icon: "clock", label: "Trial-ending alerts", toggle: $bindable.notifyTrials)
                    DividerLine()
                    SettingsRow(icon: "moon", label: "Zombie-subscription analysis", toggle: $bindable.notifyZombies)
                    DividerLine()
                    SettingsRow(icon: "arrow.clockwise", label: "Monthly re-scan reminder", toggle: $bindable.notifyRescan)
                }
                .padding(.top, 28)
                .onChange(of: store.notifyHikes) { _, _ in Task { await store.rescheduleAllNotifications() } }
                .onChange(of: store.notifyTrials) { _, _ in Task { await store.rescheduleAllNotifications() } }
                .onChange(of: store.notifyZombies) { _, _ in Task { await store.rescheduleAllNotifications() } }
                .onChange(of: store.notifyRescan) { _, _ in Task { await store.rescheduleAllNotifications() } }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Privacy", caption: "The three things Phantom will never do.")
                    VStack(alignment: .leading, spacing: 12) {
                        privacyRow("never sell", suffix: "your data to anyone.")
                        privacyRow("never push", suffix: "loans or credit cards.")
                        privacyRow("never store", suffix: "your card number — OCR runs entirely on your iPhone.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.top, 28)

                SectionWrap(title: "Support") {
                    Button { openURL(AppConfig.websiteURL) } label: {
                        SettingsRow(icon: "questionmark.circle", label: "Help center")
                    }.buttonStyle(.plain)
                    DividerLine()
                    Button { openURL(AppConfig.supportEmailURL) } label: {
                        SettingsRow(icon: "ellipsis.message", label: "Contact us")
                    }.buttonStyle(.plain)
                    DividerLine()
                    Button { openURL(AppConfig.termsOfUseURL) } label: {
                        SettingsRow(icon: "doc.text", label: "Terms of Use")
                    }.buttonStyle(.plain)
                    DividerLine()
                    Button { openURL(AppConfig.privacyPolicyURL) } label: {
                        SettingsRow(icon: "lock.shield", label: "Privacy Policy")
                    }.buttonStyle(.plain)
                }
                .padding(.top, 28)

                SectionWrap(
                    title: "Account",
                    caption: account.isSignedIn
                        ? "Everything is saved to your own iCloud. Phantom has no server and never sees it."
                        : "Sign in with Apple to keep your data on every iPhone. Nothing is uploaded to Phantom — it stays in your iCloud."
                ) {
                    if account.isSignedIn {
                        SettingsRow(icon: "person.crop.circle.badge.checkmark",
                                    label: account.displayName.isEmpty ? "Signed in with Apple" : account.displayName,
                                    value: account.email.isEmpty ? nil : account.email)
                        DividerLine()
                        SettingsRow(icon: account.syncActive ? "icloud.fill" : "icloud.slash", label: account.syncStatusText)
                        DividerLine()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            SignInWithAppleButton(.signIn) { request in
                                account.configure(request)
                            } onCompletion: { result in
                                if account.handle(result) { prefillProfileFromAccount() }
                            }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            if let err = account.lastError {
                                Text(err).font(AppFont.small).foregroundStyle(Palette.danger)
                            }
                            Text(account.syncStatusText).font(AppFont.small).foregroundStyle(Palette.mute)
                        }
                        .padding(16)
                        DividerLine()
                    }
                    if store.isPro {
                        Button { showManageSubs = true } label: {
                            SettingsRow(icon: "creditcard", label: "Manage subscription")
                        }.buttonStyle(.plain)
                        DividerLine()
                    }
                    if account.isSignedIn {
                        Button { confirmSignOut = true } label: {
                            SettingsRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign out")
                        }.buttonStyle(.plain)
                        DividerLine()
                    }
                    Button { confirmDelete = true } label: {
                        SettingsRow(icon: "trash", label: "Delete account & data", destructive: true)
                    }.buttonStyle(.plain)
                }
                .padding(.top, 28)

                Text("Phantom · v1.2.0 · Made for people who hate losing money.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .task {
            await store.refreshNotificationAuthorization()
            await account.refresh()
        }
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
        .sheet(isPresented: $showEditProfile) {
            EditProfileView().environment(store)
        }
        .sheet(isPresented: $showAppleGuide) {
            AppleSubscriptionsGuideView().environment(store)
        }
        .sheet(isPresented: $showOwnedBundles) {
            OwnedBundlesView().environment(store)
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubs)
        .confirmationDialog(
            "Sign out?",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Signs you out of your Apple account inside Phantom. Your subscriptions and proof are NOT deleted — they stay on this iPhone and in your iCloud. Your App Store Pro subscription is unaffected.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete forever", role: .destructive) { Task { await store.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Permanent — erases every subscription, dispute letter, rating, cancel proof and setting from this iPhone and from your iCloud (the deletion syncs to your other devices), then signs you out. Phantom has no server, so nothing else exists to delete. To stop a paid Pro subscription, use 'Manage subscription' first.")
        }
        .confirmationDialog(
            "Clear all subscriptions?",
            isPresented: $confirmClearAll,
            titleVisibility: .visible
        ) {
            Button("Clear everything", role: .destructive) { Task { await store.clearAllData() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every imported subscription, alert, and cancellation record from this device. You stay signed in and your Pro subscription is unaffected. You can re-import by scanning new screenshots.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func prefillProfileFromAccount() {
        let name = (store.profile?.fullName ?? "").isEmpty ? account.displayName : (store.profile?.fullName ?? "")
        let email = (store.profile?.email ?? "").isEmpty ? account.email : (store.profile?.email ?? "")
        if !name.isEmpty || !email.isEmpty { store.setProfile(name: name, email: email) }
    }

    /// First tap requests OS permission; if previously denied, the system won't
    /// re-prompt, so deep-link the user into the iOS Settings app instead.
    private func enableOrOpenSettings() async {
        let status = await NotificationService.currentAuthorization()
        if status == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        } else {
            await store.enableNotifications()
        }
    }

    private var sampleModeBanner: some View {
        Card(background: Palette.warnSoft, borderColor: Palette.warnSoft) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(Palette.warn)
                    Text("SAMPLE DATA MODE").font(AppFont.smallB).foregroundStyle(Palette.warn)
                }
                Text("You're previewing Phantom with \(store.subscriptions.count) example subscriptions. None of this is real — it's here so you can see what the app looks like with data.")
                    .font(AppFont.small).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    store.clearSampleData()
                } label: {
                    Text("Clear sample data").font(AppFont.smallB)
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Palette.ink, in: Capsule())
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

                Text("The cancel-and-clawback kit.").font(AppFont.h2).foregroundStyle(Palette.white).padding(.top, 12)
                Text("Dispute letters, chargeback packets, cancel checklists, evidence locker.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2).padding(.top, 8)

                PrimaryButton("See plans", variant: .light, fullWidth: false) { showPaywall = true }
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var proActive: some View {
        let plan = store.purchaseService.activePlan
        let exp = store.purchaseService.activeExpirationDate
        let planLabel: String = {
            switch plan {
            case .monthly: return "Monthly"
            case .yearly:  return "Annual"
            case .none:    return ""
            }
        }()
        let renewLabel: String = {
            guard let exp else {
                return plan == .monthly ? "renews next month" : "renews next year"
            }
            let f = DateFormatter()
            f.dateStyle = .medium
            return "renews \(f.string(from: exp))"
        }()

        return VStack(spacing: 12) {
            Card {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Palette.success).frame(width: 36, height: 36)
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Phantom Pro is active").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                        Text("\(planLabel) · \(renewLabel)").font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                    Spacer()
                }
            }

            // Cross-sell: when on Monthly, surface the savings of switching to
            // Annual. Tapping opens the system's Manage Subscriptions sheet
            // where Apple's auto-upgrade flow handles the proration.
            //
            // Fall back to the storekit config's listed prices ($3.99/mo,
            // $29.99/yr) when the live Products aren't loaded yet so the
            // card always renders for monthly subscribers.
            if plan == .monthly {
                let monthlyD = store.purchaseService.monthly.map { NSDecimalNumber(decimal: $0.price).doubleValue } ?? 3.99
                let yearlyD  = store.purchaseService.yearly.map  { NSDecimalNumber(decimal: $0.price).doubleValue } ?? 29.99
                let monthlyDisplay = store.purchaseService.monthly?.displayPrice ?? "$3.99"
                let yearlyDisplay  = store.purchaseService.yearly?.displayPrice  ?? "$29.99"
                let savings = max(0, monthlyD * 12 - yearlyD)
                let pct     = monthlyD > 0 ? Int((savings / (monthlyD * 12) * 100).rounded()) : 0
                if savings > 0.01 {
                    Button { showManageSubs = true } label: {
                        Card {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Palette.ink).frame(width: 36, height: 36)
                                    Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Switch to Annual — save \(pct)%").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                    Text("\(yearlyDisplay)/yr vs \(monthlyDisplay)/mo · \(fmtUSD(savings)) less per year")
                                        .font(AppFont.small).foregroundStyle(Palette.mute)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Palette.mute)
                            }
                        }
                    }.buttonStyle(.plain)
                }
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
