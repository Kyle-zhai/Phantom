import Foundation

enum AppConfig {
    /// Pro subscription product IDs for StoreKit 2
    static let proMonthlyProductId = "com.yinanzhai.phantom.pro.monthly"
    static let proYearlyProductId  = "com.yinanzhai.phantom.pro.yearly"

    /// Public catalog of subscription prices — hosted on GitHub Pages, no backend needed.
    /// Update by editing `docs/data/prices.json` and pushing to main.
    static var priceCatalogURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "PRICE_CATALOG_URL") as? String)
            ?? "https://kyle-zhai.github.io/Phantom/data/prices.json"
    }

    /// Hand-curated tiers / alternatives / bundle-inclusion catalog. A copy
    /// ships in the bundle (`Resources/alternatives.json`); this remote file
    /// lets prices be corrected without a release. Edit `docs/data/alternatives.json`.
    static var alternativesCatalogURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "ALTERNATIVES_CATALOG_URL") as? String)
            ?? "https://kyle-zhai.github.io/Phantom/data/alternatives.json"
    }

    /// iCloud container for the private SwiftData sync AND the public
    /// "Picks" leaderboard. Must be enabled on the App ID (iCloud › CloudKit)
    /// in the Apple Developer portal and its schema deployed to Production
    /// before release — see docs/CLOUDKIT_SETUP.md.
    static let cloudKitContainerID = "iCloud.com.yinanzhai.phantom"

    /// Public legal pages. Guideline 3.1.2 requires a functional Terms of Use
    /// (EULA) link in App Store metadata *and* in the binary for auto-renewing
    /// subscriptions. Apple's standard EULA is used unless a custom one is
    /// uploaded in App Store Connect.
    static let websiteURL = URL(string: "https://kyle-zhai.github.io/Phantom/")!
    static let privacyPolicyURL = URL(string: "https://kyle-zhai.github.io/Phantom/privacy.html")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let supportEmailURL = URL(string: "mailto:yn.zhai0205@gmail.com")!
}
