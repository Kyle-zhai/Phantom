# Phantom — Project Context for Claude Code

> A subscription-management iOS app that surfaces "zombie subscriptions," generates EFTA-compliant dispute letters, warns about price hikes, and helps users negotiate retention discounts. PRD at `Phantom_PRD.md`. Shipping on the App Store; UI inspired by Uber (black-and-white, large type, generous spacing).

## 0. WHICH CODEBASE IS REAL (read this first)

- **`ios-native/` — the SHIPPED native iOS app. This is the source of truth.** SwiftUI + SwiftData, fully on-device, no backend. All work happens here.
- The old Expo/React-Native prototype and Plaid/Express backend were moved to `.archive/legacy-expo/` on 2026-07-04. Not shipped, not built. Ignore unless doing history archaeology.

When the user says "the app," they mean `ios-native/`.

## 1. Product (one-liner per surface)

| Surface | Job-to-be-done |
|---|---|
| Onboarding | Sell the value, then import subscriptions (Apple-subscriptions quick start OR statement screenshots — **no bank login**) |
| Radar (Home) | Monthly + yearly spend, biggest savings opportunity, every subscription sorted by zombie score |
| Detail | Explain *why* a sub is a zombie; cancel (jumps to vendor cancel page) / negotiate / dispute |
| Dispute Letter | Generate an EFTA/ROSCA-compliant letter; mail or copy |
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
- **No backend, no Plaid.** Everything runs on-device. Price catalog is a static `prices.json` fetched from GitHub Pages.
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
  RecurrenceDetector.swift  # confirmed vs likely subs across months
  BrandRegistry.swift       # logos + brand colors
  ZombieScore.swift         # 0–100 score (see §5)
  DisputeLetter.swift       # EFTA/ROSCA letter generator
  Negotiation.swift         # 47 vendor retention scripts
  CancellationRegistry.swift# verified direct cancel URLs (60+) + Apple/phone paths
  PriceMonitor.swift        # fetch prices.json, detect hikes
  NotificationCenter.swift  # local notification scheduling (trial/hike/zombie/cancel-check)
  SharedStore.swift         # App Group bridge — snapshot the widget reads
  PurchaseService.swift / Entitlements.swift  # StoreKit + free/Pro gating
  MockData.swift            # opt-in sample data (demo mode only)
Screens/                    # Onboarding/, Tabs/ (Radar/Alerts/Negotiate/Settings), Detail, Dispute, Import, Paywall, AppleSubscriptionsGuideView
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

`ZombieScore.compute(sub) → 0–100`. Weights:

```
recencyOfLastUse 35%   (days since last open → 0 if today, 100 if 60d+)
usageVsPrice     25%   (sessions per dollar — low = zombie)
overlap          20%   (count of same-category subs → more = zombie)
userRating       15%   (1–5 → inverted)
priceVsMarket     5%   (above-market premium → zombie)
```

Score ≥ 80 → zombie (flagged + nudge). 50–79 → review. <50 → keep.

**Adaptive weighting (2026-07-04).** On an imported sub there is no usage data (`lastUsedAt`/`sessionsLast30d` are 0), so those two factors carry no signal. Pinning them at neutral 50 capped every import at 70 — no sub could ever reach 80 and the app never surfaced a zombie. `compute` now **renormalizes over the factors it actually has signal for** when usage is unknown (overlap always; rating; price-vs-market when known), so a duplicate/low-rated sub can reach "zombie" while a lone, unrated sub stays "keep". When real usage data exists (demo/rated), the full PRD §3.2 weights are used unchanged. Two inputs that were dead are now live: `hasOverlapWith` is recomputed by `AppStore.recomputeOverlaps()` (same-category peers) on every import/launch, and `category` is inferred via `BrandRegistry.category(for:)` instead of always `.other`. Users set `userRating` via the star control in `SubscriptionDetailView` (`AppStore.setRating`). This tuning is the one deliberate product judgment — adjust the renormalization if flagging feels too aggressive/timid.

## 6. Notifications, cancellation, widget (added 2026-05-28 — how they work)

- **Notifications are live.** Permission is requested at the highest-intent moment (right after the first import) and from Settings → Notifications. `AppStore.rescheduleAllNotifications()` is the single scheduler; it honors the per-category toggles (`notifyHikes/notifyTrials/notifyZombies`) and only schedules when authorized. `PhantomApp.task` calls `store.onLaunch()` on every cold start (previously gated behind a Plaid token that never existed, so nothing ever fired). Taps route via `AppDelegate` → `DeepLink.shared` → `AppStore.openSubscription` → Radar nav path.
- **Cancellation concierge.** Detail view's "Cancel" opens the verified `CancellationRegistry` URL (web/`tel:`/iOS Subscriptions). On return from Safari it asks "did it go through?"; confirming calls `AppStore.confirmCancellation` which marks cancelled AND schedules a ~35-day verification reminder (`cancelcheck-…`) to re-scan the next statement. Copy is honest — Phantom can't cancel on the user's behalf.
- **Savings share card** (`Components/SavingsShareCard.swift`): `ShareLink` of an `ImageRenderer`-rendered card. `.found` (potential) on Radar, `.saved` (realized) after a cancel. The app's only growth loop — keep it.
- **Widget** (`PhantomWidget` target): reads `SharedStore` snapshot the app writes on every `save()`. ⚠️ **The App Group `group.com.yinanzhai.phantom` must be enabled for BOTH the app and widget targets in the Apple Developer portal before a device/App Store build** (Xcode automatic signing usually registers it on first archive). Simulator builds work without it.

## 7. Conventions

- Never use real PII / bank tokens. Sample data is opt-in only (`MockData`, demo mode), clearly labeled in-app.
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

- **superpowers:brainstorming / writing-plans** — before any *new* multi-step feature.
- **superpowers:verification-before-completion** — gate before marking done.
- **investigate** — when something breaks; never patch around symptoms.
- **claude-md-management:revise-claude-md** — keep this file accurate as the app evolves.

## 10. Known gaps / next ideas

- App Group must be registered before the next release (see §6).
- No real per-app usage data (`lastUsedAt`/`sessionsLast30d` are 0 on import) — the score now leans on computed category-overlap + user rating (see §5 adaptive weighting) since neither usage factor has signal on import.
- Distribution, not feature count, is the current bottleneck (only 11 users in launch week) — favor activation (low-friction import) and the share loop over new surfaces.
- **Unit tests exist now** (`PhantomTests/`): ZombieScore, TransactionParser, RecurrenceDetector, BrandRegistry category. Run `xcodebuild test -scheme Phantom -destination 'platform=iOS Simulator,name=<sim>'`. Highest-value place to add coverage next: MerchantNormalizer.
- Done in the 2026-07-04 pass: archived the Expo/backend trees to `.archive/legacy-expo/` + rewrote `README.md`; deleted dead `Keychain.swift` + `SandboxRelease.xcconfig`; removed the unused `.debug` bundle-id suffix from `Debug.xcconfig` (a distinct id would force a matching per-config widget-extension id — not worth the churn); onboarding no longer gates on name/email (collected at dispute time); added a "rate your subs" re-engagement notification + Radar prompt + App Store review request on cancel.
- Still-open follow-ups (deliberately deferred): decompose the `AppStore` god-object (large refactor — do once it has direct test coverage); loosen the free-tier paywall / add referral attribution (product/business decisions).
