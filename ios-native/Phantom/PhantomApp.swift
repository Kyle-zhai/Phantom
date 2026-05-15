import SwiftUI
import SwiftData

@main
@MainActor
struct PhantomApp: App {
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
                    if Keychain.get(.plaidAccessToken) != nil {
                        await store.sync()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
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
        } else if args.contains("--screen-profile") {
            NavigationStack { OnboardingProfileView() }
        } else if args.contains("--screen-import") {
            ImportScreenshotView()
        } else if store.isOnboarded {
            RootTabView()
        } else {
            OnboardingWelcomeView()
        }
    }

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
}
