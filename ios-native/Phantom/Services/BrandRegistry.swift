import Foundation
import SwiftUI

/// Maps a subscription / merchant to its bundled brand SVG (in Resources/Brands/)
/// and its official brand color. SVG files come from simple-icons.org (CC0).
enum BrandRegistry {
    /// Returns `(svgFileName, hexColor)` for a known merchant, or nil if we should
    /// fall back to the letter avatar.
    static func brand(for subId: String, fallbackName: String) -> Brand? {
        // First try direct id match
        if let b = byId[subId.lowercased()] { return b }
        // Then try matching the human name against known patterns
        let n = fallbackName.lowercased()
        for (pattern, brand) in patternMatches {
            if n.contains(pattern) { return brand }
        }
        return nil
    }

    struct Brand: Equatable {
        let svgName: String        // file in Resources/Brands without .svg
        let hex: String            // official brand hex
        let backgroundHex: String? // optional contrasting background; nil → uses hex with 12% opacity
    }

    // Compact registry — keys MUST match the SVG filenames in Resources/Brands/
    static let byId: [String: Brand] = [
        "netflix":              Brand(svgName: "netflix", hex: "E50914", backgroundHex: "000000"),
        "hulu":                 Brand(svgName: "hulu", hex: "1CE783", backgroundHex: "0B0C0F"),
        "spotify":              Brand(svgName: "spotify", hex: "1DB954", backgroundHex: "191414"),
        "peacock":              Brand(svgName: "peacock", hex: "FA6400", backgroundHex: nil),
        "paramount":            Brand(svgName: "paramount", hex: "0064FF", backgroundHex: nil),
        "hbo-max":              Brand(svgName: "hbo-max", hex: "0046FF", backgroundHex: "000000"),
        "apple-tv":             Brand(svgName: "apple-tv", hex: "000000", backgroundHex: "FFFFFF"),
        "apple-music":          Brand(svgName: "apple-music", hex: "FA243C", backgroundHex: nil),
        "tidal":                Brand(svgName: "tidal", hex: "000000", backgroundHex: nil),
        "audible":              Brand(svgName: "audible", hex: "F8991C", backgroundHex: nil),
        "amazon-prime":         Brand(svgName: "amazon-prime", hex: "00A8E1", backgroundHex: nil),
        "walmart-plus":         Brand(svgName: "walmart-plus", hex: "0071CE", backgroundHex: nil),
        "icloud":               Brand(svgName: "icloud", hex: "3693F3", backgroundHex: nil),
        "google-one":           Brand(svgName: "google-one", hex: "4285F4", backgroundHex: nil),
        "dropbox":              Brand(svgName: "dropbox", hex: "0061FF", backgroundHex: nil),
        "adobe-cc":             Brand(svgName: "adobe-cc", hex: "FF0000", backgroundHex: "000000"),
        "adobe-photography":    Brand(svgName: "adobe-photography", hex: "FF0000", backgroundHex: nil),
        "github":               Brand(svgName: "github", hex: "181717", backgroundHex: nil),
        "github-copilot":       Brand(svgName: "github-copilot", hex: "181717", backgroundHex: nil),
        "chatgpt":              Brand(svgName: "openai", hex: "10A37F", backgroundHex: nil),
        "openai":               Brand(svgName: "openai", hex: "10A37F", backgroundHex: nil),
        "claude":               Brand(svgName: "claude", hex: "D97757", backgroundHex: nil),
        "anthropic":            Brand(svgName: "anthropic", hex: "191919", backgroundHex: nil),
        "gemini":               Brand(svgName: "gemini", hex: "4285F4", backgroundHex: nil),
        "perplexity":           Brand(svgName: "perplexity", hex: "20808D", backgroundHex: nil),
        "cursor":               Brand(svgName: "cursor", hex: "000000", backgroundHex: nil),
        "replit":               Brand(svgName: "replit", hex: "F26207", backgroundHex: nil),
        "vercel":               Brand(svgName: "vercel", hex: "000000", backgroundHex: nil),
        "v0":                   Brand(svgName: "v0", hex: "000000", backgroundHex: nil),
        "bolt":                 Brand(svgName: "bolt", hex: "000000", backgroundHex: nil),
        "lovable":              Brand(svgName: "lovable", hex: "EF4444", backgroundHex: nil),
        "linear":               Brand(svgName: "linear", hex: "5E6AD2", backgroundHex: nil),
        "suno":                 Brand(svgName: "suno", hex: "000000", backgroundHex: nil),
        "elevenlabs":           Brand(svgName: "elevenlabs", hex: "000000", backgroundHex: nil),
        "huggingface":          Brand(svgName: "huggingface", hex: "FFD21E", backgroundHex: "000000"),
        "deepseek":             Brand(svgName: "deepseek", hex: "4D6BFE", backgroundHex: nil),
        "notion":               Brand(svgName: "notion", hex: "000000", backgroundHex: "F4F4F5"),
        "duolingo":             Brand(svgName: "duolingo", hex: "58CC02", backgroundHex: nil),
        "lastpass":             Brand(svgName: "lastpass", hex: "D32D27", backgroundHex: nil),
        "1password":            Brand(svgName: "1password", hex: "3B66BC", backgroundHex: nil),
        "expressvpn":           Brand(svgName: "expressvpn", hex: "DA3940", backgroundHex: nil),
        "nordvpn":              Brand(svgName: "nordvpn", hex: "4687FF", backgroundHex: nil),
        "nyt":                  Brand(svgName: "nyt", hex: "000000", backgroundHex: "FFFFFF"),
        "peloton":              Brand(svgName: "peloton", hex: "DF1B2C", backgroundHex: nil),
        "headspace":            Brand(svgName: "headspace", hex: "F47D31", backgroundHex: nil),
        "youtube-premium":      Brand(svgName: "youtube-premium", hex: "FF0000", backgroundHex: "FFFFFF"),
        "youtube-tv":           Brand(svgName: "youtube-tv", hex: "FF0000", backgroundHex: "FFFFFF"),
        "paramount-plus":       Brand(svgName: "paramount", hex: "0064FF", backgroundHex: nil),
        // Mobility / delivery subscription tiers — the *Pass / *One / *Pink
        // memberships that ride on top of the ride/food apps.
        "uber-one":             Brand(svgName: "uber", hex: "000000", backgroundHex: nil),
        "lyft-pink":            Brand(svgName: "lyft", hex: "FF00BF", backgroundHex: nil),
        "dashpass":             Brand(svgName: "doordash", hex: "EB1700", backgroundHex: nil),
        // No-SVG subscription brands — recognized so looksLikeSubscription
        // returns true via the brand-match path. Avatar falls back to the
        // first-letter glyph on the brand-coloured background.
        "planet-fitness":       Brand(svgName: "planet-fitness-missing", hex: "5A1B5A", backgroundHex: nil),
        "equinox":              Brand(svgName: "equinox-missing", hex: "000000", backgroundHex: nil),
        "masterclass":          Brand(svgName: "masterclass-missing", hex: "C8102E", backgroundHex: nil),
        "wsj":                  Brand(svgName: "wsj-missing", hex: "000000", backgroundHex: nil),
        "washington-post":      Brand(svgName: "washington-post-missing", hex: "000000", backgroundHex: nil),
        "sirius-xm":            Brand(svgName: "sirius-missing", hex: "0033A0", backgroundHex: nil),
        "calm":                 Brand(svgName: "calm-missing", hex: "1A7DEF", backgroundHex: nil),
        "noom":                 Brand(svgName: "noom-missing", hex: "FF7E00", backgroundHex: nil),
        "disney-plus":          Brand(svgName: "disney-missing", hex: "113CCF", backgroundHex: "000000"),
    ]

    /// Fuzzy fallback — checks the human-readable name for these substrings.
    static let patternMatches: [(String, Brand)] = [
        ("netflix",        Brand(svgName: "netflix", hex: "E50914", backgroundHex: "000000")),
        ("hulu",           Brand(svgName: "hulu", hex: "1CE783", backgroundHex: "0B0C0F")),
        ("spotify",        Brand(svgName: "spotify", hex: "1DB954", backgroundHex: "191414")),
        ("disney+",        Brand(svgName: "youtube-premium", hex: "113CCF", backgroundHex: nil)), // no disney svg, repurpose
        ("peacock",        Brand(svgName: "peacock", hex: "FA6400", backgroundHex: nil)),
        ("paramount",      Brand(svgName: "paramount", hex: "0064FF", backgroundHex: nil)),
        ("hbo",            Brand(svgName: "hbo-max", hex: "0046FF", backgroundHex: "000000")),
        ("max ",           Brand(svgName: "hbo-max", hex: "0046FF", backgroundHex: "000000")),
        ("youtube tv",     Brand(svgName: "youtube-tv", hex: "FF0000", backgroundHex: "FFFFFF")),
        ("youtube",        Brand(svgName: "youtube-premium", hex: "FF0000", backgroundHex: "FFFFFF")),
        ("apple tv",       Brand(svgName: "apple-tv", hex: "000000", backgroundHex: "FFFFFF")),
        ("apple music",    Brand(svgName: "apple-music", hex: "FA243C", backgroundHex: nil)),
        ("icloud",         Brand(svgName: "icloud", hex: "3693F3", backgroundHex: nil)),
        ("amazon prime",   Brand(svgName: "amazon-prime", hex: "00A8E1", backgroundHex: nil)),
        ("audible",        Brand(svgName: "audible", hex: "F8991C", backgroundHex: nil)),
        ("sirius",         Brand(svgName: "audible", hex: "0033A0", backgroundHex: nil)), // no sirius svg, fallback
        ("adobe creative", Brand(svgName: "adobe-cc", hex: "FF0000", backgroundHex: "000000")),
        ("adobe",          Brand(svgName: "adobe-photography", hex: "FF0000", backgroundHex: nil)),
        ("microsoft",      Brand(svgName: "github", hex: "F25022", backgroundHex: nil)), // monochrome fallback
        ("github",         Brand(svgName: "github", hex: "181717", backgroundHex: nil)),
        ("chatgpt",        Brand(svgName: "openai",  hex: "10A37F", backgroundHex: nil)),
        ("openai",         Brand(svgName: "openai",  hex: "10A37F", backgroundHex: nil)),
        ("anthropic",      Brand(svgName: "anthropic", hex: "191919", backgroundHex: nil)),
        ("claude",         Brand(svgName: "claude",  hex: "D97757", backgroundHex: nil)),
        ("gemini",         Brand(svgName: "gemini",  hex: "4285F4", backgroundHex: nil)),
        ("perplexity",     Brand(svgName: "perplexity", hex: "20808D", backgroundHex: nil)),
        ("cursor",         Brand(svgName: "cursor",  hex: "000000", backgroundHex: nil)),
        ("replit",         Brand(svgName: "replit",  hex: "F26207", backgroundHex: nil)),
        ("v0.dev",         Brand(svgName: "v0",      hex: "000000", backgroundHex: nil)),
        ("vercel",         Brand(svgName: "vercel",  hex: "000000", backgroundHex: nil)),
        ("bolt.new",       Brand(svgName: "bolt",    hex: "000000", backgroundHex: nil)),
        ("stackblitz",     Brand(svgName: "bolt",    hex: "000000", backgroundHex: nil)),
        ("lovable",        Brand(svgName: "lovable", hex: "EF4444", backgroundHex: nil)),
        ("linear",         Brand(svgName: "linear",  hex: "5E6AD2", backgroundHex: nil)),
        ("midjourney",     Brand(svgName: "openai",  hex: "000000", backgroundHex: nil)),
        ("runway",         Brand(svgName: "openai",  hex: "000000", backgroundHex: nil)),
        ("suno",           Brand(svgName: "suno",    hex: "000000", backgroundHex: nil)),
        ("elevenlabs",     Brand(svgName: "elevenlabs", hex: "000000", backgroundHex: nil)),
        ("eleven labs",    Brand(svgName: "elevenlabs", hex: "000000", backgroundHex: nil)),
        ("huggingface",    Brand(svgName: "huggingface", hex: "FFD21E", backgroundHex: "000000")),
        ("hugging face",   Brand(svgName: "huggingface", hex: "FFD21E", backgroundHex: "000000")),
        ("deepseek",       Brand(svgName: "deepseek", hex: "4D6BFE", backgroundHex: nil)),
        ("mistral",        Brand(svgName: "anthropic", hex: "FF7000", backgroundHex: nil)),
        ("cohere",         Brand(svgName: "anthropic", hex: "39594D", backgroundHex: nil)),
        ("together ai",    Brand(svgName: "anthropic", hex: "0F6FFF", backgroundHex: nil)),
        ("groq",           Brand(svgName: "anthropic", hex: "F55036", backgroundHex: nil)),
        ("notion",         Brand(svgName: "notion", hex: "000000", backgroundHex: "F4F4F5")),
        ("dropbox",        Brand(svgName: "dropbox", hex: "0061FF", backgroundHex: nil)),
        ("duolingo",       Brand(svgName: "duolingo", hex: "58CC02", backgroundHex: nil)),
        ("lastpass",       Brand(svgName: "lastpass", hex: "D32D27", backgroundHex: nil)),
        ("1password",      Brand(svgName: "1password", hex: "3B66BC", backgroundHex: nil)),
        ("expressvpn",     Brand(svgName: "expressvpn", hex: "DA3940", backgroundHex: nil)),
        ("nordvpn",        Brand(svgName: "nordvpn", hex: "4687FF", backgroundHex: nil)),
        ("new york times", Brand(svgName: "nyt", hex: "000000", backgroundHex: "FFFFFF")),
        ("peloton",        Brand(svgName: "peloton", hex: "DF1B2C", backgroundHex: nil)),
        ("headspace",      Brand(svgName: "headspace", hex: "F47D31", backgroundHex: nil)),
        ("walmart",        Brand(svgName: "walmart-plus", hex: "0071CE", backgroundHex: nil)),
        ("uber one",       Brand(svgName: "uber", hex: "000000", backgroundHex: nil)),
        ("uber *one",      Brand(svgName: "uber", hex: "000000", backgroundHex: nil)),
        ("lyft pink",      Brand(svgName: "lyft", hex: "FF00BF", backgroundHex: nil)),
        ("lyft *pink",     Brand(svgName: "lyft", hex: "FF00BF", backgroundHex: nil)),
        ("dashpass",       Brand(svgName: "doordash", hex: "EB1700", backgroundHex: nil)),
    ]
}
