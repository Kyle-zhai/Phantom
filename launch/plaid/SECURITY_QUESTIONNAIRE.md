# Plaid Production Application — Security Questionnaire

> Plaid asks these questions during their compliance review. Copy/paste the answers into their dashboard form. Edit anything in **[brackets]**.

---

### Company & contact

| Question | Answer |
|---|---|
| Legal name | **[YOUR LEGAL ENTITY NAME]** |
| DBA | SubSpy |
| Company website | **[https://subspy.com]** |
| Privacy policy URL | **[https://subspy.com/privacy]** |
| Terms of service URL | **[https://subspy.com/terms]** |
| Primary contact (compliance) | **[YOUR NAME, your-email@subspy.com]** |
| Country of incorporation | **[USA — Delaware]** |
| Year founded | **[2026]** |

### Use case

**Question: Describe your use case for Plaid in one paragraph.**

> SubSpy is a US-only personal-finance app that helps consumers identify and cancel unused subscriptions. We use Plaid's `transactions/sync` endpoint to read users' recent recurring charges from their checking/credit accounts. We do **not** use Plaid for payments, money movement, account verification, identity verification, or any product other than transaction read. Users connect their bank explicitly through Plaid Link, can disconnect at any time, and can delete their account permanently from within the app. We never share user data with third parties (including data brokers, advertisers, or lenders), and we never offer or recommend financial products.

**Plaid products requested**:
- ☑ Transactions
- ☐ Auth, Balance, Identity, Income, Investments, Liabilities, Assets, Signal, Transfer (not used)

**Estimated volume in year 1**: **[~10,000 users / month]**

### Data handling

| Q | A |
|---|---|
| Where do you store Plaid access tokens? | **iOS Keychain** on the user's device with `kSecAttrAccessibleAfterFirstUnlock`. Server-side mirror is encrypted with **AES-256-GCM** and protected by **[describe your KMS — e.g., AWS KMS managed keys with quarterly rotation]**. |
| Do you store transaction data on your servers? | Yes — encrypted at rest with **AES-256**. Retained for **24 months** then automatically deleted. Users can request immediate deletion via Settings → Account → Delete account, which triggers a backend purge within 30 days. |
| Where are your servers located? | **[Vercel — US East regions]**. |
| How do you transmit data? | TLS 1.3 for all client↔server and server↔Plaid. HSTS enabled. No data over plaintext HTTP. |
| Do you share Plaid data with third parties? | **No third parties** except: (1) Plaid itself, (2) our hosting provider **[Vercel]** which acts as a data processor under a DPA. We do not share with advertisers, data brokers, lenders, or marketing partners. |
| Do you sell user data? | **No.** This is a stated commitment in our Privacy Policy and a core product positioning vs. competitors like Rocket Money. |
| How do you handle user-deletion requests? | (a) User taps "Delete account" in app → (b) Backend calls Plaid `/item/remove` to revoke our token → (c) All user rows in our DB are deleted within 30 days → (d) Confirmation email sent. |
| Do you offer to opt out of future data sharing? | We do not sell or share data, so opt-out is N/A. Privacy Policy explicitly states this. |

### Security controls

| Control | Implementation |
|---|---|
| At-rest encryption | AES-256 (transport via TLS 1.3) |
| Token storage | iOS Keychain (user device) + AES-encrypted server vault |
| Access control | Production database accessible only by named SREs via SSO with hardware key 2FA |
| Audit logging | All access to user data logged with actor, timestamp, action |
| Backups | Daily encrypted snapshots, retained 30 days, restored in isolated environment |
| Vulnerability scanning | **[Snyk / GitHub Dependabot]** on every PR + monthly manual review |
| Penetration testing | **[Annual third-party pen test scheduled for Q3 2026]** |
| Incident response | Documented playbook with 72-hour breach notification commitment (GDPR-aligned) |
| Employee training | Mandatory annual data-privacy training; signed confidentiality agreements |
| Subprocessor inventory | Maintained at **[https://subspy.com/subprocessors]** — Plaid, Vercel, Apple, **[any others]** |
| SOC 2 / ISO 27001 | **[Planned — not yet certified. Will pursue SOC 2 Type 1 within 18 months of launch.]** |

### Authentication

| Q | A |
|---|---|
| How do users authenticate to your app? | **[Sign in with Apple]** (primary) or email + password with bcrypt-hashed (cost 12) credentials. |
| Do you support 2FA on user accounts? | Yes — Sign in with Apple inherits Apple ID's 2FA. For email accounts: TOTP via Authenticator apps available in Settings. |
| Session management | Server-issued JWT, 14-day rolling refresh; revoked instantly on account deletion or "log out everywhere". |

### Plaid Link configuration

| Q | A |
|---|---|
| Where is Plaid Link surfaced in your app? | Onboarding step 3 ("Connect a bank to begin") and Settings → Connected Accounts → "Add another bank". |
| Do you offer non-Plaid alternatives? | Yes — users can skip Plaid and use a "demo data" mode, or manually enter subscriptions. We never require bank connection for core app access. |
| Frequency of `/transactions/sync` calls | Once on first connect; thereafter once per 24h via a backend cron, and on-demand when the user taps Refresh. |

### Marketing & disclosures

| Q | A |
|---|---|
| How do you disclose Plaid to users? | Onboarding screen titled "Connect a bank to begin" explicitly names Plaid as the provider, describes data accessed, and links to Plaid's End User Privacy Policy. |
| Do you ever imply Plaid endorses your product? | No. We use the Plaid name and logo only as a factual disclosure of the integration. |
| Do you offer financial products (loans, credit cards, etc.)? | **No, and we have explicitly committed in our marketing not to.** This is a defining positioning of the product. |

### Compliance certifications

| Item | Status |
|---|---|
| GLBA Safeguards Rule | Compliant — see Privacy Policy and security controls above |
| CCPA / California | Compliant — Privacy Policy includes CCPA addendum; we do not sell data |
| GDPR / EU | Compliant — Standard Contractual Clauses for EU→US transfers, full data-subject rights |
| State financial regulations (NY DFS, etc.) | **[Verify with your counsel — typically subscription management is not a regulated activity, but confirm based on your state.]** |
