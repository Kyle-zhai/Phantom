# Phantom Privacy Policy

**Effective date: [DATE OF FIRST RELEASE]**
**Last updated: [DATE]**

> ⚠️ **Template — replace bracketed items before publishing.** Have a US-licensed attorney review before public release. Plaid and Apple App Review will read this carefully.

This Privacy Policy describes how **Yinan Zhai** ("**Phantom**", "**we**", "**us**", or "**our**") collects, uses, stores, and shares information when you use the **Phantom** iOS application and any related services (collectively, the "**Service**").

By using Phantom you agree to the data practices described here. If you do not agree, do not use Phantom.

---

## 1. Information we collect

### 1.1 Information you give us

- **Account information**: name, email address, password (stored as a salted hash).
- **Subscription preferences**: which alerts you turn on, which subscriptions you've cancelled, your ratings of services.
- **Disputes you generate**: the contents of any dispute letter you draft or send through Phantom.

### 1.2 Information collected via Plaid

We use **[Plaid Inc.](https://plaid.com)** as our bank-data provider. When you connect a bank account through Plaid Link:

- Your bank credentials (username / password / MFA codes) **never touch our servers**. They are entered into Plaid's interface and authenticated by your bank directly.
- Plaid returns an **access token** that we store, which lets us request read-only transaction data on your behalf.
- For each transaction we receive: **merchant name, amount, date, and Plaid's category labels**. We do **not** receive your full card number, account number, account balance, or transfer authority.

You can disconnect your bank at any time in the Phantom Settings → Account → "Disconnect bank" — this revokes the access token with Plaid and stops all future data pulls.

Plaid's own privacy practices are described at https://plaid.com/legal/#consumers.

### 1.3 Information collected automatically

- **Device information**: iOS version, device model (used to debug crashes).
- **Crash reports**: anonymous stack traces if Phantom crashes (via Apple's diagnostic system, opt-in at the OS level).
- **Aggregated, non-identifying usage**: which screens are opened, which features are used — used to improve the app.

We do **not** use third-party analytics SDKs that perform cross-app tracking. We do **not** use advertising identifiers. We are not, and will not be, members of the IDFA / Ad Network ecosystem.

### 1.4 Information we do **not** collect

- Your full credit card number or CVV.
- Your bank account number or routing number.
- Account balances or net worth.
- Browsing or location history.
- Contacts or photos.

---

## 2. How we use information

We use the information we collect only to:

1. **Detect recurring charges** in your transactions so we can show them to you.
2. **Compute Zombie Scores** indicating which subscriptions you're paying for but not using.
3. **Notify you** about price hikes, trial endings, and forgotten subscriptions.
4. **Generate dispute letters** at your request, using template language and your personal contact info.
5. **Provide retention negotiation scripts**.
6. **Operate, secure, and improve** the Service (debugging, fraud prevention, customer support).

We do **not** sell, rent, or share your information with advertisers, data brokers, or marketers for their commercial use.

We do **not** push, recommend, or pre-qualify you for loans, credit cards, or any other financial products. This is a core promise of the Service.

---

## 3. How we share information

We share information only as listed below:

### 3.1 With Plaid

To pull your transaction history. Plaid is a data processor acting on our (and your) behalf under their published privacy policy.

### 3.2 With Apple

Anonymous crash reports and App Store-mediated purchase data (Apple, not Phantom, processes your payment for Phantom Pro).

### 3.3 With hosting and infrastructure vendors

Our backend runs on **[VERCEL / AWS / your provider]**, which stores transaction data in encrypted form on our behalf. They are contractually prohibited from using your data for any other purpose.

### 3.4 With law enforcement

We will respond to lawful subpoenas, court orders, or other legally binding requests, but only to the extent legally required, and we will notify you unless prohibited by law.

### 3.5 With acquirers

If Phantom is acquired or merged, your information will transfer with the company. The acquiring party will be bound by terms no less protective than this policy.

We do **not** share information with any other category of recipient. In particular: **we do not share data with banks (other than your own), credit bureaus, lenders, insurers, or marketing platforms.**

---

## 4. How we store and secure information

- All data is encrypted in transit using TLS 1.3.
- Plaid access tokens are stored in the iOS Keychain on your device with `kSecAttrAccessibleAfterFirstUnlock` protection.
- Server-side databases are encrypted at rest using AES-256.
- Access to production data is limited to a small number of named employees who have signed confidentiality agreements.
- We perform routine vulnerability scanning and respond to disclosed security issues at **[yn.zhai0205@gmail.com]**.

---

## 5. How long we keep information

- Transaction data: 24 months from the most recent sync, then automatically deleted.
- Account profile: until you delete your account, then immediately wiped.
- Dispute letters you generate: stored only on your device unless you explicitly request server-side backup.
- Anonymized usage stats: 24 months, then automatically aggregated.

If you delete your account (Settings → Account → "Delete account"), we wipe everything within 30 days and request that Plaid revoke our access token to your bank.

---

## 6. Your rights

You have the right to:

1. **Access** the data we hold about you (email **[yn.zhai0205@gmail.com]**).
2. **Correct** inaccurate data.
3. **Delete** your account and all associated data at any time, directly in the app.
4. **Export** your data in a machine-readable format on request.
5. **Restrict or object** to certain processing.
6. **Disconnect your bank** at any time without deleting your account.

European, UK, and California users have additional rights under GDPR, UK-GDPR, and the CCPA respectively. To exercise these rights, email **[yn.zhai0205@gmail.com]**. We will respond within 30 days.

We will not retaliate against you for exercising any of these rights.

---

## 7. Children

Phantom is not directed at children under 13 (or 16 in the EU). We do not knowingly collect data from anyone in that age group. If you believe a child has provided data to us, contact us and we will delete it.

---

## 8. International transfers

Phantom stores data on servers located in the **United States**. By using the Service from outside the US, you consent to your data being transferred there. We rely on **Standard Contractual Clauses** for transfers from the EEA and UK.

---

## 9. Changes to this policy

We may update this policy. If we make a material change, we will notify you in-app and by email at least 30 days before the change takes effect. Continued use after the change constitutes acceptance.

---

## 10. Contact

**Yinan Zhai**
Address available on request — see email above.
Email: **[yn.zhai0205@gmail.com]**
Security: **[yn.zhai0205@gmail.com]**

For California consumers — Do Not Sell My Personal Information: we **do not sell personal information** as defined by the CCPA. If you wish to opt out of any future change, email **[yn.zhai0205@gmail.com]**.
