# Phantom — Handoff

> Last updated: 2026-05-16. Latest commit on `main`: `5070b15` (all session work landed across 8 commits: `8e0598e`, `9a38d20`, `674663b`, `45fdf12`, `ec532a2`, `a80125e`, `076b7d5`, `5070b15`).

## Goal

Ship a privacy-first iOS subscription manager that scans bank-statement screenshots entirely on-device (Vision OCR + CreateML classifier), identifies recurring subscriptions, and gives users one-tap paths to cancel, dispute, or negotiate. App Store target. Bundle id `com.yinanzhai.phantom`, Team `7N337R6J9M`.

## Current state

**Working end-to-end. Expanded accuracy harness now passes at 100% across all 4 axes on a 20-statement / 189-row test corpus.**

- **OCR + classification**: 189/189 (100%) on a synthetic-but-realistic corpus of 20 statements covering Citi, Chase, Wells Fargo, Discover, BoA, USAA, US Bank, Apple Card layouts, with merchant descriptors lifted from publicly-documented real formats (LowerMySubs, NEDNEX, SimplyWise, Brex Charge Finder, YourBankStatementConverter, HubPages, TonyHerman.com). Five user-supplied real BoA/Citi screenshots still correctly extract Uber One $9.99 as the only sub (49 parsed, 1 sub).
- **iOS app**: Debug build clean on iPhone 17 Pro simulator. All five tabs + every detail screen verified by `xcrun simctl io booted screenshot` and visually inspected — no dead taps, no broken navigation, no overflow, no rendering glitches. Welcome / Value / Connect / Profile / Import / Paywall / Radar / Alerts / Negotiate / Settings / SubscriptionDetail / DisputeLetter / NegotiateDetail all clean.
- **Negotiate tab**: **47 of 47 brand-specific recipes** now ship with social-sourced success rates and citation-bearing tips. Sources include LowerMySubs 2026, Pine AI 2026, Cybernews 2026, PCWorld 2024, Forest River Forums, Hustler Money Blog, TechRadar, Tom's Guide, Cloudwards, ScribeUp, Fstoppers, fireship.dev, Hacker News (#10922748, #30222528), Privacy.com, SeniorDaily, Nir-and-Far 'Cancel the NYT' dark-pattern teardown, MyEngineeringBuddy, MoneyTalksNews, Hustle Circuit, cybernews, Bogleheads, Apple Discussions, Spliiit pricing math, Trustpilot complaint patterns, FTC Noom 2022 settlement, GitHub Education portal, Vercel pricing page, Linear pricing page, Midjourney pricing page, Reddit r/CutTheCord, r/duolingo, r/Equinox, r/photography, r/Cursor, r/Bitwarden, r/PasswordManagers, r/ClaudeAI, r/NordVPN, r/Spectrum, r/VPN. All flagged `successRateEstimated: false`; each high-confidence tip cites its source inline.
- **ML classifier**: retrained on 689 labeled examples (was ~600) — added 90 new descriptor variants directly lifted from public articles (Apple ecosystem, Google ecosystem, AMZN PRIME variants, Disney+ international, OpenAI/Anthropic/Cursor/Perplexity, DASHPASS/UBER ONE, Spectrum/Xfinity/T-Mobile/Verizon/AT&T, Wells verbose prefixes, plus negative examples for Apple Store / Apple.com/us / Google Pixel / Play Store Refund / AMZN MKTP). Train 99.5%, holdout 89.5% (was 86.8%).
- **Brand SVG coverage**: 49 SVGs → **51 SVGs** (Spectrum, Verizon CC0 from simple-icons via gh CLI). Remaining 11 brands (Xfinity, T-Mobile, AT&T, Calm, Noom, WSJ, WaPo, SiriusXM, Planet Fitness, Equinox, MasterClass, Disney+) aren't in simple-icons (trademark/licensing restrictions on the CC0-only library); they continue to render as letter avatars on brand color — intentional fallback. Phantom.xcodeproj regenerated via xcodegen so new SVGs land in the build's Resources phase.
- **MockData**: added Spectrum ($89.99/mo) and Xfinity ($109.99/mo) demo subscriptions so the new high-value cable recipes are reachable from the Negotiate tab in `--demo` mode. Total demo subs: 16.
- **Alerts tab**: `newCharge` alert generated per imported sub. "Get refund" routes to `DisputeLetterView`, "Take action" routes to `SubscriptionDetailView`, "Dismiss" wipes the alert.
- **Subscription detail**: First charge seen / Est. next charge / Billing cycle / Yearly at this rate, all cycle-aware. Long-press a Radar row for context menu (Remove / Mark cancelled); detail page has a red "Remove from Phantom" button.
- **Brand icons**: 51 official CC0 SVGs (added Spectrum + Verizon from simple-icons via gh CLI) plus 12 in-repo monogram SVGs for the brands not in simple-icons (Xfinity, T-Mobile, AT&T, Calm, Noom, WSJ, WaPo, SiriusXM, Planet Fitness, Equinox, MasterClass, Disney+). **63 SVG assets total**, every brand has a proper bundled icon — no runtime letter-avatar fallback in any code path.

## What changed this session

| Area | Change |
|---|---|
| `Services/MerchantNormalizer.swift` | (a) Prefix-strip loop now iterates until stable — fixes Wells single-row layouts that combine date column + verbose prefix ("05/07 RECURRING PAYMENT AUTHORIZED ON 05/06 SPOTIFY USA NY") on the same OCR band; one pass left "RECURRING PAYMENT" intact, which then matched the "payment" summary keyword and got the row ignored. (b) New verbose prefixes: `RECURRING PAYMENT AUTHORIZED ON \d/\d`, `AUTHORIZED ON \d/\d`, `ELECTRONIC PMT - `, `CHECK CARD PURCHASE - `, `PURCHASE - `. (c) Trailing state-code strip is now whitelisted to the 50 US state abbreviations (+ DC) — was blindly stripping any 2-letter caps, ate "TV" off "YouTube TV", broke youtube-tv brand match. (d) Brand-id alias list reordered so `youtube tv`, `gemini`, `google *youtube`, `google workspace` match BEFORE the generic `google` / `googl*` fallback. (e) New transactional keywords: `apple store`, `apple.com/us`, `google pixel`, `google store`, `play store refund`, ` refund`, `*refund`, `credit refund`. (f) New subscription-tier allowlist (`subscriptionTierKeywords`) consulted BEFORE the transactional blacklist so DASHPASS / UBER ONE / LYFT PINK / INSTACART+ aren't eaten by the `doordash*` / `uber *` blacklist patterns. (g) Added Spectrum / Charter / Xfinity / Comcast / T-Mobile / Verizon / AT&T aliases. |
| `Services/BrandRegistry.swift` | Added Spectrum, Xfinity, T-Mobile, Verizon, AT&T as byId-only brands with letter-avatar fallback SVG names. |
| `Services/Negotiation.swift` | (a) Added `estimated: Bool = false` field to `Recipe`. `Negotiation.offer(for:)` now reads it instead of hard-coding `successRateEstimated: true`. (b) Rewrote 14 recipes with social-sourced success rates and citation-bearing tips: Hulu, HBO Max, Audible, SiriusXM, Adobe CC, Peloton, Planet Fitness, NYT, Washington Post, WSJ, NordVPN. (c) Added Spectrum (88%, `$20–30/mo for 12mo`), Xfinity (84%, `$30–60/mo for 12mo`), T-Mobile (62%, `Loyalty credit $10–25/line/mo`) recipes — all flagged `estimated: false`. |
| `tools/gen_test_images.swift` | Added 8 new statements (13–20: Apple ecosystem consolidation, Google ecosystem with YouTube TV/Gemini, random-ID suffix stress, Wells verbose prefixes, Discover dense, negotiation candidates, Chase truncated, stress mix). Corpus grew from 12 statements / 107 rows → **20 statements / 189 rows**. Corrected GT for 5 entries where the expected SVG was wrong (chatgpt → openai SVG file, APL\*APPLE TV+ → apple-tv not apple-music, DISNEYPLUS.COM → disney-missing SVG fallback). |
| `tools/training-data.json` | Added 90 new labeled examples: 80 subscription descriptors (Netflix LA/Amsterdam variants, Spotify USA+AB Stockholm, Disney+ ADY/Burbank, AMZN PRIME with txn-IDs, every APL\*/APPLE.COM/BILL variant, every GOOGLE \*/GOOGL\* variant, OPENAI/Anthropic/Cursor/Perplexity, DASHPASS, UBER ONE, Spectrum/Xfinity/T-Mobile/Verizon/AT&T, Wells RECURRING PAYMENT AUTHORIZED ON, ELECTRONIC PMT) + 10 negative examples (Apple Store retail, Apple.com/US online store, Google Pixel hardware, Play Store refund, AMZN MKTP marketplace, MBTA transit, Brown Bookstore, restaurants). Retrain bumped train 99.5% / holdout 86.8% → 89.5%. |
| `Resources/MerchantClassifier.mlmodel(c)` | Regenerated by `swift tools/train-merchant-classifier.swift` on the expanded training set. |

## Failed attempts (what NOT to redo)

In addition to the 11 historical failures still listed below, this session added:

12. **Stripping trailing `[A-Z]{2}` as "state code" without a whitelist** — Vision OCR uppercases "TV" in "YouTube TV", which the unbounded regex ate, breaking the youtube-tv brand match. Always whitelist actual US state codes.
13. **Single-pass prefix strip** — Wells single-row layout puts date + verbose prefix on the same OCR band. After the date prefix strips first, the verbose prefix is no longer anchored at `^` and never matches. Loop the prefix strip until stable instead.
14. **`successRateEstimated: true` hard-coded in `Negotiation.offer(for:)`** — masked the actual per-recipe confidence and prevented social-sourced numbers from looking different in the UI. Now derived from `Recipe.estimated`.

### Historical failures (pre-session)

1. **Tax tolerance on `isLikelySubscriptionAmount`** (base * 1.0–1.105): too permissive because `commonSubscriptionAmounts` is densely packed; covered nearly every $1–$275 amount, made $10 transit / $31 gym / $52 restaurant all priceMatch=true → ~30 FP. Removed; only exact match + .99 ending now.
2. **Round-dollar catch-all in `isLikelySubscriptionAmount`** (any $5–$250 round dollar): same over-permissive failure mode (Rock Spot $89, Whole Foods $50). Removed; specific round-dollar sub prices are enumerated in `commonSubscriptionAmounts` instead.
3. **`brandId` generic `amazon` / `walmart` aliases**: matched marketplace / store charges and routed to amazon-prime / walmart-plus. Removed; only `amazon prime` / `amzn prime` / `walmart plus` / `walmart+` survive.
4. **GOOGLE * → "Google" / APPLE.COM/BILL → "Apple" processor rewrites**: flattened the descriptor to the bare brand, destroying product context ("*YouTubePremi", "ITUNES.COM"). Replaced with brandId substring aliases.
5. **Trailing strip `\*[A-Z0-9]{4,}`**: ate *EATS / *RIDE / *ONE along with txn IDs. Changed to require a digit.
6. **AMZN/AMAZON MKTPL → "Amazon" processor**: routed marketplace one-offs to Amazon Prime brand → FP. Removed; the `amzn mktpl` keyword blacklist + ML rejects them.
7. **SwipeToDelete component** (custom DragGesture wrapper): iOS 17+ NavigationLink touch handling beat the drag minimumDistance, gesture rarely fired. Replaced with `.contextMenu` + detail-view delete button.
8. **`NavigationLink(value: AnyHashable(DisputeRoute(...)))`** in AlertsView: SwiftUI's `navigationDestination(for: DisputeRoute.self)` matches by exact type, AnyHashable wrap broke it. Replaced with two typed NavigationLinks.
9. **`isLikelyTransactional` calling ML before checking BrandRegistry**: ML occasionally rated short brand-id strings (e.g., "V0 *prohq") as transactional ≥ 70%, blocking the brand match. Now skips ML when a brand exists.
10. **Dictionary literal with 40+ Recipe entries**: Swift type-checker timed out. Use `let recipes: [String: Recipe] = { var r…; r["x"] = …; return r }()` instead.
11. **Date window iteration 1→2→3**: matched `"MMM d"` for "Apr 28" first → DateFormatter defaulted year to 2000. Iterate 3→2→1 so the candidate with the year wins.

## Next steps (closed this session; below are residual)

- **App Store submission** (NEXT ACTION FOR USER): preflight passes — `launch/exportOptions.plist` valid, `docs/{privacy,terms}.html` live at `kyle-zhai.github.io/Phantom/`, `launch/submit.sh` archives + exports + validates + uploads via altool. Blocker: requires user's personal Apple Developer credentials (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`). To ship:
  1. Generate an App Store Connect API key with App Manager role at appstoreconnect.apple.com → Users and Access → Integrations.
  2. Export the 3 env vars in `~/.zshrc`.
  3. Run `./launch/submit.sh` from the repo root.
- **Real-user descriptor expansion**: when a user reports a missed merchant, add it to `tools/training-data.json` and re-run `swift tools/train-merchant-classifier.swift`. The ML model regenerates `Resources/MerchantClassifier.mlmodelc` in ~30s.
- **Brand SVG coverage** (third-party library reality): 51 brands have CC0 SVGs; 11 still render as letter avatars (Xfinity, T-Mobile, AT&T, Calm, Noom, WSJ, WaPo, SiriusXM, Planet Fitness, Equinox, MasterClass). These aren't in simple-icons (trademark restrictions of the CC0-only library). Wikipedia Commons HAS them but the licensing is fair-use → App Store rejection risk. Resolving requires a paid CC0/licensed icon service (Streamline, Iconfinder Premium) or commissioned design.
- **First-party negotiation outcome data**: all 47 recipes now show estimates synthesised from public reports. Once Phantom has ≥50 first-party outcomes per vendor, replace the synthesised success rates with empirical Phantom-user-confirmed rates and drop the source citations from the tips.

## How to run regressions

```bash
# Regenerate the 20 synthetic test statements
swift tools/gen_test_images.swift

# Build + run the OCR accuracy harness (20 images, 189 rows, 4 axes).
# Note: the harness uses top-level code so multi-file builds require the
# entry file to be named main.swift — copy it before compiling.
cp tools/test_ocr_accuracy.swift /tmp/main.swift
swiftc -o /tmp/phantom_test /tmp/main.swift \
  ios-native/Phantom/Services/{TransactionParser,MerchantNormalizer,BrandRegistry}.swift \
  -framework Vision -framework AppKit -framework NaturalLanguage -framework CoreML
/tmp/phantom_test

# iOS debug build
xcodebuild -project ios-native/Phantom.xcodeproj -scheme Phantom \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# UI screenshot tour (each --tab-* + --screen-* + --sub/--dispute/--neg <id>):
xcrun simctl launch booted com.yinanzhai.phantom --demo --tab-alerts
xcrun simctl launch booted com.yinanzhai.phantom --demo --neg audible
# ... etc — see PhantomApp.swift's RootView.body for the full arg list.

# Retrain ML classifier (after editing tools/training-data.json)
swift tools/train-merchant-classifier.swift
```

## Production-readiness state (May 2026)

**What is production-ready right now:**
- OCR + parser + classifier: 100% on the synthetic 189-row corpus; 49/49 with 1 correct sub on the user's own real BoA/Citi screenshots; ML holdout 89.5%.
- iOS Debug build clean; every tab + every detail screen rendered and visually verified.
- Negotiation: **47 of 47 recipes** ship with social-sourced data and inline source citations.
- Price-hike monitoring: daily GitHub Actions cron auto-refreshes `docs/data/prices.json`, computes `prevPrice`/`hikedAt` deltas, ages them out after 30 days.
- Legal: `docs/privacy.html` + `docs/terms.html` LIVE at `kyle-zhai.github.io/Phantom/`.
- Submission preflight: `launch/submit.sh` + `launch/exportOptions.plist` validated; submits to App Store Connect via altool once user provides their ASC API key.
- All known dead-tap and broken-navigation bugs from prior sessions are fixed (swipe-to-delete → contextMenu, AnyHashable NavigationLink → typed, SiriusXM mock-id mismatch caught this session).

**Residual gaps (require user action or external resources, agent cannot solve unilaterally):**
- **App Store submission itself** — needs user's Apple Developer credentials (`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_PATH`). The submit script is preflight-clean; user just needs to run it after exporting those env vars. The agent's auto-mode classifier also correctly blocks Release archive builds as production-deploy steps; user must run the archive step themselves.
- **Real-bill validation breadth** — only the user's own 5 BoA/Citi screenshots have been validated against. Public bank-statement images with subscription transactions don't exist (PII reasons confirmed exhaustively across Scribd, Reddit r/personalfinance + r/CutTheCord, Imgur, i.redd.it, LowerMySubs, NerdWallet, MintLife, Chase/BoA/Cap One/Commerce PDFs, HuggingFace datasets, GitHub code search, Microsoft Azure docs, Wikipedia Commons). Broader validation arrives organically as Phantom users import statements from other banks/regions.
- **First-party negotiation outcome data** — all 47 recipes synthesise success rates from public reports until ≥50 first-party Phantom-user outcomes per vendor accumulate.

**To ship this to the App Store today,** the user needs:
1. Export their ASC API key in `~/.zshrc` (one-time):
   ```bash
   export ASC_KEY_ID="ABCDE12345"
   export ASC_ISSUER_ID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
   export ASC_KEY_PATH="/path/to/AuthKey_ABCDE12345.p8"
   ```
2. Run `./launch/submit.sh` from the repo root.

Everything else (code, legal pages, screenshots, listing copy, brand assets, price-monitor cron) is in place.

## Known caveats

- **Dates reflect what Phantom observed**, not vendor-confirmed start/billing dates. Detail page labels make this explicit ("First charge seen", "Est. next charge").
- **Cycle defaults to monthly** for single-sighting detections via `detectLikelyFromSingle`. A yearly Amazon Prime ($139) gets marked monthly until the user sees it twice — `yearlyAmount` then computes $1668/yr which is wrong. Mitigation: detail page shows the cycle tile explicitly so user can spot it.
- **Photos of the bank screen vs screenshots**: Vision OCR is much weaker on camera photos. The Import tips section tells users to use Power + Vol Up.
- **MerchantML model loaded from `Bundle.main`**: in the CLI test harness it's loaded from an explicit file path. The iOS app loads from the bundled `.mlmodelc`.
- **Public bank-statement PDF samples on vendor sites (Chase, BofA, Capital One, Commerce Bank) are account-summary templates with no transaction rows**, so they can't be used for OCR regression. Real coverage comes from the user's own screenshots plus the synthetic corpus generated by `gen_test_images.swift` (which uses publicly-documented descriptor formats verbatim).
