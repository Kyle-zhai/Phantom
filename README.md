# Phantom

> Find the money you're losing. Subscription Radar + Zombie Score + Dispute Letter generator + Price-hike alerts + Negotiation scripts.

Two implementations live in this repo:

| Path | Stack | Purpose |
|---|---|---|
| `ios-native/` | SwiftUI + Swift 6.2 + iOS 17+ | **The App Store binary.** |
| Root (`app/`, `components/`, `lib/`) | Expo + React Native | Cross-platform reference + browser-testable. |
| `backend/` | Node.js 20 + Express + Plaid SDK | Plaid token exchange, recurring-charge detection, price monitoring. |

## Quickstart

### 1. Start the backend

```bash
cd backend
cp .env.example .env
# Get free sandbox keys at https://dashboard.plaid.com/signup
# Fill in PLAID_CLIENT_ID and PLAID_SECRET in .env
npm install
npm run dev
```

Backend listens on `http://localhost:3000`. Confirm with `curl http://localhost:3000/health`.

### 2. Open the iOS app

```bash
open ios-native/Phantom.xcodeproj
```

In Xcode:
1. Pick **iPhone 17 Pro** (or any iOS 17+ simulator).
2. ▶ Run (`⌘R`).
3. The app opens to the onboarding flow.

### 3. Connect a bank (Plaid sandbox)

1. Tap **Connect with Plaid**.
2. Plaid Link sheet opens — pick **First Platypus Bank**.
3. Use sandbox credentials:
   - Username: `user_good`
   - Password: `pass_good`
4. Pick any account → Phantom fetches transactions and auto-detects recurring charges.

Or tap **Skip — explore with demo data** to skip Plaid and use curated samples.

## What is real (vs. mocked)

| Feature | Status |
|---|---|
| Plaid Link iOS SDK 5.6+ (`LinkKit`) | Real, sandbox-mode out of the box |
| Plaid token exchange + transactions/sync | Real backend round-trip |
| Recurring-charge detection algorithm | Real, median-gap-stability scoring |
| Zombie Score (5 weighted factors) | Real, matches PRD §3.2 |
| EFTA-compliant dispute letter generation | Real, 5 reason templates with statute citations |
| MFMailComposeViewController for sending disputes | Real Mail.app composer + mailto: fallback |
| Negotiation script registry (10 vendors) | Real, served by backend so it's updatable |
| Price-hike monitoring (55+ services) | Real catalog + hike detection. Live scraping requires `PRICE_MONITOR_LIVE=true` |
| Local notifications (trial / hike / zombie nudges) | Real UNUserNotificationCenter |
| StoreKit 2 in-app purchases | Real, with `Phantom.storekit` local config for sim testing |
| SwiftData persistence | Real, `@Model` schemas for Subscription / Alert / UserProfile |
| Keychain for sensitive tokens | Real, `kSecAttrAccessibleAfterFirstUnlock` |
| Real device install + App Store archive | Verified — `xcodebuild archive` produces a valid `.xcarchive` |

### Genuinely outside the code (you need to provide)

1. **Apple Developer Program account** ($99/yr) — required to sign the binary, ship to TestFlight, list on App Store Connect.
2. **Plaid Production approval** — sandbox is free and ready; flipping to `production` env needs Plaid's compliance review of your company.
3. **App Store Connect product configuration** — create two auto-renewing subscriptions matching the product IDs:
   - `com.yinanzhai.phantom.pro.monthly` ($3.99/mo)
   - `com.yinanzhai.phantom.pro.yearly` ($29.99/yr)
4. **Deploy backend** — works locally as-is. For TestFlight/App Store, deploy `backend/` to Vercel (run `vercel deploy` inside it) and set `PHANTOM_API_BASE` in Xcode build settings to the deployed URL.

## Submission checklist

```bash
# 1. Set your team in Xcode → Signing & Capabilities
# 2. Build for archive (signed)
xcodebuild -project ios-native/Phantom.xcodeproj \
  -scheme Phantom -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/phantom.xcarchive archive

# 3. Validate with App Store Connect
xcodebuild -exportArchive \
  -archivePath /tmp/phantom.xcarchive \
  -exportPath /tmp/phantom-export \
  -exportOptionsPlist ios-native/exportOptions.plist

# 4. Upload
xcrun altool --upload-app -f /tmp/phantom-export/Phantom.ipa \
  -t ios -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD
```

## Architecture

```
ios-native/Phantom/
├── PhantomApp.swift               @main, wires SwiftData + AppStore
├── Phantom.storekit               Local StoreKit config (Pro monthly + yearly)
├── Theme/Theme.swift             Uber-style design tokens
├── Models/
│   ├── Models.swift              Subscription, PriceAlert, Category, BillingCycle
│   └── Persistent.swift          @Model SwiftData mirrors
├── Services/
│   ├── AppConfig.swift           Info.plist-driven env config
│   ├── APIClient.swift           Generic actor-based HTTP client
│   ├── Keychain.swift            Plaid token + user id storage
│   ├── PlaidService.swift        Backend Plaid wrapper + RemoteSubscription→Subscription
│   ├── PlaidLink.swift           SwiftUI wrapper around LinkKit (Plaid's official iOS SDK)
│   ├── PriceMonitor.swift        Catalog fetch + hike detection
│   ├── PurchaseService.swift     StoreKit 2 — products, purchase, restore, entitlement listening
│   ├── MailComposer.swift        MFMailComposeViewController bridge + mailto: fallback
│   ├── NotificationCenter.swift  Trial/hike/zombie scheduling
│   ├── DisputeLetter.swift       EFTA/ROSCA/Reg E template engine
│   ├── ZombieScore.swift         5-factor weighted algorithm (PRD §3.2)
│   ├── Negotiation.swift         Per-vendor retention scripts
│   └── MockData.swift            Curated demo subs (used only when --demo arg passed)
├── Store/AppStore.swift          @Observable global store wiring everything
├── Components/                   Button, Card, Badge, Avatar, ZombieMeter, Section, SubscriptionRow
└── Screens/
    ├── Onboarding/               Welcome → Value → Connect (Plaid Link)
    ├── Tabs/                     Radar / Alerts / Negotiate / Settings
    ├── SubscriptionDetailView.swift
    ├── DisputeLetterView.swift   3-step flow w/ real Mail composer
    ├── NegotiateDetailView.swift
    └── PaywallView.swift         Real StoreKit 2 purchase
```

```
backend/
├── server.js                     Express app
├── lib/
│   ├── plaid.js                  Plaid client setup
│   ├── recurring.js              Recurring-charge detection from Plaid /transactions/sync
│   ├── prices.js                 Catalog snapshot + monitor (live scraper opt-in)
│   └── negotiation-scripts.js
├── data/seed-prices.js           55+ US services with current prices
└── vercel.json                   For one-command Vercel deploy
```

## Debug launch flags

When running via Xcode you can pass arguments in *Edit Scheme → Arguments*:

| Flag | Effect |
|---|---|
| `--skip-onboarding` | Start at Radar with empty store |
| `--demo` | Start at Radar with curated sample subscriptions |
| `--tab-{alerts,negotiate,settings}` | Open a specific tab on launch |
| `--sub <id>` | Open subscription detail (e.g. `--sub peacock`) |
| `--dispute <id>` | Open dispute letter generator |
| `--neg <id>` | Open negotiation detail |
| `--screen-paywall` | Open paywall |
| `--screen-{value,connect}` | Open a specific onboarding screen |

These also work via `xcrun simctl launch booted com.yinanzhai.phantom --demo`.
