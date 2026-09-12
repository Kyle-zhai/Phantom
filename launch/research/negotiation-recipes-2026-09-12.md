# Negotiation recipes — coverage sweep and sources (2026-09-12)

Playbooks in `ios-native/Phantom/Services/Negotiation.swift`, surfaced by the Negotiate tab
and `NegotiateDetailView`. This pass added 17 community-sourced playbooks, 5 billing-descriptor
aliases, and an explicit "we looked and found nothing repeatable" list, so a missing recipe now
reads as a decision instead of an oversight.

Written from the citations each recipe carries in its own `tips`. The URLs below are recorded as
cited in the code; this pass did not re-fetch them. Anything sourced from a forum or a single
post stays flagged `estimated: true`, which is what makes the detail view print the
"estimate from public reports" disclaimer.

## Counts after the sweep

| Quantity | Value |
|---|---|
| Recipe entries | 64 |
| Alias ids resolving to one of them | 5 |
| Ids with a brand-specific playbook | 69 |
| Ids researched and left on the generic script | 32 |
| Audited universe | 101 |
| Brand ids the taxonomy recognises | 307 |

The **audited universe** is the `BrandRegistry.byId` logo table plus every `MockData`
subscription id. It is deliberately narrower than the 307 ids the taxonomy knows: the generic
script is a legitimate answer for the long tail, and holding 307 ids to a documented search
would make the list unmaintainable without making the product better. Every id inside the
audited universe must be in exactly one of the two lists, and both guards below enforce that.

## New playbooks

Rate is the shipped `successRate`. The three entries with an explicit rate are self-service or
widely-reported paths; the other 14 use the 35% default that `addCommunityRecipe` applies until
Phantom has first-party outcomes.

| id | Rate | Offer | Saving model | Source |
|---|---|---|---|---|
| `hellofresh` | 68 | Cancel-flow offer or ~30% comeback discount | 30% of one month, × 0.75 confidence | reddit.com/r/hellofresh/comments/12yhwo4, /zbtgwx, /wg8fv5 |
| `ring-home` | 91 | Ring Solo $4.99/mo for one device | gap to $4.99 × 12 | ring.com/plans; reddit.com/r/Ring/comments/ywp4vt, /1fodhxl, /1am58ns |
| `tinder` | 54 | Targeted 50% off Gold for one month | 50% of one month | reddit.com/r/Tinder/comments/15sbxh8, /q7y2k8 |
| `apple-tv` | 35 | Targeted $5.99/mo for 2 months | gap to $5.99 × 2 | 9to5mac.com/2025/08/24/apple-tv-plus-secret-discount-offer-when-cancel/ |
| `amc-plus` | 35 | Cancel-flow renewal or ~$2/mo comeback | gap to $2 × 2 | lowermysubs.com/lower/amc_plus |
| `sling` | 35 | Targeted 50% off the first month back | 50% of one month | lowermysubs.com/lower/sling_tv |
| `youtube-tv` | 35 | $50/mo for 2 months, or $10/mo off for 6 | better of the two cohorts, floor $60 | tech.yahoo.com/streaming/deals/articles/youtube-tv-quietly-drops-66-051311737.html |
| `tidal` | 35 | Targeted 50% off for 3–6 months | 50% × 3 months | lowermysubs.com/lower/tidal |
| `pandora` | 35 | Targeted 50% off for 3 months | 50% × 3 months | lowermysubs.com/lower/pandora |
| `walmart-plus` | 35 | Targeted $49 annual renewal | annual cost minus $49 | doctorofcredit.com/ymmv-walmart-renewal-for-49/ |
| `kindle-unlimited` | 35 | Return offer, sometimes 3 months for $0.99 | 3 months minus $0.99 | offthefrontpage.com/many-subscriptions-quietly-offer-discounts-when-you-try-to-cancel/ |
| `grubhub-plus` | 35 | Activate the Grubhub+ benefit included with Prime | full year × 0.75 confidence | lowermysubs.com/blog/grubhub-plus-retention-offer |
| `lovable` | 35 | Unlisted Lite plan in the downgrade flow | 50% × 3 months | linkedin.com/posts/yaakov-carno_woah-i-just-went-to-cancel-my-lovable-subscription-activity-7421560847413547008-BrBE |
| `att` | 35 | Account-specific Loyalty credit | 10% × 12 months | dbstalk.com/answers/how-do-i-contact-at-t-loyalty-department/ |
| `verizon` | 35 | $10–$20 per line or a percentage Loyalty offer | 10% × 12 months | droid-life.com/2026/08/17/verizon-loyalty-discount-hits-25-off-how-to-get-it/ |
| `proton` | 35 | Support retention offer, or downgrade to Proton Free | full year | discuss.techlore.tech/t/cancelled-my-proton-unlimited-sub-they-still-charged-me/9267 |
| `runway` | 35 | Downgrade to Free after spending expiring credits | full year | recurdash.com/guides/how-to-cancel-runway |

### Saving-model conventions

An unconditional action the user controls alone claims the full year: ending a paid plan for a
free tier, as with Proton and Runway. A conditional or account-specific offer does not.

- **Conditional on something Phantom cannot verify** carries a confidence discount. Grubhub+
  only replaces the paid membership for someone who already pays for Prime, so it claims 75% of
  the year rather than all of it. HelloFresh uses the same 0.75 factor on its comeback discount.
- **Account experiments and targeted offers** are scoped to the months the reports describe,
  not annualised. Lovable's Lite plan rests on a single public report, so it claims a quarter.
- **Telecom loyalty credits** use a flat 10% for a year, below the $10–$20 per line and 10–25%
  figures the forums report, because those depend on lines, plan, and a real competitor quote.
- Nothing may claim more than the subscription costs in a year. `NegotiationTests` asserts it.

## Aliases

Billing descriptors and renamed products that used to fall through to the generic script even
though a researched playbook existed under another id.

| Descriptor id | Resolves to |
|---|---|
| `adobe` | `adobe-cc` |
| `anthropic` | `claude` |
| `openai` | `chatgpt` |
| `paramount-plus` | `paramount` |
| `proton-vpn` | `proton` |

All five are ids the normalizer or the registry can actually produce, so each alias is
load-bearing rather than defensive.

## Researched generic fallbacks

`Negotiation.researchedGenericFallbackIds` — 32 branded ids we searched and left on the generic
script. Both guards read this one list, so the command-line check and the test suite cannot
disagree.

- **Billing descriptors whose product cannot be inferred** (3): `amazon-digital`,
  `apple-services`, `google-play`. A charge that says only `APPLE.COM/BILL` names no vendor to
  negotiate with, so the app routes these to the Apple or Google cancel path instead.
- **No repeatable product-specific offer found** (29): `amazon-music`, `apple-arcade`,
  `apple-fitness`, `apple-news`, `apple-one`, `apple-passwords`, `bitwarden`, `bolt`, `cohere`,
  `crunchyroll`, `dashpass`, `deepseek`, `espn-plus`, `fubo`, `gemini`, `google-workspace`,
  `huggingface`, `instacart-plus`, `lyft-pink`, `microsoft-365`, `mister-car-wash`, `mistral`,
  `philo`, `prime-video`, `starz`, `suno`, `uber-one`, `v0`, `youtube-music`. Platform-billed
  Apple and Google products have no agent to ask; the AI and developer-tool subscriptions are
  self-serve with published tiers and no retention desk.

The generic script is honest about this: it opens with "Phantom doesn't have a verified
retention playbook for X yet" and then gives the four universals.

`mister-car-wash` stays in the `MockData` sample stack on purpose, so the demo shows a vertical
with no known offer rather than implying every charge is negotiable.

## Guards

Both enforce the same three rules: every audited id carries a coverage decision, the fallback
list never goes stale, and no recipe id is stranded behind a key nothing produces.

```bash
xcodebuild test -project ios-native/Phantom.xcodeproj -scheme Phantom \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PhantomTests/NegotiationTests
```

```bash
cp tools/check_recipe_coverage.swift /tmp/main.swift && swiftc -o /tmp/recipe_check /tmp/main.swift \
  ios-native/Phantom/Services/{MerchantNormalizer,BrandRegistry,Negotiation,MockData,MerchantML}.swift \
  ios-native/Phantom/Models/Models.swift ios-native/Phantom/Theme/Theme.swift \
  -framework Foundation -framework SwiftUI && /tmp/recipe_check
```

## Maintenance

- Adding a brand to the logo table adds it to the audited universe, so it needs either a
  playbook or a line in the fallback list with a search behind it.
- Replace an estimated rate with a measured one only once Phantom has about 50 first-party
  outcomes for that vendor, then drop `estimated` so the disclaimer disappears.
- Never promise an offer a source only reports as targeted. The tips say "reports" and
  "varies by account" because that is what the evidence supports.
