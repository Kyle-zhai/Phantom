# Phantom — Project Context for Claude Code

> A subscription-management iOS app that surfaces "zombie subscriptions," walks users through cancel with on-device proof, generates EFTA-compliant dispute letters and chargeback packets, warns about price hikes, and helps users negotiate retention discounts. PRD at `Phantom_PRD.md`. Shipping on the App Store; UI inspired by Uber (black-and-white, large type, generous spacing).

## 0. WHICH CODEBASE IS REAL (read this first)

- **`ios-native/` — the SHIPPED native iOS app. This is the source of truth.** SwiftUI + SwiftData, fully on-device, no backend. All work happens here.
- The old Expo/React-Native prototype and Plaid/Express backend were moved to `.archive/legacy-expo/` on 2026-07-04. Not shipped, not built. Ignore unless doing history archaeology.

When the user says "the app," they mean `ios-native/`.

## 1. Product (one-liner per surface)

| Surface | Job-to-be-done |
|---|---|
| Onboarding | Sell the clawback, then import (Apple subscriptions first, or statement screenshot / CSV — **no bank login**) |
| Radar (Home) | Monthly + yearly spend, biggest savings opportunity, every subscription sorted by zombie score |
| Detail | Explain *why* a sub is a zombie; cancel checklist / negotiate / dispute |
| Cancel flow | Verified vendor path + on-device evidence locker (confirmation #, screenshot) |
| Dispute Letter | Generate an EFTA/ROSCA-compliant letter; then a card-issuer chargeback packet if they ignore it |
| Alerts | Price hikes, trial ends, new charges |
| Negotiate | Per-vendor retention scripts (47 vendors); "cancel instead" jumps to the cancel page |
| Settings / Pro | Plan tiers, real notification toggles, three-no privacy promise, account |

## 2. Tech stack (native app)

- **Swift 5.10 / SwiftUI**, iOS 17+, iPhone-only (`TARGETED_DEVICE_FAMILY = 1`)
- **SwiftData** for local persistence (`Models/Persistent.swift`); view-layer structs in `Models/Models.swift`
- **`@Observable AppStore`** (`Store/AppStore.swift`) is the single source of truth (no Redux/zustand)
- **Vision** on-device OCR + a **CoreML** merchant classifier to detect subscriptions from screenshots
- **StoreKit 2** for Pro IAP; **UserNotifications** for local alerts; **WidgetKit** for the home/lock-screen widget
- **SVGView** (SPM) for brand logos
- **No Phantom backend, no Plaid.** Processing runs on-device. Price/alternatives catalogs are static JSON fetched from GitHub Pages. Since 2026-09-10 the SwiftData store syncs to the user's **private iCloud** (CloudKit, `.automatic`), identity is **Sign in with Apple** — setup in `docs/CLOUDKIT_SETUP.md`. (The Picks leaderboard on the CloudKit **public** database is parked since 2026-09-11: code kept, tab removed.)
- **xcodegen** generates the Xcode project from `ios-native/project.yml` — edit the YAML, not the `.xcodeproj`.

## 3. Repo layout (`ios-native/Phantom/`)

```
PhantomApp.swift            # @main App + AppDelegate (notification delegate) + DeepLink holder
Models/                     # Models.swift (view structs), Persistent.swift (SwiftData)
Store/AppStore.swift        # @Observable hub: state, scoring, notifications, cancellation, widget snapshot
Services/
  OCR.swift                 # Vision text recognition
  TransactionParser.swift   # OCR lines → transactions
  MerchantNormalizer.swift  # clean merchant text → brandId
  MerchantML.swift          # CoreML subscription classifier
  RecurrenceDetector.swift  # cycle inference (weekly…yearly, tolerant of a missed charge), on-statement hikes, one sub per Apple/Google amount
  TransactionLedger.swift   # on-device JSON ledger of every imported charge — makes cross-month confirmation real
  AppleSubscriptionsParser.swift # Settings › Subscriptions screenshot → named, Apple-billed subs (there is NO API for this)
  AppleReconciler.swift     # folds "APPLE.COM/BILL $19.99" (apple-services-1999c) into the Apple-list "Netflix $19.99" — never both
  AccountService.swift      # Sign in with Apple identity (Keychain, synchronizable) + iCloud account status; CloudSyncState
  PrefsSync.swift           # mirrors tracked UserDefaults keys into PersistentSetting rows so they sync
  Dedupe.swift              # CloudKit has no unique constraints — collapse duplicate rows on load
  KeychainStore.swift       # tiny SecItem wrapper
  PicksService.swift        # CloudKit public DB: leaderboard, submissions, one-open-per-day counting, reports (PARKED 2026-09-11)
  BrandRegistry.swift       # logos + brand colors + Kind (36 verticals) + display names; Category derives from Kind
  Overlaps.swift            # same-Kind overlap (pure; the store delegates to it)
  ZombieScore.swift         # 0–100 score with ScoreContext (coverage, cheapest tier, kind median) — see §5
  AlternativesCatalog.swift # tiers / pause / edge-tagged alternatives / bundle inclusions / suggestion rules (bundled + remote JSON)
  Recommender.swift         # For you: needs by Kind → like-for-like replacements (free→cheaper→bundle→better) + rule-based "you might also need"
  BundleCoverage.swift      # "you already pay for this": owned/inferred bundles × active subs → CoverageHit
  DisputeLetter.swift       # EFTA/ROSCA letter generator
  ChargebackPacket.swift    # card-issuer chargeback script
  StatementCSV.swift        # bank CSV → ParsedTransaction
  EvidenceLocker.swift      # on-device cancel proof
  IncomingInbox.swift       # App Group drop-box from the share extension
  Negotiation.swift         # 47 vendor retention scripts
  CancellationRegistry.swift# verified direct cancel URLs (60+) + Apple/phone paths
  PriceMonitor.swift        # fetch prices.json, detect hikes
  NotificationCenter.swift  # local notification scheduling (trial/hike/zombie/cancel-check/rescan/dispute-follow)
  SharedStore.swift         # App Group bridge — snapshot the widget reads
  PurchaseService.swift / Entitlements.swift  # StoreKit + free/Pro gating
  MockData.swift            # opt-in sample data (demo mode only)
Screens/                    # Onboarding/ (Welcome → Value → SignIn → Connect), Tabs/ (Radar/Alerts/Negotiate/ForYou/Settings), ForYouView, Picks/ (PicksView, PickDetailView, SubmitPickView — parked; Debug-only via `--screen-picks`), Detail, Dispute, Chargeback, CancelFlow, Import, Paywall, AppleSubscriptionsGuideView, OwnedBundlesView
Resources/alternatives.json # bundled copy of the catalog (services w/ tiers, pause, edge-tagged alternatives; bundles; suggestion rules); remote copy at docs/data/alternatives.json (+ alternatives-sources.json)
Components/                 # Button, Card, Badge, ZombieMeter, SavingsShareCard, …
Theme/Theme.swift           # Palette / Radius / Space / AppFont tokens + fmtUSD
../PhantomWidget/           # WidgetKit extension (separate target)
```

## 4. Design language — "Uber-clean" (tokens in `Theme/Theme.swift`)

- **Palette**: `Palette.ink` `#0A0A0A`, `black`, `white`, `mute` `#6B7280`, `surface` `#F4F4F5`, `border` `#E5E7EB`, `success` `#10B981`, `danger` `#EF4444`, `warn` `#F59E0B` (+ soft variants).
- **Type** (`AppFont`): SF system; display 44/heavy, h1 32, h2 24, h3 18, body 16, small 13, micro 11. Headlines oversized and tight.
- **Spacing** (`Space`): 4-pt base (8/12/16/24/32). Cards 20pt inner padding.
- **Radius** (`Radius`): `md` 16 cards, `pill` 999, `xl` 28 primary CTAs.
- **Buttons** (`PrimaryButton`): primary = black fill/white text, 56 tall, full-bleed; secondary = white + 1px border; also `ghost`, `danger`, `light`. Light-impact haptic on tap.

## 5. Zombie score (PRD §3.2 → `Services/ZombieScore.swift`)

`ZombieScore.compute(sub, context:) → ScoreBreakdown` (0–100 + per-factor values + the effective weights, which the detail view renders). Two regimes:

**Usage known** (demo/mock data; real usage never exists on-device) — PRD §3.2 weights, unchanged:

```
recencyOfLastUse 35%   usageVsPrice 25%   overlap 20%   userRating 15%   priceVsMarket 5%
```

**Usage unknown** (every real import) — renormalized over the signals we actually have. Rewritten 2026-09-10:

```
overlap   25%  always      same-Kind duplicates (Netflix+Hulu yes, Netflix+Spotify no); a bundle that includes the sub counts as one duplicate
coverage  30%  if covered  included 100 / card credit 70 / carrier perk 40 (ScoreContext.coverage from BundleCoverage)
rating    35%  always      1★ → 100 … 5★ → 0; neutral 50 when unrated (so a lone unrated import stays "keep")
price     10%  if signal   gap to the same service's cheapest feature tier (Netflix Premium vs ads tier); else legacy marketAverage; else Kind median
hike       5%  if signal   a hike effective within −180…+30 days: +10% → 40, +25% → 100 (from catalog or seen on the statement)
```

Score ≥ 80 → zombie. 50–79 → review. <50 → keep. Calibration pinned by `ZombieScoreTests`: lone unrated → keep; two duplicates → review; duplicates + 1★ → zombie; 1★ alone → review; covered by an owned bundle → review; covered + 1★ → zombie; 5★ stays keep even with duplicates; overpaying alone is never a zombie (it's a "keep it for less" tip).

`AppStore.scoreContext(for:)` supplies coverage + catalog prices; `Overlaps.compute` recomputes `hasOverlapWith` by `Kind` on every import/launch (`Kind.participatesInOverlap` excludes telecom and platform-billed). Users set `userRating` via the star control in `SubscriptionDetailView`.

## 6. Notifications, cancellation, widget (added 2026-05-28 — how they work)

- **Notifications are live.** Permission is requested at the highest-intent moment (right after the first import) and from Settings → Notifications. `AppStore.rescheduleAllNotifications()` is the single scheduler; it honors the per-category toggles (`notifyHikes/notifyTrials/notifyZombies`) and only schedules when authorized. `PhantomApp.task` calls `store.onLaunch()` on every cold start (previously gated behind a Plaid token that never existed, so nothing ever fired). Taps route via `AppDelegate` → `DeepLink.shared` → `AppStore.openSubscription` → Radar nav path.
- **Cancellation concierge.** Detail view's "Cancel" opens a checklist (`CancelFlowView`) against the verified `CancellationRegistry` URL (web/`tel:`/iOS Subscriptions). After the vendor flow, the user saves a confirmation number / screenshot in the on-device evidence locker. Confirming calls `AppStore.confirmCancellation` which marks cancelled AND schedules a ~35-day verification reminder (`cancelcheck-…`) to re-scan the next statement. Copy is honest — Phantom can't cancel on the user's behalf.
- **Chargeback packet.** After a dispute letter is sent, `ChargebackGuideView` gives a Regulation E/Z script for the card issuer plus CFPB/FTC links. A 14-day `disputefollow-…` notification asks whether the refund landed.
- **Re-scan reminder.** 28 days after the last screenshot/CSV import (`rescan`), plus an in-Radar banner after 21 days. Share Sheet / Open-in land in `IncomingInbox` (App Group) and open `phantom://import`.
- **Savings share card** (`Components/SavingsShareCard.swift`): `ShareLink` of an `ImageRenderer`-rendered card. `.found` (potential) on Radar, `.saved` (realized) after a cancel. The app's only growth loop — keep it.
- **"Already covered" + "Keep it for less"** (added 2026-09-10). `AlternativesCatalog` (bundled `Resources/alternatives.json`, refreshed from `docs/data/alternatives.json` on launch; entries marked `"confidence": "low"` are dropped at decode) lists per-service tiers, pause rules, like-for-like alternatives, and bundles/cards with their inclusions. `BundleCoverage` cross-checks active subs against bundles the user ticked in Settings › *What you already have* (`OwnedBundlesView`, `AppStore.ownedBundleIds`) plus bundles inferred from their own subs (an Amazon Prime charge ⇒ Prime; see `BundleCoverage.subToBundle`). Inferred carrier perks are plan-dependent, so they surface as "check your plan" (`.discounted`) until confirmed. **Gating:** the single most valuable coverage finding is free; every finding, the exact cheaper tier, pause notes and alternatives are Pro (`visibleCoverageHits`, detail `ProLockOverlay`). Findings also land in Alerts as `.covered` / `.cheaperTier`. **No affiliate links, ever** — the UI says so. Video subs get a JustWatch link instead of any "better content" claim. Maintenance: edit `docs/data/alternatives.json` (sources in `alternatives-sources.json`) and push — GitHub Pages serves it from `main` `/docs`, no release needed. **Bump `updatedAt` on every edit.** `AlternativesCatalogLoader.refresh` only adopts the remote copy when its `updatedAt` is strictly newer than the one in hand, so a corrected price with an unchanged date silently never reaches anyone. Keep `ios-native/Phantom/Resources/alternatives.json` byte-identical to the published copy so a fresh install and an updated install agree.
- **For you (2026-09-11, tab 3 — replaced the parked Picks tab).** `Recommender.build(subs:catalog:)` is pure and runs on every `subscriptions` change (`AppStore.recommendations`). It reads *needs* (active subs grouped by `Kind` with monthly spend) and habit *tags* (Entertainment-first ≥40% of spend on video/liveTV/music/audiobooks, Builder, Wellness, Reader & learner, Security-minded, Convenience, Subscription-heavy ≥8 subs), then produces two lists. **Replacements** ("Same job, better fit"): per held sub, the catalog's `alternatives` ordered by `edge` (`free` → `cheaper` → `bundle` → `better` → `similar`), brands the user already pays for excluded, max 4, groups sorted by best yearly saving. **Suggestions** ("You might also need"): catalog `suggestions` rules `{when: {anyKinds, anyBrands, minSubs, notKinds, notBrands}, apps}`; `minSubs` counts *matching* subs when the rule names kinds/brands ("2+ video services") and *all* subs when it names none ("8+ subscriptions"); apps the user already holds are dropped; rules with `confidence: low` are dropped at decode; every card carries a "Because you pay for X and Y" line; ids prefixed `phantom-` are internal actions (`phantom-negotiate` → Negotiate tab, `phantom-bundles` → OwnedBundlesView). **Gating:** first replacement group + first suggestion free, the rest behind `ProLockOverlay` (`visibleReplacements/visibleSuggestions`). Curation rules: verified iOS app + current price, no affiliate links, never suggest an app the user is already paying for. Sources: `launch/research/alternatives-replacements-sources.md`, `alternatives-suggestions-sources.md`, `alternatives-verticals-2026-09-11.md`.
- **Vertical expansion (2026-09-11).** `Kind` went from 22 to 36 cases, adding the recurring charges that used to land in `.other` and therefore got no overlap check, no coverage check and no recommendation: `dating socialMedia creatorSupport sports podcasts security email webHosting kids health mealKit homeSecurity auto finance`. `Kind.category` now derives the coarse persisted `Category`, so a new brand needs one map entry, not two (`BrandRegistry.category` still honours a hand mapping first). **Overlap is per-kind and deliberate:** dating, finance, security, mealKit, webHosting, sports, homeSecurity, email and podcasts flag duplicates; creatorSupport, socialMedia, health, auto and kids never do — two creators, X Premium vs LinkedIn Premium, therapy vs a prescription service and two kids' apps are not substitutes, and treating them as such would inflate the zombie score. Catalog: 149 services across 28 kinds, 427 alternatives (free 133, cheaper 127, bundle 30, better 67), 41 rules. The highest-value rules live in the money verticals: a credit freeze is free and federally mandated, OS protection is already paid for, and a simple tax return can be filed for nothing. `BrandRegistry.knownDisplayNames`/`knownKinds` and `MerchantNormalizer.brandAliases` carry the long tail so these charges are *recognised*, not just recommendable; short aliases go in `wholeWordAliases` ("aura" inside "laura"). **Merge tooling** lives in the session scratchpad (`merge_v2.py` + `splice.py`): it rejects a tier with a non-numeric `priceMonthly` — one null makes the whole bundled catalog fail to decode for every user — drops low-confidence and self-referential entries, and regenerates the Swift tables. Guards: `TaxonomyTests` (label uniqueness, overlap semantics, catalog↔registry kind agreement) and `RecommenderCatalogTests` (every catalog service is reachable from a real sub; the new rules fire; a held app is never suggested back).
- **Detection pipeline** (rewritten 2026-09-10, guarded by `DetectionCorpusTests` ≥97% recall / ≥95% one-off rejection / ≥97% brand accuracy): the raw row's "RECURRING / MEMBERSHIP / SUBSCRIPTION / .com/bill" label is captured as `ParsedTransaction.recurringHint` *before* the normalizer strips it and promotes unknown merchants; generic aliases (apple, google, max, adobe, kindle, philo…) match whole words only; `APPLE.COM/BILL` / `GOOGLE *` map to `apple-services` / `google-play` (Kind `.platformBilled`, one sub per distinct amount, id `apple-services-1299c`, detail view routes to Settings › Subscriptions + reportaproblem.apple.com); Microsoft 365 / Midjourney / Mistral etc. have their own ids (Microsoft used to display as "GitHub"). `TransactionLedger` persists every imported charge so "upload next month to confirm" actually confirms, and `RecurrenceDetector` infers weekly/biweekly/monthly/quarterly/yearly (tolerating a skipped charge) and records a `PriceHike` when the statement shows the price going up. Catalog hikes (`PriceMonitor.matches`) match the tier the user actually pays and are written back to the sub (`AppStore.applyPriceHike`) + announced immediately.
- **Apple subscriptions (verified 2026-09-10: no public API).** StoreKit 2 (`Transaction.all`, `AppTransaction`, `Product.SubscriptionInfo`), `AppStore.showManageSubscriptions`, the App Store Server API, Advanced Commerce API, WWDC26 bundles, Family Sharing, Screen Time and Wallet are all documented as scoped to *the calling developer's own app* — no third-party app can enumerate a user's other subscriptions (sources in `launch/research/2026-09-monetization-and-entry-point.md` §8). So the "Apple integration" is the screenshot of Settings › Subscriptions: `ImportScreenshotView` detects that screen (`AppleSubscriptionsParser.looksLikeAppleList`) and parses name / plan / `$X/period` / Renews / trial rows into subs with `billedVia: .apple`; expired or "Expires …" (already cancelled) rows are skipped. `AppleReconciler` runs inside `mergeImported` so the same money never shows twice: a bank row `APPLE.COM/BILL $19.99` (`apple-services-1999c`) and the Apple-list "Netflix $19.99" collapse into the named sub (earliest date, rating and statement descriptor carried over). Apple-billed subs always take the Apple cancel path and show the Apple refund route in the detail view.
- **Widget** (`PhantomWidget` target): reads `SharedStore` snapshot the app writes on every `save()`. ⚠️ **The App Group `group.com.yinanzhai.phantom` must be enabled for BOTH the app and widget targets in the Apple Developer portal before a device/App Store build** (Xcode automatic signing usually registers it on first archive). Simulator builds work without it.

## 7. Conventions

- Never use real PII / bank tokens. Sample data is opt-in only (`MockData`, demo mode), clearly labeled in-app. The sample stack deliberately spans beyond streaming and software (a dating renewal, a camera plan, a meal kit, a car wash) so reviewers see the verticals people actually forget.
- Currency: always `fmtUSD()` from `Theme.swift`.
- Design for the 390×844 iPhone viewport. Tap targets ≥ 44pt. Light haptic on destructive/value-changing taps.
- Keep views thin; hoist state into `AppStore`. Prefer existing `Components/` over new ad-hoc UI.
- Don't add comments that restate code; only annotate non-obvious invariants (e.g., score weights cite PRD §3.2; the App Group caveat).

## 8. Building & verifying

```bash
cd ios-native
xcodegen generate                       # regenerate the project after ANY project.yml or new-file change
xcodebuild -project Phantom.xcodeproj -scheme Phantom \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
# or: open Phantom.xcodeproj and run on a simulator
```

- **`xcodegen generate` is required whenever you add a Swift file or edit `project.yml`** (folder-based source groups are only picked up on regeneration).
- Live SourceKit diagnostics in this repo are unreliable (frequent false "Cannot find type / No such module" cascades). **Trust `xcodebuild`, not the editor squiggles.**
- The native UI can't be driven by the web `browse`/`gstack` tools — those are for the deprecated Expo build. Verify the native app in the iOS Simulator.

## 9. Skills to reach for


## 10. Known gaps / next ideas

- App Group must be registered before the next release (see §6).
- No real per-app usage data (`lastUsedAt`/`sessionsLast30d` are 0 on import) — the score leans on same-Kind overlap, bundle coverage, the user's rating, cheapest-tier gap and recent hikes (see §5).
- Catalog is hand-curated (149 services / 17 bundles / 41 suggestion rules as of 2026-09-11); prices move ~10×/yr across the big streamers. The Amex Platinum entertainment credit is a shared $25 pool, so per-sub "reimbursed" values can double-count if several eligible subs are held.
- The CoreML merchant classifier (`tools/train-merchant-classifier.swift`, `tools/training-data.json`) was not retrained in the 2026-09 pass; the deterministic layers carry the corpus tests. Retrain if the "unknown merchant" long tail regresses.
- Distribution, not feature count, is the current bottleneck (only 11 users in launch week) — favor activation (low-friction import) and the share loop over new surfaces.
- **Accounts & sync (2026-09-10).** `AccountService` = Sign in with Apple (optional; onboarding step 3 and Settings › Account). Data sync does not depend on it: the whole SwiftData store (`PersistentSubscription/Alert/Transaction/Evidence/Setting`, `UserProfile`) syncs through the device's iCloud account via CloudKit `.automatic`; `PrefsSync` mirrors the small UserDefaults blobs; `EvidenceLocker` and the ledger moved into the store. `AppStore.scheduleReload()` re-reads everything on `NSPersistentStoreRemoteChange`. Sign out keeps data; **Delete account & data** wipes local + cloud. Unsigned simulator builds have no entitlement → `CloudSyncState.mode == .local`, everything still works on-device.
- **Picks leaderboard (PARKED 2026-09-11 — code, tests and `docs/cloudkit/phantom-public.ckdb` kept; tab replaced by For you; `--screen-picks` still opens it in Debug).** Was tab 4. Public, user-submitted app recommendations grouped by `PickCategory`, ranked by opens. `AppPick` (pending until approved in the CloudKit Console), `PickCounter` (world-writable count, one per pick), `PickClick` (record name = pick|user|day enforces one counted open per person per day), `PickReport`. Report + "hide this developer" satisfy App Review 1.2. Opens are counted only when the tap comes from a signed-in iCloud user; reading is anonymous; no names shown; no affiliate links.
- **Release blockers (2026-09-10):** portal capabilities are registered (`launch/register-capabilities.sh`, needs Xcode signed in); still manual: CloudKit management token → `docs/cloudkit/import-schema.sh` (public schema + roles), deploy both schemas to Production, App Store privacy labels (answer sheet in `launch/store/APP_STORE_LISTING.md`). Debug signs with the Development container environment, Release with `Phantom/Phantom.release.entitlements` (Production). Details in `docs/CLOUDKIT_SETUP.md`.
- **Unit tests** (`PhantomTests/`, 128 as of 2026-09-11): ZombieScore calibration, TransactionParser, RecurrenceDetector (cycles, hikes, Apple multi-charge), MerchantNormalizer, DetectionCorpusTests (150-row descriptor corpus with thresholds), AlternativesCatalog / BundleCoverage / TransactionLedger / PriceMonitor matching, AppleSubscriptionsParser / AppleReconciler, Picks (record mapping, validation, ranking, click keys, screenshot prep), Recommender (needs grouping, edge ordering, held-brand exclusion, rule firing incl. per-kind `minSubs`, held-app suppression, tag cap, low-confidence drop, internal ids) and RecommenderCatalogTests against the shipped catalog, Taxonomy (kind labels, overlap semantics, catalog↔registry drift), sync foundation (Dedupe, row round-trips, PrefsSync plist, Keychain, AccountService), StatementCSV. Run `xcodebuild test -scheme Phantom -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Done in the 2026-07-04 pass: archived the Expo/backend trees to `.archive/legacy-expo/` + rewrote `README.md`; deleted dead `Keychain.swift` + `SandboxRelease.xcconfig`; removed the unused `.debug` bundle-id suffix from `Debug.xcconfig` (a distinct id would force a matching per-config widget-extension id — not worth the churn); onboarding no longer gates on name/email (collected at dispute time); added a "rate your subs" re-engagement notification + Radar prompt + App Store review request on cancel.
- Still-open follow-ups (deliberately deferred): decompose the `AppStore` god-object (large refactor — do once it has direct test coverage); loosen the free-tier paywall / add referral attribution (product/business decisions).
