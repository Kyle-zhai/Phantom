import Foundation

enum AppConfig {
    /// Backend base URL. Read from Info.plist `SUBSPY_API_BASE`, fallback to localhost for dev.
    static var apiBase: URL {
        let raw = Bundle.main.object(forInfoDictionaryKey: "SUBSPY_API_BASE") as? String
        let s = (raw?.isEmpty == false ? raw : nil) ?? "http://localhost:3000"
        return URL(string: s) ?? URL(string: "http://localhost:3000")!
    }

    static var plaidEnvironment: String {
        (Bundle.main.object(forInfoDictionaryKey: "PLAID_ENVIRONMENT") as? String) ?? "sandbox"
    }

    /// Pro subscription product IDs for StoreKit 2
    static let proMonthlyProductId = "com.subspy.app.pro.monthly"
    static let proYearlyProductId  = "com.subspy.app.pro.yearly"

    /// Public catalog of subscription prices — hosted on GitHub Pages, no backend needed.
    /// Update by editing `docs/data/prices.json` and pushing to main.
    static var priceCatalogURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "PRICE_CATALOG_URL") as? String)
            ?? "https://kyle-zhai.github.io/SubSpy/data/prices.json"
    }
}
