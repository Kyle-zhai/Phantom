# App Store Connect — Listing Pack

Copy and paste each field into App Store Connect at https://appstoreconnect.apple.com/apps.

---

## App Information

| Field | Value |
|---|---|
| **Name** | Phantom |
| **Subtitle** (max 30 chars) | Find the money you're losing |
| **Primary category** | Finance |
| **Secondary category** | Productivity |
| **Bundle ID** | `com.yinanzhai.phantom` |
| **SKU** | `phantom-ios-001` |
| **Content rights** | "Does this app use third-party content?" → **No** |
| **Age rating** | 4+ (no objectionable content) |
| **Pricing** | Free with In-App Purchases |
| **Availability** | United States (Phase 1) — expand later |

---

## Description (max 4000 chars)

```
You're still paying for subscriptions you forgot you had. Phantom finds them without a bank login — then helps you cancel, keep the proof, and fight charges that should never have gone through. Your data stays on your iPhone and in your own iCloud, never on a Phantom server.

GET YOUR MONEY BACK

1. Find the charges. Start from Apple subscriptions, screenshot a statement, or import a bank CSV. On-device OCR reads it. No account to connect. No password to hand over.

2. See the zombies. Every recurring charge gets a Zombie Score from 0–100: overlapping services, what you rate it, and whether you're paying above market. The 80+ ones are the money quietly leaving.

3. Cancel with a checklist. Phantom opens the vendor's real cancel page and walks you through it. Save a confirmation number or screenshot in an on-device evidence locker — so you have proof if they bill you again.

4. Fight the charge. Generate an EFTA/ROSCA-compliant dispute letter for silent auto-renewals, trial traps, and billing after you already cancelled. If the merchant won't refund, Phantom builds a chargeback packet with a Regulation E/Z script you can read to your bank.

5. Don't get surprised twice. Price-hike and trial-end alerts, plus a reminder to re-scan your next statement. For 64 services Phantom has a researched, service-specific retention script, and a proven general one for everything else, so you can keep the subscription for less.

PRIVATE BY DESIGN

Phantom has no servers of its own and no bank connection. Statements and cancel proof stay on your phone and, if you sign in with Apple, in your own iCloud. We never receive your data, so we can't sell it. Nothing in Phantom is public: no profile, no feed, no leaderboard.

• We never ask for your bank login.
• We never sell your data.
• We never push loans or credit cards.

PRICING

Free — track up to 5 subscriptions and send 1 dispute letter a month.
Phantom Pro — $3.99/month or $29.99/year (save 37%): unlimited subscriptions, unlimited dispute letters and chargeback packets, cancel checklists, the on-device evidence locker, every alert, and the complete negotiation-script catalog.

Pro pays for itself the first time it catches a charge you would have missed.

Start free. Find what you're losing in about a minute.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://kyle-zhai.github.io/Phantom/privacy.html
```

---

## Promotional text (max 170 chars, can update without re-review)

```
Cancel forgotten charges without a bank login. Keep proof on your iPhone. If they bill you anyway, get a dispute letter and a chargeback script.
```

---

## Keywords (max 100 chars, comma-separated, no spaces after commas)

```
subscription,manage,cancel,save,money,refund,bill,track,budget,spending,unsubscribe,dispute,zombie
```

---

## Support URL

```
https://kyle-zhai.github.io/Phantom/
```

## Marketing URL (optional)

```
https://kyle-zhai.github.io/Phantom/
```

## Privacy Policy URL

Required. App Store Connect → App Information.

```
https://kyle-zhai.github.io/Phantom/privacy.html
```

## License Agreement / EULA (Guideline 3.1.2)

Keep **Apple's Standard EULA** selected (do not upload a custom one unless you paste `docs/terms.html` into the custom-EULA field). Then the **App Description must include this exact URL**, or review is blocked:

```
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

---

## App Review Information

| Field | Value |
|---|---|
| Sign-in required | ❌ No — Sign in with Apple is optional (step 3 of onboarding has "Continue without an account"); demo data path available |
| Demo account | N/A — no account or bank connection is required; use “Browse with sample data” during onboarding |
| Notes for reviewer | See below |

### Notes for reviewer

```
Thanks for reviewing Phantom.

Phantom is a privacy-first subscription-management app. Users either
upload screenshots of their bank/credit-card app (OCR runs entirely
on-device via Apple Vision) or add subscriptions manually. The app
never connects to a bank — no Plaid, no API keys. There is no Phantom
server: an optional Sign in with Apple syncs the user's data to their
OWN iCloud (CloudKit private database). There is no user-generated
content and no public surface of any kind: no profile, no feed, no
leaderboard. The "For you" tab compares the user's own subscriptions,
on-device, against a static catalog of prices and alternatives that
the app downloads from GitHub Pages; nothing about the user is sent.
Recommendations carry no affiliate links.

TO REVIEW THE APP IN UNDER 2 MINUTES:

1. On launch you'll see a 4-step onboarding (Welcome → Value →
   Profile → Method).

2. On the Profile screen, enter any name and email (e.g.
   "Reviewer" / "reviewer@apple.com"). Data is stored on-device only.

3. On the "How should we find your subscriptions?" screen, scroll
   to the bottom and tap "Browse with sample data".

4. This loads 14 curated example subscriptions (Netflix, Hulu,
   Adobe, Audible, Planet Fitness, etc.) so you can review the full
   feature set without uploading any real screenshots.

5. A yellow "SAMPLE DATA MODE" banner appears in Settings so it's
   always clear this is preview data, not real user data. A "Clear
   sample data" button is one tap away.

KEY FLOWS TO REVIEW (after loading sample data):

1. Radar tab → tap any subscription → see Zombie Score breakdown
2. Subscription detail → "Cancel" → opens vendor's real cancel page
   in Safari (e.g., Netflix /cancelplan)
3. Alerts tab → tap any alert → "Take action" or "Get refund"
4. Dispute letter generator → fill form → preview → "Send via Mail"
   (opens MFMailComposeViewController)
5. Negotiate tab → pick any service → see real retention script
6. Settings → Account → "Delete account" (App Store 5.1.1(v) compliance)
7. Settings → "Manage subscription" (deep links to iOS Subscriptions)
8. Free tier limit: only top 5 subscriptions visible; "Unlock with
   Pro" surfaces the rest. Tap to see the paywall.
9. Paywall → "Restore" button in top-right (required by 3.1.1)

NOTES ON IN-APP PURCHASES:

We use StoreKit 2 with two auto-renewing subscriptions:
   com.yinanzhai.phantom.pro.monthly  ($3.99/month)
   com.yinanzhai.phantom.pro.yearly   ($29.99/year)
Both share the subscription group "Phantom Pro".

Free tier is genuinely useful (5 subscriptions, 1 dispute letter
per month, 1 alert at a time). Pro unlocks unlimited everything.

PRIVACY / DATA HANDLING:

No Phantom server. All transaction parsing happens on-device with
Apple Vision OCR; sync (optional) uses the user's private iCloud
database. Nothing is published or shared with other users. No
third-party SDK that performs tracking. No analytics SDK. Account
deletion (Settings → Account → Delete account & data) removes device
+ iCloud data (guideline 5.1.1(v)). Privacy Policy and Terms of Service linked
above; full source: github.com/Kyle-zhai/Phantom

Thanks!
Yinan Zhai
```

| Field | Value |
|---|---|
| First name | **Yinan** |
| Last name | **Zhai** |
| Phone | **REQUIRED — enter the reachable phone number for App Review before submission** |
| Email | **yn.zhai0205@gmail.com** |

---

## In-App Purchases

Create two **auto-renewable** subscriptions in App Store Connect → Features → In-App Purchases. Both belong to a single subscription group named "Phantom Pro".

### Product 1 — Monthly

| Field | Value |
|---|---|
| Reference name | `Pro Monthly` |
| Product ID | `com.yinanzhai.phantom.pro.monthly` |
| Subscription Duration | 1 month |
| Pricing | Tier 4 ($3.99 USD) |
| Localizations (English) | |
| — Display name | `Phantom Pro Monthly` |
| — Description | `Unlimited subscription scans, dispute letters, and price-hike alerts. Cancel any time.` |
| Review screenshot | Use `screenshots/16-paywall.png` |

### Product 2 — Annual

| Field | Value |
|---|---|
| Reference name | `Pro Annual` |
| Product ID | `com.yinanzhai.phantom.pro.yearly` |
| Subscription Duration | 1 year |
| Pricing | Tier 30 ($29.99 USD) |
| Localizations (English) | |
| — Display name | `Phantom Pro Annual` |
| — Description | `Save 37% vs monthly. Unlimited features. 30-day refund window.` |
| Review screenshot | Same as monthly |

---

## What's New in This Version (release notes, v1.2.0)

Paste this into the **1.2.0** version in App Store Connect (not 1.1.1 — that train is closed).

```
Cancel-and-clawback, without a bank login.

• Cancel with a checklist, then save the confirmation number or screenshot on your iPhone — never uploaded.
• After a dispute letter, get a chargeback packet with a Regulation E/Z script and where to file if the merchant won't refund.
• Import a bank CSV, or share a statement into Phantom from Files / Mail.
• Get a reminder to re-scan your next statement so a cancelled charge doesn't sneak back.
• Apple subscriptions still the fastest first import. Screenshots still work.

Nothing leaves your phone except into your own iCloud. We still never ask for your bank login.
```

---

## App Privacy (nutrition labels) — App Store Connect → App Privacy

Answer the questionnaire exactly like this (re-check when features change):

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **Yes** |
| **Data Linked to You** | |
| Identifiers → User ID | Yes — the Sign in with Apple user identifier only. Purpose: **App Functionality**. Not used for tracking. |
| User Content → Other User Content | No — Phantom publishes nothing and has no user-to-user content. |
| Contact Info → Name, Email Address | **No** — name/email from Sign in with Apple stay on the device and in the user's iCloud Keychain; Phantom never receives them. |
| Financial Info, Purchases, Usage Data, Diagnostics | **No** (IAP is handled by Apple; no analytics SDK) |
| **Data Used to Track You** | **None** |

Everything synced through the user's private iCloud database is not "collected" in Apple's sense (the developer cannot access it), so it is not declared.

---

## Screenshots required

App Store Connect needs **3 screenshots minimum**, up to 10, at one of these sizes:

| Device | Required size |
|---|---|
| iPhone 17 Pro Max (6.9") | 1320 × 2868 |
| iPhone 16 Plus (6.5") | 1284 × 2778 |
| iPad Pro 13" | 2064 × 2752 |

The ones already in `ios-native/screenshots/` are at iPhone 17 Pro resolution which works as the 6.7" device class. Use these (renamed for App Store Connect):

| Order | File | Caption suggestion |
|---|---|---|
| 1 | `05-radar.png` (or `real-radar.png`) | Find every subscription you're paying for |
| 2 | `08-detail-peacock.png` | See exactly why each one is a zombie |
| 3 | `10-dispute-form.png` | One tap = a legal dispute letter |
| 4 | `12-alerts.png` | Know about price hikes 7 days early |
| 5 | `13-negotiate.png` | Save without cancelling — proven scripts |
| 6 | `16-paywall.png` | $3.99 a month. Saves $47 a month on average. |

For "marketing screenshots" with overlaid text, you can use Apple's [App Store Connect Help → Generate Screenshots](https://developer.apple.com/help/app-store-connect/manage-screenshots-and-app-previews/take-app-store-screenshots), or tools like Screenshots.pro / RocketSim.
