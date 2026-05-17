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
}
