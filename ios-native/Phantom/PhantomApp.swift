import SwiftUI
import SwiftData
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
            // Tab-level target (e.g. the rating re-engagement nudge) — no sub to open.
            await MainActor.run { DeepLink.shared.pendingRadar = true }
        }
    }
}

@main
@MainActor
struct PhantomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore(purchaseService: PurchaseService.shared)
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: PersistentSubscription.self, PersistentAlert.self, UserProfile.self
            )
        } catch {
            fatalError("Failed to set up SwiftData: \(error)")
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
                    await store.onLaunch()
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
        if let id = debugSubArg(args) {
            NavigationStack { SubscriptionDetailView(subId: id) }
        } else if let id = debugDisputeArg(args) {
            DisputeLetterView(subId: id)
        } else if let id = debugNegotiateArg(args) {
            NavigationStack { NegotiateDetailView(subId: id) }
        } else if args.contains("--screen-paywall") {
            PaywallView()
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
