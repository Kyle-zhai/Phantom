# App Store Review — Pre-Flight Checklist

Common rejection reasons for finance apps, mapped to the actual code in this repo.

| Guideline | Risk | Fix in Phantom |
|---|---|---|
| **2.3.1** — Accurate metadata | Medium | App Store screenshots must show *real* in-app screens, not mockups. Use the ones in `ios-native/screenshots/` taken on iPhone 17 Pro simulator. |
| **2.3.10** — Don't include placeholders | High | Remove "Lorem ipsum"-style demo content from the marketing copy. Marketing copy in `launch/store/APP_STORE_LISTING.md` is final. |
| **3.1.1** — In-App Purchase required for digital content | **Very high** | Pro subscription **must** be via StoreKit 2 (it is). Do not route users to an external payment page. The "Restore Purchases" button is in the paywall top-right. ✅ |
| **3.1.2(a)** — Auto-renewing subscription metadata | High | Display title, length, and price near the CTA. Disclose "Auto-renews. Cancel any time in Settings." We do this. ✅ |
| **3.1.3(b)** — Reader Apps exception N/A | N/A | We are not a reader app — IAP is the only way to upgrade. ✅ |
| **4.2** — Minimum functionality | Low | App offers core value (subscription scan, score, dispute letter) free without Pro. ✅ |
| **5.1.1(i)** — Data collection disclosed | High | App Store Privacy Labels must match the Privacy Policy exactly. Use the mapping below. |
| **5.1.1(v)** — Account deletion in-app | **Very high** | Settings → Account → "Delete account & data" with confirmation. Deletes local SwiftData and the user's private CloudKit records, then signs out. ✅ Implemented. |
| **5.1.2** — Sharing data with third parties | High | Privacy Policy names Apple (IAP, Sign in with Apple, private CloudKit) and GitHub (public catalog hosting). Phantom has no backend, advertising, or analytics SDK. |
| **5.1.4** — Children | Low | Age gate 18+ via app icon settings rating (4+ in the App Store but ToS limits to 18+). |

---

## App Store Privacy Labels (Apple's required disclosures)

Apple asks you to declare each data category. Fill in App Store Connect → App Privacy as follows.

| Category | Used? | Linked to user? | Used for tracking? | Purposes |
|---|---|---|---|---|
| **Financial Info — Other Financial Info** (transactions) | No | — | No | Processed on-device or in the user's private iCloud; not collected by Phantom |
| **Contact Info — Email Address** | No | — | No | Optional Sign in with Apple value stays on-device/private iCloud |
| **Contact Info — Name** | No | — | No | Stored on-device/private iCloud only |
| **Identifiers — User ID** | No | — | No | Apple sign-in identifier is not sent to a Phantom server |
| **Usage Data — Product Interaction** | No | — | No | No analytics SDK |
| **Diagnostics — Crash Data** | No | — | No | No third-party crash SDK |
| **Diagnostics — Performance Data** | No | — | No | No third-party performance SDK |

Categories we do **NOT** collect (be explicit — selecting "Data Not Collected" reduces friction):

- Health & Fitness
- Sensitive Info
- Contacts
- User Content (photos, video, audio, gameplay)
- Browsing History
- Search History
- Identifiers — Device ID / Advertising ID
- Purchases (other than via App Store-mediated IAP, which Apple handles)
- Location (precise or coarse)
- Other Data Types

---

## Tracking transparency (App Tracking Transparency)

Even though we do not track, we must declare it:

- "Does this app track users?" → **No**
- We never call `ATTrackingManager.requestTrackingAuthorization()`. Our Info.plist still includes `NSUserTrackingUsageDescription` for compliance — but it's a "we don't track" string, not an opt-in prompt.

---

## Other common rejection patterns

### 1. No bank-link flow

✅ Phantom does not connect to banks or include a bank-link SDK. Users add data manually or explicitly import a screenshot, statement image, or CSV file. OCR runs on-device.

### 2. Dispute letters that imply legal advice

❌ **Don't** say "we will resolve your dispute" or "100% refund guarantee". Use language like "Generate a letter you can send to ...". Our copy already does this. ✅

### 3. Pricing claims that aren't substantiated

❌ **Don't** promise "save $47/month" as a guarantee. Our copy says "average Pro user saves $47/month — Pro pays for itself in week one." This must be substantiated; before launch, replace with "Based on our internal estimates" or remove until you have real usage data.

⚠️ **Action needed before submission**: replace "Most Pro users save $47/month on average. Pro pays for itself in week one." in `PaywallView.swift` with either real measured data or a softer claim. Suggested copy:

```
"Pro pays for itself the first time it catches a charge you would have missed. Average users save $20–$60 per month."
```

### 4. Fake reviews / testimonials

❌ Don't include user quotes you haven't received from real users. Don't include them yet.

### 5. Subscription downgrade / cancellation

✅ Settings → "Manage subscription" calls `.manageSubscriptionsSheet(...)` which is Apple's deep link into iOS system Settings. Required for IAP apps.

### 6. Restore Purchases visibility

✅ Top right of `PaywallView`. Required by guideline 3.1.1.

### 7. Import disclosure

✅ Onboarding and import screens state that Phantom never asks for bank credentials and that Apple Vision OCR runs on-device.

### 8. Demo data + bank-connect optional

✅ Users can continue without an account and use sample data, so App Review can inspect all core flows without credentials or personal documents.

---

## Crash-resistance checks

Before submission run:

```bash
xcodebuild -project ios-native/Phantom.xcodeproj \
  -scheme Phantom \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Release \
  build
```

Should output `** BUILD SUCCEEDED **`. Then run smoke flows:

1. Launch → onboarding → "Skip — demo data" → all 4 tabs load
2. Subscription detail → cancel → confirm dialog → undo
3. Dispute letter → form → preview → "Send via Mail" (Mail.app opens with prefilled body)
4. Negotiate → tap any vendor → script visible → copy works
5. Settings → "Delete account" → confirm dialog appears
6. Paywall → both products load (requires Xcode-driven launch, not simctl) → tap "Restore"
7. Background the app for 1 minute, foreground — state persists via SwiftData

---

## TestFlight before submission

Distribute via TestFlight to ≥ 5 testers (yourself + 4 others) for 2–7 days:
- Screenshot/CSV import using non-sensitive test data
- StoreKit purchase ($0.99 sandbox account)
- Real dispute email send
- Sign-out, sign-in across devices

App Review will sometimes ask "have you tested this with real users?" — TestFlight is your proof.
