import Foundation

/// Direct cancellation links for each major subscription service.
/// URLs are kept up-to-date here — push a new app version to update,
/// or move to a JSON on GitHub Pages later for hot updates.
///
/// Sources verified by visiting each vendor's official help center.
enum CancellationRegistry {
    struct CancelPath {
        /// Universal opener: web URL, deep link, or phone.
        let url: URL
        /// Optional human-readable hint shown above the button (e.g. "Call to cancel — no online option").
        let hint: String?
        /// True if cancellation happens through Apple (iOS Settings → Subscriptions).
        let isAppleManaged: Bool
    }

    /// iOS Settings deep link to the user's App Store subscriptions.
    /// Apple intentionally has no public deep link to a specific subscription;
    /// this opens the full subscription list and is the App Store-approved pattern.
    static let appleSubscriptions = CancelPath(
        url: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!,
        hint: "This subscription is billed through Apple. Tap below to open iOS Subscriptions.",
        isAppleManaged: true
    )

    /// Phone-only services (Planet Fitness, some local gyms, cable, etc.)
    static func phoneOnly(_ number: String, note: String) -> CancelPath {
        let cleaned = number.filter { $0.isNumber }
        return CancelPath(
            url: URL(string: "tel://\(cleaned)")!,
            hint: note,
            isAppleManaged: false
        )
    }

    /// Map of subscription id (from BrandRegistry / MerchantNormalizer) → cancel path.
    /// IDs match the SVG filenames so they line up with logos.
    static let byId: [String: CancelPath] = [
        "netflix":           web("https://www.netflix.com/cancelplan"),
        "hulu":              web("https://www.hulu.com/account/cancel"),
        "spotify":           web("https://www.spotify.com/account/subscription/cancel/"),
        "peacock":           web("https://www.peacocktv.com/account/plans"),
        "paramount":         web("https://www.paramountplus.com/account/signin/"),
        "disney-plus":       web("https://www.disneyplus.com/account/subscription"),
        "hbo-max":           web("https://help.max.com/us/Answer/Detail/000001399"),
        "apple-tv":          appleSubscriptions,
        "apple-music":       appleSubscriptions,
        "icloud":            CancelPath(url: URL(string: "App-prefs:APPLE_ACCOUNT&path=ICLOUD_SERVICE")!, hint: "Manage iCloud+ in iOS Settings → Apple ID → iCloud.", isAppleManaged: true),
        "youtube-premium":   web("https://www.youtube.com/paid_memberships"),
        "youtube-tv":        web("https://tv.youtube.com/welcome"),
        "audible":           web("https://www.audible.com/account/cancel"),
        "amazon-prime":      web("https://www.amazon.com/gp/help/customer/display.html?nodeId=GVDLAJN6CGE76TJD"),
        "walmart-plus":      web("https://www.walmart.com/plus/cancel"),
        "tidal":             web("https://tidal.com/account/subscription"),
        "sirius-xm":         phoneOnly("1-866-635-2349", note: "SiriusXM requires a phone call to cancel. Retention agents often offer a deep discount before letting you go."),
        "google-one":        web("https://one.google.com/storage"),
        "dropbox":           web("https://www.dropbox.com/account/plan"),
        "adobe-cc":          web("https://account.adobe.com/plans"),
        "adobe-photography": web("https://account.adobe.com/plans"),
        "microsoft-365":     web("https://account.microsoft.com/services"),
        "github":            web("https://github.com/settings/billing"),
        "github-copilot":    web("https://github.com/settings/copilot"),
        "chatgpt":           web("https://chatgpt.com/#settings/Subscription"),
        "openai":            web("https://chatgpt.com/#settings/Subscription"),
        "claude":            web("https://claude.ai/settings/billing"),
        "anthropic":         web("https://claude.ai/settings/billing"),
        "gemini":            web("https://one.google.com/storage"),
        "perplexity":        web("https://www.perplexity.ai/settings/account"),
        "cursor":            web("https://www.cursor.com/settings"),
        "replit":            web("https://replit.com/account/plan"),
        "vercel":            web("https://vercel.com/account/plans"),
        "v0":                web("https://v0.dev/account/billing"),
        "bolt":              web("https://bolt.new/account/subscription"),
        "lovable":           web("https://lovable.dev/account/billing"),
        "linear":            web("https://linear.app/settings/billing"),
        "midjourney":        web("https://www.midjourney.com/account/"),
        "suno":              web("https://suno.com/me"),
        "elevenlabs":        web("https://elevenlabs.io/app/subscription"),
        "huggingface":       web("https://huggingface.co/settings/billing"),
        "deepseek":          web("https://platform.deepseek.com/usage"),
        "notion":            web("https://www.notion.so/my-account?tab=plans"),
        "duolingo":          web("https://www.duolingo.com/settings/super"),
        "masterclass":       web("https://www.masterclass.com/profile/plan"),
        "lastpass":          web("https://lastpass.com/?ac=1"),
        "1password":         web("https://start.1password.com/billing"),
        "expressvpn":        web("https://www.expressvpn.com/support/troubleshooting/cancel-subscription/"),
        "nordvpn":           web("https://my.nordaccount.com/plans/"),
        "nyt":               web("https://help.nytimes.com/hc/en-us/articles/115014892048-Cancel-your-subscription"),
        "wsj":               phoneOnly("1-800-369-2834", note: "WSJ requires a phone call. Reps often offer a 50%-off retention deal."),
        "washington-post":   web("https://subscribe.washingtonpost.com/account"),
        "planet-fitness":    phoneOnly("0", note: "Planet Fitness requires in-person cancellation at your home club OR a certified letter. No online or phone cancel."),
        "equinox":           phoneOnly("0", note: "Equinox requires a written cancellation request at your home club, 45 days notice."),
        "peloton":           web("https://onepeloton.com/digital/help/cancel-membership"),
        "headspace":         web("https://www.headspace.com/account"),
        "calm":              web("https://help.calm.com/hc/en-us/articles/115002473248-Cancel-Subscription"),
        "noom":              web("https://www.noom.com/support/"),
    ]

    private static func web(_ s: String) -> CancelPath {
        CancelPath(url: URL(string: s)!, hint: nil, isAppleManaged: false)
    }

    /// Resolve a cancel path for a given subscription. Falls back to a Google
    /// search for "cancel <vendor>" when unknown.
    static func path(forSubscriptionId id: String, fallbackName: String) -> CancelPath {
        if let known = byId[id.lowercased()] { return known }
        // Try matching on the normalized name (helps when id was auto-generated)
        let normalized = MerchantNormalizer.brandId(forNormalized: fallbackName)
        if let known = byId[normalized] { return known }
        // Fallback: Google search
        let query = "cancel \(fallbackName) subscription"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "cancel"
        return CancelPath(
            url: URL(string: "https://www.google.com/search?q=\(query)")!,
            hint: "We don't have a verified cancel link for this service yet. Search opens in Safari.",
            isAppleManaged: false
        )
    }
}
