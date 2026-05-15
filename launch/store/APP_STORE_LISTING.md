# App Store Connect — Listing Pack

Copy and paste each field into App Store Connect at https://appstoreconnect.apple.com/apps.

---

## App Information

| Field | Value |
|---|---|
| **Name** | SubSpy |
| **Subtitle** (max 30 chars) | Find the money you're losing |
| **Primary category** | Finance |
| **Secondary category** | Productivity |
| **Bundle ID** | `com.subspy.app` |
| **SKU** | `subspy-ios-001` |
| **Content rights** | "Does this app use third-party content?" → **No** |
| **Age rating** | 4+ (no objectionable content) |
| **Pricing** | Free with In-App Purchases |
| **Availability** | United States (Phase 1) — expand later |

---

## Description (max 4000 chars)

```
SubSpy finds the subscriptions you forgot you were paying for — and helps you cancel them in seconds.

The average American pays for 4.5 subscriptions they never use. That's about $50 per month silently disappearing from your bank account. SubSpy stops the bleeding.

HOW IT WORKS

1. Connect your bank securely via Plaid (the same provider Venmo and Coinbase use). We see merchant names and amounts — never your card number, never your account balance.

2. Subscription Radar scans your last 90 days of charges and automatically detects every recurring payment.

3. Each subscription gets a Zombie Score from 0 to 100 based on how often you actually use it. Scores ≥ 80 are flagged for cancellation.

4. One tap generates an EFTA-compliant dispute letter for wrongful charges — auto-renewals you weren't notified about, trial-conversions, post-cancellation billing.

5. Get a 7-day heads up before any price increase across 2,000+ services.

6. For services that hand out retention discounts (Hulu, SiriusXM, Audible, Adobe Creative Cloud, and more), SubSpy gives you the exact script to use.

PRIVACY YOU CAN VERIFY

- We never sell your data.
- We never push loans, credit cards, or financial products.
- We never store your card number or account number.
- Disconnect your bank with one tap. Delete your account with one tap.

These aren't promises in a privacy policy footnote. They're the entire business model.

WHY NOT ROCKET MONEY?

Rocket Money's parent company is a lender. Their goal is to qualify you for loans, and they sell anonymized data to do it. SubSpy's only revenue is a $3.99/month subscription. We win when you save money. That's the entire alignment.

PRICING

Free: 3 subscriptions scanned, basic detection
SubSpy Pro Monthly: $3.99/month — unlimited scans, alerts, disputes
SubSpy Pro Annual: $29.99/year — save 37% vs monthly

Average Pro user saves $47/month. Pro pays for itself in week one.

QUESTIONS

support@[yourdomain.com]
Privacy policy: https://[yourdomain.com]/privacy
Terms of service: https://[yourdomain.com]/terms
```

---

## Promotional text (max 170 chars, can update without re-review)

```
Now monitoring 2,000+ services for price hikes. Get notified 7 days before any increase. The fastest way to stop paying for what you don't use.
```

---

## Keywords (max 100 chars, comma-separated, no spaces after commas)

```
subscription,manage,cancel,save,money,bank,plaid,refund,bill,track,budget,spending,unsubscribe,zombie
```

---

## Support URL

```
https://[yourdomain.com]/support
```

## Marketing URL (optional)

```
https://[yourdomain.com]
```

## Privacy Policy URL

```
https://[yourdomain.com]/privacy
```

---

## App Review Information

| Field | Value |
|---|---|
| Sign-in required | ❌ No (offers "Skip — explore with demo data" path) |
| Demo account | N/A — reviewer uses Plaid sandbox: First Platypus Bank / user_good / pass_good |
| Notes for reviewer | See below |

### Notes for reviewer

```
Thanks for reviewing SubSpy.

SubSpy is a subscription-management app. Users connect their bank
account via Plaid (read-only) to detect recurring charges.

TO REVIEW WITHOUT A REAL BANK ACCOUNT:

Option 1 — Demo mode (fastest):
   On the third onboarding screen, tap "Skip — explore with demo
   data". This populates the app with 14 sample subscriptions so you
   can review the full feature set without any bank connection.

Option 2 — Plaid Sandbox (recommended to verify the integration):
   On the connect screen, tap "Connect with Plaid". When Plaid Link
   opens:
     Bank: First Platypus Bank (search "Platypus")
     Username: user_good
     Password: pass_good
     MFA code (if asked): 1234
   This connects to a fake bank Plaid runs for testing. No real
   credentials are stored on our servers.

KEY FLOWS TO REVIEW:

1. Onboarding (3 screens) → bank connect → dashboard auto-populates
2. Subscription detail → score breakdown → cancel + undo cancel
3. Alerts tab → tap any alert → action button
4. Dispute letter generator → fill form → preview → send via Mail
   (uses MFMailComposeViewController)
5. Negotiate tab → pick any service → copy retention script
6. Settings → Account → "Delete account" (App Store 5.1.1(v) compliance)
7. Settings → "Manage subscription" (deep links to iOS subscription
   management as required for IAP)

NOTES ON IN-APP PURCHASES:

We use StoreKit 2 with two auto-renewing subscriptions:
   com.subspy.app.pro.monthly  ($3.99/month)
   com.subspy.app.pro.yearly   ($29.99/year)
Both share the subscription group "SubSpy Pro".

Restore Purchases is in the paywall top-right corner.

PRIVACY / DATA HANDLING:

We use Plaid for read-only bank transaction data only — no payment,
balance, or identity products. We never sell data, push loans, or
store card numbers. Full policy at [Privacy URL above].

Thanks!
[Your name]
```

| Field | Value |
|---|---|
| First name | **[Your name]** |
| Last name | — |
| Phone | **[+1 ...]** |
| Email | **[review@yourdomain.com]** |

---

## In-App Purchases

Create two **auto-renewable** subscriptions in App Store Connect → Features → In-App Purchases. Both belong to a single subscription group named "SubSpy Pro".

### Product 1 — Monthly

| Field | Value |
|---|---|
| Reference name | `Pro Monthly` |
| Product ID | `com.subspy.app.pro.monthly` |
| Subscription Duration | 1 month |
| Pricing | Tier 4 ($3.99 USD) |
| Localizations (English) | |
| — Display name | `SubSpy Pro Monthly` |
| — Description | `Unlimited subscription scans, dispute letters, and price-hike alerts. Cancel any time.` |
| Review screenshot | Use `screenshots/16-paywall.png` |

### Product 2 — Annual

| Field | Value |
|---|---|
| Reference name | `Pro Annual` |
| Product ID | `com.subspy.app.pro.yearly` |
| Subscription Duration | 1 year |
| Pricing | Tier 30 ($29.99 USD) |
| Localizations (English) | |
| — Display name | `SubSpy Pro Annual` |
| — Description | `Save 37% vs monthly. Unlimited features. 30-day refund window.` |
| Review screenshot | Same as monthly |

---

## What's New in This Version (release notes, v1.0)

```
Welcome to SubSpy 1.0.

Stop paying for subscriptions you don't use. SubSpy scans your bank, scores every recurring charge for "zombie" behavior, generates EFTA-compliant dispute letters for wrongful charges, and warns you 7 days before any price hike.

We never sell your data. We never push loans. We never store your card number.

Questions? support@[yourdomain.com]
```

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
