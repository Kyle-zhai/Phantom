# Phantom

> Find the money you're losing. Surfaces "zombie" subscriptions, generates EFTA-compliant dispute letters, warns about price hikes, and gives per-vendor retention scripts — **100% on-device, no bank login, no backend.**

## Which codebase is real

**`ios-native/` is the shipped App Store app and the only thing you build.** It's SwiftUI + SwiftData, fully on-device.

A deprecated Expo/React-Native prototype and an old Plaid/Express backend have been moved to `.archive/legacy-expo/`. They are **not** built or shipped — they predate the native rewrite and are kept only for history.

## How it works (no servers involved)

Phantom never talks to your bank and has no backend. You give it screenshots of your bank app / Apple Wallet / statements, and everything runs locally:

1. **Vision OCR** reads the screenshots on-device.
2. A **CoreML** classifier + heuristics (`MerchantNormalizer`, `TransactionParser`) turn OCR lines into merchant + amount + date.
3. **`RecurrenceDetector`** finds charges that repeat monthly/yearly.
4. **`ZombieScore`** ranks each subscription 0–100 (recency, usage, same-category overlap, your rating, price-vs-market).
5. **SwiftData** persists everything on the device. A **WidgetKit** widget reads a shared snapshot.

The only network call is fetching a static `prices.json` (hosted on GitHub Pages) to detect price hikes.

## Build & run

Requires Xcode 17+ (iOS 17 SDK). The Xcode project is generated from `project.yml` with [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
cd ios-native
xcodegen generate                      # regenerate after any project.yml or new-file change
open Phantom.xcodeproj                  # then ⌘R on an iOS 17+ simulator
```

Or from the command line:

```bash
xcodebuild -project Phantom.xcodeproj -scheme Phantom \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

**Tests:**

```bash
xcodebuild test -project Phantom.xcodeproj -scheme Phantom \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

The app opens to onboarding: **Welcome → Value → Connect**, where you import via Apple subscriptions (recommended), statement screenshots, manual entry, or a demo dataset.

## Architecture (`ios-native/Phantom/`)

```
PhantomApp.swift            @main App + AppDelegate (notification delegate) + DeepLink holder
Models/
  Models.swift              View-layer structs (Subscription, PriceAlert, Category…)
  Persistent.swift          @Model SwiftData mirrors
Store/AppStore.swift        @Observable single source of truth (state, scoring, notifications, widget)
Services/
  OCR.swift                 Vision on-device text recognition
  TransactionParser.swift   OCR lines → transactions
  MerchantNormalizer.swift  Clean merchant text → brandId
  MerchantML.swift          CoreML subscription classifier
  RecurrenceDetector.swift  Confirmed vs likely recurring charges
  BrandRegistry.swift       Logos, brand colors, category inference
  ZombieScore.swift         0–100 score with adaptive weighting (PRD §3.2)
  DisputeLetter.swift       EFTA/ROSCA letter generator
  Negotiation.swift         47 vendor retention scripts
  CancellationRegistry.swift Verified cancel URLs + Apple/phone/in-person paths
  PriceMonitor.swift        Fetch prices.json, detect hikes
  NotificationCenter.swift  Local notification scheduling (trial/hike/zombie/cancel-check/rate-nudge)
  SharedStore.swift         App Group bridge — snapshot the widget reads
  PurchaseService.swift / Entitlements.swift  StoreKit 2 + free/Pro gating
  MockData.swift            Opt-in sample data (demo mode only)
Screens/                    Onboarding/, Tabs/ (Radar/Alerts/Negotiate/Settings), Detail, Dispute, Import, Paywall
Components/                 Button, Card, Badge, ZombieMeter, SavingsShareCard, …
Theme/Theme.swift           Palette / Radius / Space / AppFont tokens
../PhantomWidget/           WidgetKit extension (separate target)
PhantomTests/               Unit tests (ZombieScore, TransactionParser, RecurrenceDetector, BrandRegistry)
```

## Tech stack

- **Swift 5.10 / SwiftUI**, iOS 17+, iPhone-only
- **SwiftData** for local persistence; **`@Observable AppStore`** as the hub
- **Vision** OCR + **CoreML** merchant classifier
- **StoreKit 2** for Pro IAP; **UserNotifications** for local alerts; **WidgetKit** for the widget
- **SVGView** (SPM) for brand logos
- **No backend, no Plaid** — everything runs on-device

## Debug launch flags

Pass in *Edit Scheme → Arguments*, or `xcrun simctl launch booted com.yinanzhai.phantom <flag>`:

| Flag | Effect |
|---|---|
| `--demo` | Start at Radar with curated sample subscriptions |
| `--skip-onboarding` | Start at Radar with an empty store |
| `--tab-{alerts,negotiate,settings}` | Open a specific tab |
| `--sub <id>` | Open a subscription's detail (e.g. `--sub peacock`) |
| `--dispute <id>` / `--neg <id>` | Open dispute / negotiate for a sub |
| `--screen-{paywall,value,connect,import,profile}` | Open a specific screen |
| `--fake-pro-{monthly,yearly}` | Simulate an active Pro entitlement (DEBUG only) |

## App Store notes

- Product IDs: `com.yinanzhai.phantom.pro.monthly`, `com.yinanzhai.phantom.pro.yearly` (configure in App Store Connect; `Phantom.storekit` drives the simulator).
- The App Group `group.com.yinanzhai.phantom` must be enabled for **both** the app and widget targets before a device/App Store build.
- See `CLAUDE.md` for the full working agreement and conventions.
