# Phantom Privacy Policy

**Effective: 2026-05-14 · Last updated: 2026-09-11** (added iCloud sync and Sign in with Apple; removed the Picks leaderboard, which was never released)

Published at https://kyle-zhai.github.io/Phantom/privacy.html — `docs/privacy.html` is the canonical text; keep this file in sync.

This policy describes how **Phantom** (operated by **Yinan Zhai**, an independent developer) collects, uses, stores, and shares information when you use the Phantom iOS app.

## 1. What we collect

### 1.1 On your device and in your own iCloud
Phantom has **no server of its own**. The following is stored in your device's local database and, if you sign in, synced to **your own iCloud account** (Apple's CloudKit private database) so it follows you to your other devices. We cannot read your iCloud data.

- Screenshots you import (used only momentarily for OCR, never persisted as images)
- Extracted text: merchant name, amount, date of each charge
- Subscriptions you add, ratings, notes, cancellation status, and the bundles you tell us you already own
- Cancel proof you save (confirmation numbers, notes, an optional screenshot)
- Dispute letters you generate and your notification preferences

Without an account, all of this stays on your iPhone only.

### 1.2 Apple-mediated information
- App Store purchase records (Apple processes the payment; we receive only a verified flag that you're on Pro)
- Anonymous crash diagnostics if you opt in at the iOS level

### 1.3 Account (Sign in with Apple)
Signing in is optional. Apple gives Phantom an anonymous user identifier and, the first time only, the name and email you choose to share (Apple's private relay email works). Used to show who is signed in and pre-fill the dispute-letter signature. Stored on your device and in your iCloud Keychain, never on a Phantom server.

### 1.4 Recommendations
Phantom suggests cheaper or free replacements for the services you pay for, and apps that fit the pattern of your subscriptions. This is worked out **entirely on your device** by comparing your own subscriptions against a catalog of prices and alternatives that Phantom downloads as a plain file. Your subscriptions, your spending and the recommendations you see are never uploaded, and nothing about you is sent when the catalog is downloaded.

**No part of Phantom is public.** There is no profile, no feed, no leaderboard and no way for another person to see anything you have in the app.

### 1.5 What we never collect
Bank login or password · card number or CVV · balances or net worth · browsing history, location, contacts, or photo library beyond images you explicitly import · advertising identifiers (we never call ATTrackingManager).

## 2. How we use information
Only to: detect recurring charges; compute Zombie Scores; notify you on-device about trial endings, price hikes and forgotten charges; generate dispute-letter templates; provide negotiation scripts; sync your data between your own devices via iCloud; compare your subscriptions against the price catalog, on your device, to show cheaper plans, bundles you already own and alternative apps.

We do **not** sell your data, share it with advertisers, lenders, data brokers or marketers, or push loans or financial products.

## 3. Third parties
- **Apple** — App Store purchases, Sign in with Apple, and iCloud sync in your own private database via CloudKit. https://www.apple.com/legal/privacy/
- **GitHub** — hosts this website and small public JSON catalogs of subscription prices and bundles (no user data passes through).

## 4. Security
On-device data lives in iOS's sandboxed container behind your passcode and Secure Enclave. iCloud sync runs on Apple's CloudKit in your own private database; data in transit and at rest is encrypted by Apple. We do not run a backend server of our own.

## 5. Retention & deletion
- Uninstalling Phantom deletes everything on that device; a signed-in user's iCloud copy remains until deleted.
- **Settings → Account → Delete account & data** erases everything on the device and in your iCloud (the deletion syncs to your other devices) and signs you out. **Sign out** alone never deletes anything.

## 6. Your rights
Everything Phantom holds about you is in the app and in your own iCloud, so access, portability and correction are in your hands directly; deletion is one tap in Settings. Questions or requests: yn.zhai0205@gmail.com — we respond within 30 days. California residents: we do not sell personal information.

## 7. Children
Phantom is not directed at children under 13 (16 in the EU); we do not knowingly collect data from them.

## 8. Changes
Material changes update the "Last updated" date above and, where possible, are announced in-app.

## 9. Contact
Yinan Zhai · yn.zhai0205@gmail.com
