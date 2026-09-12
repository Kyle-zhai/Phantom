import SwiftUI

struct RootTabView: View {
    @Environment(AppStore.self) private var store
    @State private var deepLink = DeepLink.shared
    @State private var showImport = false

    private static func computeInitialTab() -> Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--tab-alerts") { return 1 }
        if args.contains("--tab-negotiate") { return 2 }
        if args.contains("--tab-foryou") || args.contains("--tab-picks") { return 3 }
        if args.contains("--tab-settings") { return 4 }
        #endif
        return 0
    }

    var body: some View {
        @Bindable var bindable = store
        return TabView(selection: $bindable.selectedTab) {
            NavigationStack(path: $bindable.radarPath) { RadarView() }
                .tag(0)
                .tabItem { Label("Radar", systemImage: "dot.radiowaves.left.and.right") }
            NavigationStack { AlertsView() }
                .tag(1)
                .tabItem { Label("Alerts", systemImage: "bell") }
            NavigationStack { NegotiateView() }
                .tag(2)
                .tabItem { Label("Negotiate", systemImage: "bubble.left") }
            // The public Picks leaderboard (Screens/Picks) is parked; this
            // slot is the on-device "For you" recommendations page.
            NavigationStack { ForYouView() }
                .tag(3)
                .tabItem { Label("For you", systemImage: "sparkles") }
            NavigationStack { SettingsView() }
                .tag(4)
                .tabItem { Label("Settings", systemImage: "person") }
        }
        .tint(Palette.ink)
        .onAppear {
            if store.selectedTab == 0 {
                store.selectedTab = Self.computeInitialTab()
            }
            consumeDeepLink(deepLink.pendingSubId)
            consumeRadar(deepLink.pendingRadar)
            consumeImport(deepLink.pendingImport)
        }
        .onChange(of: deepLink.pendingSubId) { _, id in
            consumeDeepLink(id)
        }
        .onChange(of: deepLink.pendingRadar) { _, flag in
            consumeRadar(flag)
        }
        .onChange(of: deepLink.pendingImport) { _, flag in
            consumeImport(flag)
        }
        .sheet(isPresented: $showImport) {
            ImportScreenshotView().environment(store)
        }
    }

    private func consumeDeepLink(_ id: String?) {
        guard let id else { return }
        store.openSubscription(id)
        deepLink.pendingSubId = nil
    }

    private func consumeRadar(_ flag: Bool) {
        guard flag else { return }
        store.selectedTab = 0
        deepLink.pendingRadar = false
    }

    private func consumeImport(_ flag: Bool) {
        guard flag else { return }
        store.selectedTab = 0
        deepLink.pendingImport = false
        showImport = true
    }
}
