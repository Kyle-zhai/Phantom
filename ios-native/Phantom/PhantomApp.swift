import SwiftUI
import SwiftData
import CoreData
import UIKit
import UserNotifications

/// Holds a pending notification-tap target until a view can consume it. Written
/// by `AppDelegate` (which can fire before the UI exists on a cold launch) and
/// observed by `RootTabView`.
@MainActor
@Observable
final class DeepLink {
    static let shared = DeepLink()
    var pendingSubId: String?
    /// Set by a notification whose target is a tab, not a specific sub (the
    /// "rate your subs" re-engagement nudge routes here). `RootTabView` selects
    /// Radar and clears it.
    var pendingRadar: Bool = false
    /// Share extension / Open-in dropped files into the App Group inbox.
    var pendingImport: Bool = false
    /// After the cancel flow, open the dispute sheet on the same subscription.
    var pendingDisputeId: String?
    private init() {}
}

/// Minimal app delegate purely to own the `UNUserNotificationCenter` delegate so
/// notification taps route correctly — including taps that cold-launch the app.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        if let id = info["id"] as? String {
            await MainActor.run { DeepLink.shared.pendingSubId = id }
        } else if info["route"] as? String == "radar" {
            await MainActor.run { DeepLink.shared.pendingRadar = true }
        } else if info["route"] as? String == "import" {
            await MainActor.run { DeepLink.shared.pendingImport = true }
        }
    }
}

@main
@MainActor
struct PhantomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AppStore(purchaseService: PurchaseService.shared)
    let modelContainer: ModelContainer

    static let schema = Schema([
        PersistentSubscription.self, PersistentAlert.self, UserProfile.self,
        PersistentTransaction.self, PersistentEvidence.self, PersistentSetting.self,
    ])

    init() {
        // `.automatic` syncs to the user's private iCloud database when the
        // iCloud entitlement is present (device/App Store builds) and stays
        // local when it isn't (unsigned simulator builds, tests). Same store
        // file as before, so existing users keep their data.
        do {
            guard CloudEntitlements.hasCloudKit else {
                throw NSError(domain: "Phantom", code: 1, userInfo: [NSLocalizedDescriptionKey: "no iCloud entitlement in this build"])
            }
            let cloud = ModelConfiguration(schema: Self.schema, cloudKitDatabase: .automatic)
            modelContainer = try ModelContainer(for: Self.schema, configurations: [cloud])
            CloudSyncState.shared.mode = .cloud
        } catch {
            do {
                let local = ModelConfiguration(schema: Self.schema, cloudKitDatabase: .none)
                modelContainer = try ModelContainer(for: Self.schema, configurations: [local])
                CloudSyncState.shared.mode = .local(error.localizedDescription)
            } catch {
                fatalError("Failed to set up SwiftData: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.modelContext, modelContainer.mainContext)
                .preferredColorScheme(.light)
                .tint(Palette.ink)
                .task {
                    store.attach(modelContext: modelContainer.mainContext)
                    await AccountService.shared.refresh()
                    await store.onLaunch()
                    store.flagIncomingImportIfNeeded()
                }
                .onOpenURL { url in
                    Task { await store.handleIncomingURL(url) }
                }
                // CloudKit imported changes from another device → re-read the
                // store. Coalesced so a burst of records reloads once.
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
                    store.scheduleReload()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await AccountService.shared.refresh() }
                        store.scheduleReload()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        #if DEBUG
        // Debug-only launch-arg routing for screenshot testing & visual
        // verification. Compiled out of Release so the flag strings don't
        // ship in the App Store binary.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--screen-cancel") {
            NavigationStack { CancelFlowView(subId: debugSubArg(args) ?? "peacock") }
        } else if args.contains("--screen-chargeback") {
            ChargebackGuideView(subId: debugSubArg(args) ?? "peacock")
        } else if args.contains("--screen-apple") {
            AppleSubscriptionsGuideView()
        } else if let id = debugSubArg(args) {
            NavigationStack { SubscriptionDetailView(subId: id) }
        } else if let id = debugDisputeArg(args) {
            DisputeLetterView(subId: id)
        } else if let id = debugNegotiateArg(args) {
            NavigationStack { NegotiateDetailView(subId: id) }
        } else if args.contains("--screen-paywall") {
            PaywallView()
        } else if args.contains("--screen-signin") {
            NavigationStack { OnboardingSignInView() }
        } else if args.contains("--screen-picks") {
            NavigationStack { PicksView() }
        } else if args.contains("--screen-foryou") {
            NavigationStack { ForYouView() }
        } else if args.contains("--screen-value") {
            NavigationStack { OnboardingValueView() }
        } else if args.contains("--screen-connect") {
            NavigationStack { OnboardingConnectView() }
        } else if args.contains("--screen-import") {
            ImportScreenshotView()
        } else if store.isOnboarded {
            RootTabView()
        } else {
            OnboardingWelcomeView()
        }
        #else
        if store.isOnboarded {
            RootTabView()
        } else {
            OnboardingWelcomeView()
        }
        #endif
    }

    #if DEBUG
    private func debugSubArg(_ args: [String]) -> String? {
        guard let i = args.firstIndex(of: "--sub"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    private func debugDisputeArg(_ args: [String]) -> String? {
        guard let i = args.firstIndex(of: "--dispute"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    private func debugNegotiateArg(_ args: [String]) -> String? {
        guard let i = args.firstIndex(of: "--neg"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    #endif
}
