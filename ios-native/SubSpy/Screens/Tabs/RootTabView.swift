import SwiftUI

struct RootTabView: View {
    @Environment(AppStore.self) private var store

    private static func computeInitialTab() -> Int {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--tab-alerts") { return 1 }
        if args.contains("--tab-negotiate") { return 2 }
        if args.contains("--tab-settings") { return 3 }
        return 0
    }

    var body: some View {
        @Bindable var bindable = store
        return TabView(selection: $bindable.selectedTab) {
            NavigationStack { RadarView() }
                .tag(0)
                .tabItem { Label("Radar", systemImage: "dot.radiowaves.left.and.right") }
            NavigationStack { AlertsView() }
                .tag(1)
                .tabItem { Label("Alerts", systemImage: "bell") }
            NavigationStack { NegotiateView() }
                .tag(2)
                .tabItem { Label("Negotiate", systemImage: "bubble.left") }
            NavigationStack { SettingsView() }
                .tag(3)
                .tabItem { Label("Settings", systemImage: "person") }
        }
        .tint(Palette.ink)
        .onAppear {
            if store.selectedTab == 0 {
                store.selectedTab = Self.computeInitialTab()
            }
        }
    }
}
