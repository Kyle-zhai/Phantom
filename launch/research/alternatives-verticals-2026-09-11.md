# cluster_health — sources (2026-09-11)

18 services across `health`, `fitness`, `meditation`, `mealKit`. Written from WebSearch
grounded on vendor/App Store sources plus direct iTunes Search API lookups for every
App Store URL (no numeric id was hand-typed). Most vendor sites (hims.com, forhers.com,
whoop.com, betterhelp.com, talkspace.com, ouraring.com) return 403/404 to a plain fetch,
so pricing came from WebSearch syntheses that themselves cite the vendor's own pricing
or FAQ page — noted per service below. `weightwatchers.com/us/plans` was the one
vendor pricing page that fetched directly and cleanly.

## Deliberately narrowed from the spec's candidate brandIds (24 -> 18)

The spec listed 24 candidate brandIds across the 4 kinds but capped the cluster at
14-18 services, so a subset was chosen per kind rather than force-fitting all 24:

- **health (6/6 kept)** — betterhelp, talkspace, hims, hers, one-medical,
  weight-watchers. All included; this kind had the most detailed spec guidance
  (insurance caveats), so full coverage seemed most valuable.
- **fitness (4/7 kept)** — whoop, oura, strava, classpass. Dropped **fitbit-premium**
  and **alo-moves** as their own top-level entries (see below); **nike-training-club**
  was deliberately kept out as a *service* for a schema reason, not a coverage one —
  see next section.
- **meditation (4/4 kept)** — insight-timer, waking-up, ten-percent-happier, balance.
  All included.
- **mealKit (4/7 kept)** — hellofresh, factor, home-chef, blue-apron. Dropped
  **marley-spoon**, **green-chef**, **cookunity** as top-level entries but folded
  **cookunity** in as a Factor alternative, and pulled in **everyplate** and
  **dinnerly** (not in the spec's candidate list, but real, verified, and the
  most useful "cheaper" edge for the meal-kit group) as alternatives instead.

## Nike Training Club: alternative, not a top-level service (deliberate)

The spec flags `nike-training-club` under fitness brandIds with "(free — a strong
free edge)". NTC has no paid tier at all — Nike has never charged for it — so it
would never produce a charge on a bank statement, which is what `statementDescriptors`
and this whole catalog are for. Rather than force an empty/fabricated statement
descriptor onto a service object, NTC is used exactly where the spec's own phrasing
points: as a `"edge": "free"` **alternative**, cited on ClassPass (its closest
same-job competitor — on-demand/studio-style workouts). Confirmed still free and
operating via its own live App Store listing (id301521403).

## fitbit-premium -> rebranded mid-2026

Searched to cite as a WHOOP/Oura alternative and found Fitbit Premium is being
retired as a brand name: the Fitbit app became "Google Health" on May 19, 2026,
with "Fitbit Premium" replaced by "Google Health Premium" at $9.99/mo (annual
$79.99 -> $99.99). Recorded as `google-health-premium` with the old name
parenthetically noted, confirmed independently by the App Store listing now
showing "Google Health (Fitbit)" (id462638897). Source:
https://www.ghacks.net/2026/05/10/fitbit-app-becomes-google-health-on-may-19-with-annual-subscription-price-increase/

## Per-service sources

- **betterhelp** — no fixed price; billed every 4 weeks, $70-100/week ($240-400/mo),
  set by location/therapist availability, not user choice. Confidence medium because
  of that variability. Also surfaced: BetterHelp began accepting some insurance
  (Cigna, UnitedHealthcare, Aetna, Optum) in select states starting Jan 2026 — noted
  in the tier, not modeled as a separate tier since coverage is regional.
  Sources: healthline.com/health/mental-health/betterhelp-review,
  therapyhelpers.com/blog/betterhelp-price-increase/.
- **talkspace** — 3 tiers cleanly reconstructed from weekly rates ($69/$99/$109) that
  a WebSearch synthesis attributed to talkspace.com's own pricing/blog pages (site
  itself 403'd to a direct fetch). Psychiatry pricing ($299 first visit/$175
  follow-up) added to the top tier's note rather than as a 4th tier since it's
  billed per-session, not monthly. Source: talkspace.com/blog/blog-how-much-talkspace-costs/
  (via search), choosingtherapy.com/how-much-does-talkspace-cost/.
- **hims / hers** — both marked confidence medium: pricing is genuinely per-product
  (hair/ED-or-skincare/GLP-1) and shifted materially in 2026. Confirmed via search
  that Hims settled with Novo Nordisk in March 2026 and stopped selling compounded
  semaglutide to new patients, moving to branded Wegovy/Zepbound only — this is
  called out explicitly in the weight-loss tier note since it changes the honest
  price a lot (compounded was materially cheaper). Hers's GLP-1 program mirrors the
  same $149/mo membership + separate medication structure. iTunes search confirmed
  the Hers app is published by "Hims, Inc. (CA)" — same parent company, cited in
  each other's alternatives as `"edge": "similar"`.
  Sources: telehealthally.com/guides/hims-complete-glp1-guide,
  formblends.com/articles/comparison-hub/hers-cost-2026.
- **one-medical** — high confidence; Amazon's own help page, onemedical.com press
  releases, and independent press (Bloomberg, TechCrunch) all agree: $99/yr first
  membership with Prime (up to 6/account, +$66/yr each), $199/yr standalone.
  Sources: amazon.com/gp/help/customer/display.html?nodeId=TjqvKqjxQH0HOams6s,
  onemedical.com/mediacenter/one-medical-amazon-prime-benefit/.
- **weight-watchers** — only service whose vendor page (weightwatchers.com/us/plans)
  fetched directly and cleanly. High confidence. 3 tiers (Core/Core+/Med+) as shown
  on the page.
- **whoop** — whoop.com's own support article ("Membership Pricing") and whoop.com/peak
  surfaced via search corroborate 3 tiers x monthly-or-annual billing. One
  statement-descriptor caveat: a "who charged me"-style site reported some WHOOP
  charges appear as "WHOOP DUBLIN 2 CO. IRL" (their Irish billing entity); kept
  `WHOOP`/`WHOOP.COM` as the descriptors since they're the safer general-purpose
  pattern, and deliberately did NOT use "WHOOP MOBILE"/"WHOOPMOBILE.COM" — those
  turned up in a chargeback-dispute context as a possibly different/confusable
  billing entity and using them risked mis-flagging a different service as WHOOP.
- **oura** — high confidence, consistent $5.99/mo, $69.99/yr across
  support.ouraring.com and independent trackers.
- **strava** — high confidence, strava.com/subscribe pricing corroborated by
  multiple trackers: $11.99/mo, $79.99/yr, $139.99/yr family.
- **classpass** — medium confidence: pricing is explicitly zip-code-dependent, and
  multiple sources flagged a Jan 1, 2026 restructuring to the current 25/48/68/100
  credit tiers. Pause/freeze policy (2-3 months, no charge, credits roll over)
  confirmed via ClassPass's own help center article.
- **insight-timer** — high confidence. Confirmed the free tier is 300k+ practices
  and explicitly NOT a time-limited trial (per Insight Timer's own support article),
  matching the spec's instruction to verify and call this out.
- **waking-up** — high confidence on price ($19.99/mo, $129.99/yr, $229.99/yr family)
  and the no-questions-asked scholarship (both corroborated by multiple sources);
  App Store id (1307736395) came directly from an apps.apple.com search hit.
- **ten-percent-happier** — medium confidence, flagged as the messiest naming
  situation in this cluster: the original "Ten Percent Happier" app is now "Happier"
  on the App Store (publisher "Happier Meditation, Inc"), while founder Dan Harris
  separately publishes a newer, different app called "10% with Dan Harris" (publisher
  "10 Percent Media LLC"). Kept the spec's brandId (`ten-percent-happier`) but set
  `name` to "Happier (formerly Ten Percent Happier)" and explained the split in the
  tier note so it isn't confused with Harris's newer app.
- **balance** — medium confidence. Confirmed maker is Elevate Labs (also matches the
  Google Play package id `com.elevatelabs.geonosis` seen in search results). The
  "first year free" promo is real and heavily advertised, but it's a promo, not a
  permanent free tier, so `priceMonthly`/`priceYearly` reflect the standard paid
  price with the promo caveat in the note per Hard Rule 5.
- **hellofresh / factor / home-chef / blue-apron** — all confidence medium by
  design: these are usage-priced, and `priceMonthly` is a computed "2 people,
  3 meals/week" (or Factor's "6 meals/week") realistic monthly total = per-serving
  price + weekly shipping, x4.33 weeks/month, shown in each tier's `note` so the
  math is auditable. Skip-week/pause support for HelloFresh and Blue Apron came
  directly from vendor-adjacent review sources; Home Chef and Factor's pause support
  is stated from general knowledge of standard meal-kit account settings (all four
  are structurally identical weekly-cutoff subscriptions) rather than a source
  fetched this session — flagged here rather than silently assumed.

## Alternatives sourced outside the spec's brandId lists

Verified real and operating via iTunes Search API + WebSearch, used only inside
`alternatives` arrays (never as top-level services): Open Path Collective (no app,
sliding-scale therapy directory), GoodRx, Cost Plus Drugs (Mark Cuban's pharmacy),
Amazon Prime, CVS MinuteClinic, MyFitnessPal, Apple Watch's built-in Health/Workout
apps (no App Store listing — it's a system app), Nike Run Club, Garmin Connect,
Google Health Premium (see rebrand note above), EveryPlate, Dinnerly, CookUnity,
Tasty (BuzzFeed's free recipe app), Peloton App. Swapped NYT Cooking out for Tasty
as the HelloFresh "cook it yourself" alternative — NYT Cooking's own pricing
(standalone vs. bundled into NYT All Access) wasn't independently confirmed this
session, and Tasty is unambiguously free with a verified live App Store listing.

## Nothing was dropped for failing to verify

Every one of the 18 chosen services confirmed as currently operating with a
checkable current price; none were dropped for going out of business or for
being unable to confirm a price (unlike, e.g., the sibling `cluster_watch` batch,
which dropped Amazon Freevee and Nebula for exactly those reasons).
# cluster_home.json — sources & curation notes

18 services: homeSecurity (4), auto (5), kids (4), retailMembership (5).
Budget note: WebSearch worked throughout this session (never actually exhausted), so
research below mixes direct vendor-page WebFetch with WebSearch-sourced corroboration.
Vendor pages that 404'd/403'd/timed out are called out per service; in those cases I
used review-site aggregation (mainly security.org, a generally reliable, frequently
updated source) and cross-checked against a second independent query before writing
a number down, then marked `"confidence": "medium"`.

## Why only 18 of the 26 brandIds named in the spec

The spec listed 8 homeSecurity + 6 auto + 6 kids + 6 retailMembership = 26 candidate
brandIds, but asked for a 14-18 service cluster total. I treated the brandId lists as
"things to cover accurately," not "all must be top-level services," and demoted the
weakest-fit or least-cleanly-priced ones to rich `alternatives` entries instead of
dropping them outright:

- **adt** — folded into `ring-home` and `simplisafe` alternatives (edge: similar).
  Kept out of the top level because ADT's flagship pro-install pricing is quote-based
  ("starts at $49.99/mo," scales with equipment); the cleaner numbers I found are for
  the newer ADT Blu self-setup line, which isn't really what "ADT" means to most users.
- **wyze**, **blink** — folded into `ring-home`, `nest-aware`, `arlo` alternatives
  (edge: cheaper). Both have clean, confirmed vendor pricing; they were cut from the
  top level purely for budget, not accuracy.
- **eufy** — used exactly as the spec asked: a `free`-edge alternative on all four
  homeSecurity services, with the yearly saving spelled out in `why`/`priceNote`
  (e.g., "saves $120-360/yr vs Arlo"). Not made a standalone service because its own
  paid tier (optional cloud backup) is secondary to the free-local-storage story.
- **aaa** — folded into `onstar` alternatives (edge: cheaper) rather than top-level,
  because AAA pricing is set per regional club (no single national number exists).
  Used the CalState club's 2026 published tiers as a representative figure and said
  so explicitly in the note.
- **khan-academy-kids**, and **pbs-kids** (not in the original brandId list, added
  because the spec called it out by name) — used exactly as instructed: `free`-edge
  alternatives on all four kids services, never top-level, since they have no paid
  tier to document.
- **noggin** — researched (standalone $7.99/mo or $69.99/yr, confirmed via two
  independent sources) but dropped entirely to stay in budget. It's video
  entertainment (closer to the video/liveTV kind already covered in the main
  catalog) rather than curriculum/reading, so it was the weakest fit for this
  cluster's "learning app" framing.
- **best-buy-plus** — dropped without research. Time went to getting the
  warehouse-club break-even framing right (the spec's specific ask) instead.

## homeSecurity

**ring-home** — `https://ring.com/protect-plans` fetched directly and returned a full,
current tier table (Solo/Multi/Pro/Virtual Security Guard with exact prices); used the
first three, dropped Virtual Security Guard ($99/mo) as a niche 4th tier not worth the
slot. Confidence: high.

**nest-aware** — Google's own product pages truncated/404'd through WebFetch. Used
PCWorld's Aug-2025 price-hike article (fetched directly), which states the exact new
numbers ($10/$20 per month, $100/$200 per year) and confirms the "Google Home Premium"
rebrand; cross-checked against a WebSearch summary citing the same figures. Confidence:
high (specific, dated, corroborated).

**simplisafe** — `simplisafe.com/home-security-monitoring` and other guessed URLs
404'd. Used `security.org/home-security-systems/simplisafe/` (fetched directly), which
listed six current tiers with exact prices; I kept the four most representative
(Self Monitoring free tier, Standard, Core/Fast Protect, Pro) and dropped the
self-monitor-with-camera ($9.99) and Pro Plus ($79.99) tiers to stay within the 4-tier
limit. Confidence: medium (review site, not simplisafe.com itself).

**arlo** — `arlo.com` subscription pages 404'd repeatedly. Used
`security.org/security-cameras/arlo/` (fetched directly) plus a WebSearch that returned
matching numbers independently (Secure Plus $7.99/$17.99 annual-equivalent, Premium
$24.99 annual-equivalent). Confidence: medium.

Alternatives sourced from: `https://www.wyze.com/products/cam-plus` (direct fetch,
Cam Plus $2.99/mo/camera, Cam Unlimited $9.99/mo confirmed),
`https://www.security.org/security-cameras/eufy/` (direct fetch: free local storage
via HomeBase/microSD confirmed, optional cloud $2.99 Basic / $9.99 Premier),
`https://www.adt.com/pricing` (403, so used security.org's ADT page instead, which
gives the ADT Blu self-setup tiers: $9.99/$14.99 self-monitor, $24.99/$34.99
professionally-monitored, plus "Pro Install starts at $49.99/mo").

## auto

**mister-car-wash**, **take-5-car-wash**, **zips-car-wash** — none of the three
vendor sites show a price without a zip code (genuinely location-based pricing), so
`mistercarwash.com/join-unlimited-wash-club/` and `zipscarwash.com/` were fetched
directly to confirm tier *names* and *features* (both succeeded), and the actual
*numbers* come from WebSearch queries that were cross-checked against 2+ independent
car-wash review/aggregator sites returning matching figures (Mister: Base $22.99,
Titanium $39.99; Zips: Clean It $14.95, Protect It $34.95; Take 5: found via
`take5carwash.com` — note the correct domain is take5carwash.com, NOT take5.com,
which is the unrelated Take 5 Oil Change site and was a dead end early on). All three
are marked `"confidence": "medium"` and each tier `note` says pricing is
location-set. Cancel-path notes (in-app/in-person, no phone/online self-cancel) are
from the same review sources and are consistent across all three chains.

**tesla-premium-connectivity** — `tesla.com/support/connectivity` returned 403.
Used `notateslaapp.com` (a Tesla enthusiast reference site with a dedicated,
frequently-updated pricing page) via direct fetch: $9.99/mo or $99/yr, confirmed
unchanged for the US as of the article's most recent update. The free Standard
Connectivity downgrade (nav, updates, safety features, no live traffic/streaming) is
documented on Tesla's own support content surfaced through search. Confidence: medium.

**onstar** — `onstar.com/plans` and `public-safety.onstar.com` both failed (403/503).
Used `gmauthority.com` (a GM-focused trade/enthusiast site) which published the full
2025-model-year tier table (Connect $9.99, Connect Plus $19.99, Safety & Security
$22.99, OnStar One $34.99/$349.99yr); did not find a second independent confirmation
for every tier, so this is `"confidence": "medium"` and I only used the tiers I felt
were solid (dropped "Super Cruise add-on $25/mo" as not a base plan).

**aaa** (alternative only) — `ampauto.io` and a broader WebSearch agree AAA is priced
per independent regional club, not nationally; used the CalState club's 2026 published
numbers (Classic $64.99/yr) as the representative figure and said explicitly in
`priceNote` that it varies $60-165/yr by club.

## kids

**abcmouse** — `abcmouse.com/pricing` 404'd. Used a WebSearch that surfaced
`support.abcmouse.com`'s own pricing-options article title/summary (Monthly $14.99,
Annual $45 first-year promo renewing at $59.99/yr standard, 6-month $29.99 — dropped
the 6-month tier, kept the two clean recurring options). The abcmouse.com support
domain returned 403 on direct fetch so this is corroborated via search summary only.
Confidence: medium.

**epic-books** (Epic!) — `getepic.com/pricing` 404'd;
`support.getepic.com/hc/en-us/articles/204259899-How-much-does-Epic-Family-cost`
(Epic's own help-center article) appeared in search and its title/URL match exactly
what was asked, but the direct fetch 403'd, so the $13.99/mo, $84.99/yr figures are
from the WebSearch summary of that same official page, not a raw fetch. Noted Epic's
free-for-teachers program (Epic School) in the tier note since it's a real, relevant
free path for the same content, just not available for personal/home use. Confidence:
medium.

**lingokids** — `lingokids.com/pricing` 404'd; `help.lingokids.com` (Lingokids' own
billing-FAQ) 403'd on direct fetch. Used the WebSearch summary of that same page:
Monthly $13.49, Annual $71.88/yr. Sanity-checked the annual figure against itself
(71.88 / 12 = 5.99, matching a separately-quoted "$5.99/mo" figure in the same search
results), which is why I trust it despite the noisy source page. Confidence: medium.

**homer** — `learnwithhomer.com/pricing/` 404'd. Used a WebSearch aggregating HOMER's
publicly listed options (Monthly $12.99, 6-month $49.99, Annual $59.99, lifetime
$99.99); kept the three recurring options, dropped the one-time lifetime plan since
it doesn't fit the `priceMonthly`-as-recurring-cost schema. Confidence: medium.

**khan-academy-kids** / **pbs-kids** (alternatives only, used on all four kids
services) — confirmed genuinely free (no ads, no IAP, no premium tier) via
`khanacademy.org/kids/schools-districts` and `blog.khanacademy.org` for Khan Academy
Kids (nonprofit, 501(c)(3)), and `help.pbs.org` + `pbskids.org/apps/pbs-kids-video`
for PBS Kids. Both are the strongest, cleanest "free" edges in this whole cluster —
confidence: high.

## retailMembership

**costco** — `costco.com/membership.html` timed out. Used
`fool.com/investing/2026/01/16/costco-gold-star-members-upgrade-executive-3-perks/`
(Motley Fool, fetched via search, cites the actual Sept 2024 increase to $65/$130 —
first increase in seven years, which is a specific enough detail that I trust it).
Confidence: high.

**sams-club** — `samsclub.com/membership` fetched directly and returned exact,
current tiers including the live Jul-Sep 2026 promo pricing. Confidence: high.

**bjs** — `bjs.com/membership` 403'd on direct fetch. WebSearch results were
inconsistent about tier *names* (some sources say "Club"/"Club+", older ones say
"Inner Circle"/"Perks Rewards" — these look like stale scrapes of a prior naming
scheme) but converged on the same *numbers* ($60/$120/yr) as the more recent
sources, which also line up with Sam's Club's identical $60/$120 structure. Used
Club/Club+ as the tier names and flagged the legacy naming in the tier note.
Confidence: medium.

**cvs-carepass** — Vendor pages required login/didn't expose pricing cleanly; used
two independent WebSearch queries (`querysprout.com`, `thekrazycouponlady.com`) that
agree exactly: $5/mo or $48/yr, $10/mo in ExtraBucks rewards, rebranded to "CVS
ExtraCare Plus." Added the free ExtraCare base loyalty tier as the `free`-edge
alternative. Confidence: medium.

**target-circle-360** — Confirmed via `target.com/help/articles/target-circle/about-
target-circle-360` (Target's own help article, surfaced through search) and
`thekrazycouponlady.com`: $10.99/mo standard, $99/yr annual, discounted $4.99/mo
($49/yr) for Circle Card holders / verified students / teachers / military. Added the
free Target Circle loyalty tier as a `free` edge, and Amazon Prime / Walmart+ as
`bundle`/`similar` edges since both already exist in the main catalog as bundles
(`amazon-prime`, `walmart-plus` — confirmed by reading
`Phantom/Resources/alternatives.json` directly rather than re-verifying their
pricing, since the spec says not to re-add already-catalogued items).

## App Store URLs

All `appStoreURL` values were pulled from `itunes.apple.com/search` (via curl) and
verified as real app names/ids returned by Apple's own API — none were typed from
memory. A few services have no confirmed single "official app" (OnStar's app is
split across per-brand GM apps like myChevrolet; Tesla Premium Connectivity has no
separate app from the main Tesla app which wasn't a clean fit as an "alternative"
listing; AAA's regional clubs each run variants) — those `appStoreURL` fields are
`null` rather than guessed.
# Sources & decisions — dating / socialMedia / creatorSupport cluster (2026-09-11)

General method: iOS App Store listing pages were confirmed via the iTunes Search/Lookup API
(`itunes.apple.com/search`, `/lookup`) and fetched directly for in-app-purchase price points.
Vendor pricing pages were fetched where they were publicly reachable; many dating apps and
several social apps return 403/404 to automated fetches or gate pricing behind login/region/age,
so third-party aggregator pages (cross-checked across 2+ independent sources where possible) were
used and every affected service is marked `"confidence": "medium"`. No price was invented from
memory alone without at least one corroborating source found this session.

## Dating

All six dating apps use **dynamic pricing by age and location**, which is not published on any
single canonical page — this is itself the reason every dating-app entry is `confidence: medium`
and every tier `note` spells out the observed range rather than a single number. Per the spec's
callout, iOS in-app pricing runs higher than web checkout for several of these (confirmed
explicitly for Telegram Premium and reported for Bumble/X); noted in each tier where seen.

- **tinder**: App Store listing (id 547702041) showed raw IAP price points ($9.99-$24.99 range).
  Cross-checked against https://www.datingapps.com/cost/tinder/ (1/6/12-month ladder) and a
  general web-search rollup citing $24.99/$39.99/$49.99 as "standard" 1-month Plus/Gold/Platinum
  with 6-month terms at $16.66/$23.33/$29.99. Used the higher "standard" figures as priceMonthly
  since most zombie subscribers are on month-to-month auto-renew, not a 6-12 month prepay; noted
  the lower age-discounted range and the term discount in each tier's `note`. `help.tinder.com`
  and `tinder.com` pricing pages both blocked automated fetch (403/404).
- **hinge**: `hinge.co/subscription` 404'd. Pricing from search rollup (Hinge+ "$29.99/mo... varies
  $14-32/mo"; HingeX "$49.99/mo for a single month"). Statement descriptor "HINGE.CO" is an
  inference from the company's own domain (Match Group's exact billing descriptor for Hinge
  wasn't confirmed) — flagged medium confidence, single entry per "omit guesses."
- **bumble**: `bumble.com/en-us/premium` fetched but had no pricing in the rendered text; used
  https://www.datingapps.com/cost/bumble/ (Premium $29.99 1-month / $59.99 3-month / $99.99
  6-month, "no sales ever") plus a search rollup noting iOS in-app runs $32.99-39.99 due to App
  Store fees — both folded into the tier `note`. Statement descriptors (BUMBLE.COM, BUMBLE
  HOLDING) were corroborated by two independent consumer "what's this charge" sites.
- **grindr**: `grindr.com/xtra` and `/unlimited` both 404'd. Used the App Store listing's own IAP
  price points (XTRA $22.99/$14.99; Unlimited $44.99/$27.99; Day Pass $9.99) as the primary
  source since it's first-party (Apple-hosted, vendor-submitted), cross-checked against a search
  rollup citing Unlimited "~$39.99/mo, $299.99/yr" as a ballpark. Descriptor "GRINDR LLC" seen on
  a consumer bank-statement-lookup site.
- **match**: Numbers were the most inconsistent of the six across sources ($18.99-$42.99 depending
  on commitment length). Used the App Store IAP listing's $42.99 1-month price point as
  priceMonthly and noted the $18.99-23.99/mo range for 6-/12-month prepay in `note`. Statement
  descriptor "MATCH.COM" is an inference (own-domain convention), not directly observed.
- **coffee-meets-bagel**: App Store id corrected mid-session — an old `id630119301` surfaced in
  one search result but fails a US `itunes.apple.com/lookup` (delisted/stale); confirmed
  `id6502307144` ("Coffee Meets Bagel: Dating App") is the live app (`currentVersionReleaseDate`
  2026-09-02). CMB's own Zendesk help article on Premium vs. Platinum 403'd; used a search rollup
  with a clean 1/3/6/12-month ladder ($34.99/$74.99/$119.99/$179.99) plus the App Store's own
  Platinum IAP price points ($46.99-$54.99 1-month, $99.99 3-month).

Cross-cutting alternative: **OkCupid** (free, unlimited messaging, Match Group-owned, confirmed
`Free` in its own App Store listing metadata) is used as the "free" alternative for all six dating
services since it's a genuine, verifiable, currently-operating free option in the same category.
**SCRUFF** and **Feeld** (both confirmed live on the App Store) round out Grindr's alternatives for
the LGBTQ+-specific and open-relationship-adjacent angles respectively. Plenty of Fish was looked
up (App Store id 389638243, confirmed live) but not used in the end — OkCupid already covers the
"free Match-Group option" angle without duplicating it across every entry.

## Social media

- **x-premium**: `help.x.com/en/using-x/x-premium` 403'd. Search rollup gave Basic $3/mo ($32/yr),
  Premium $8/mo ($84/yr), Premium+ $40/mo ($395/yr), consistent with the well-known 2026 price
  ladder and multiple aggregator citations; medium confidence since the vendor page itself
  couldn't be fetched directly. Descriptor "X CORP" (current) / "TWITTER INC" (legacy, still seen
  on un-refreshed recurring charges) both corroborated by a dedicated statement-descriptor site.
- **linkedin-premium**: `linkedin.com/premium/products` redirected to a login wall. Search rollup:
  Career $39.99/mo new-subscriber ($29.99/mo grandfathered), $239.88/yr; Business $69.99/mo new
  ($59.99/mo grandfathered), $539.88/yr — both from `premium.linkedin.com` copy quoted in search
  results. Noted LinkedIn's free CLEAR-based identity-verification badge (confirmed via LinkedIn's
  own help center, `linkedin.com/help/linkedin/answer/a1458457`) in the Career tier's note since
  it's a genuine free alternative to confusing "verified" with "paid."
- **reddit-premium**: `reddit.com/premium` is blocked for automated fetch entirely (tool-level
  restriction). Search rollup: $5.99/mo, $49.99/yr — consistent across multiple sources including
  a piece specifically about Reddit's ad-free upsell. Descriptor is an inference (medium
  confidence); genuine third-party alternatives are scarce since most competing Reddit clients
  (Apollo, RIF) shut down after the 2023 API pricing change and are correctly excluded per the
  "never recommend a shut-down product" rule — used Brave's built-in ad-blocking and Discord
  community migration instead, both real and currently operating.
- **discord-nitro**: Fetched `discord.com/nitro` directly (vendor's own page) — Nitro Basic
  $2.99/mo, Nitro $9.99/mo confirmed first-party. Annual figures ($29.99/yr, $99.99/yr)
  cross-checked via search since the vendor page only showed monthly.
- **snapchat-plus**: `snapchat.com/plus` (marketing page) and `accounts.snapchat.com/plus/plans`
  (checkout page) both returned no usable pricing text to WebFetch. Search rollup: $3.99/mo,
  $39.99/yr, consistent with the original 2022 TechCrunch launch price never having changed.
  (A few low-quality SEO/content-farm results also claimed a new 2026 "Platinum" tier around
  $10/mo; not corroborated by any primary or reputable source, so it was deliberately **not**
  added as a second tier.)
- **meta-verified**: Fetched `meta.com/meta-verified/` directly (post-redirect from
  `about.meta.com`) — first-party. Standard $14.99/mo/profile (web; mobile app historically
  higher), plus Plus/Premium/Max ($49.99/$149.99/$499.99) which read as a 2026 professional/business
  tier ladder layered on top of the original consumer product. Included Standard and Plus as the
  two tiers most relevant to an individual's "did I forget I'm paying for this" use case; Premium
  and Max are mentioned in the Plus tier's note rather than added as full tiers, since a Phantom
  user paying $150-500/mo for this is an edge case not the target scenario.
- **telegram-premium**: `telegram.org/faq_premium` fetched directly (first-party) confirmed the
  feature list and confirmed **in-app/app-store pricing is higher than paying via @PremiumBot** —
  Telegram says so explicitly in its own FAQ — but doesn't publish a bare USD number on that page.
  Search rollup: $4.99/mo, $49.99/yr, corroborated by a second aggregator citing "$5.00/mo."

## Creator support

Per the task instructions, alternatives here lean on free tiers / free cross-posts / RSS rather
than inventing peer products, and Patreon/Substack/Ko-fi are modeled as **usage-priced** (the
creator sets the price, not the platform) — same treatment the spec asks for on meal kits. Their
`tiers` are illustrative "typical" price points with that caveat spelled out in every `note`, not
a single vendor-set price.

- **patreon**: `patreon.com/pricing` fetched directly (first-party) — confirmed Patreon takes
  "10% of the income you earn" from creators (their creator-facing pricing page states a flat
  10%; some legacy plans have 8%/12% tiers not shown on the current page) plus payment
  processing; page did not list patron-side tier examples, so the $3/$10/$25 illustrative ladder
  is drawn from common real-world creator tier conventions rather than a vendor number.
  Statement descriptor "PATREON* MEMBERSHIP" / "PATREON.COM" corroborated by two independent
  bank-statement-lookup sites.
- **substack**: `subscribe.substack.com/pricing` 404'd. Used
  `support.substack.com/hc/en-us/articles/360037607131-How-much-does-Substack-cost` (first-party,
  via search summary) confirming the 10% + ~2.9%+30¢ Stripe fee structure and that $5/mo is the
  common default with $8/mo the frequently-recommended "sweet spot." Also surfaced and included a
  genuinely important fact: **Substack lets each writer customize their own billing descriptor**,
  so a generic "SUBSTACK" match will miss many real charges — called out explicitly in the tier
  `note` since it affects the app's own detection reliability, not just the user's awareness.
- **twitch**: Modeled the `tiers` array on **channel subscriptions** (Tier 1/2/3: $4.99/$9.99/
  $24.99 — long-stable, fixed platform-wide prices, well corroborated including by a fresh 2026
  source), not Twitch Turbo, since channel subs are literally "pay to support one creator" —
  Turbo is a site-wide ad-free utility upsell with no specific creator attached, so it's
  cross-referenced in the Tier 1 note instead of used as the primary price (search rollup put
  current Turbo at $11.99/mo web, up from its original $8.99 launch price). This is the one
  `"confidence": "high"` service in the whole cluster because the channel-sub ladder is extremely
  stable and multiply-corroborated. **Prime Gaming** (a free channel sub per month included with
  Amazon Prime) is used as the `bundle`-edge alternative, cross-linked to the catalog's existing
  `prime-video` brandId per the spec's encouragement to cross-link.
- **medium**: `medium.com/membership` 403'd. Used
  `help.medium.com/hc/en-us/articles/115004545567-Become-a-Medium-Member` (first-party, via
  search) confirming $5/mo or $50/yr, described as "one of the fairest subscriptions in digital
  media" with stable historical pricing — high confidence.
- **ko-fi**: `ko-fi.com/gold` 404'd. Search results disagreed on Ko-fi Gold's exact price ($6/mo
  vs. $12/mo across two sources) — since Gold is a **creator-side** tool subscription (lowers
  Ko-fi's cut on shop/membership sales to 0%), not what a Phantom user (a supporter) would be
  charged, it was deliberately left out of the `tiers` (which model the fan-facing membership
  price a supporter actually pays, same usage-priced treatment as Patreon/Substack) and mentioned
  only qualitatively, without a specific number, in the `note`. Confirmed via the iTunes Search
  API that **Ko-fi has no official iOS app**: the only "Ko-fi"-adjacent App Store result is an
  unofficial third-party client ("KOFI," id 1582783748, published by an unrelated individual
  developer, not Ko-fi's own company) — `appStoreURL` is `null` for this reason, not merely
  "unverified."

## Dropped / not added

- **Plenty of Fish** (App Store id 389638243, confirmed live, Match Group-owned) — researched as a
  possible dating alternative but not used in the final file; OkCupid already covers the "free
  Match-Group-owned option" for every dating entry without repeating the same two options six times.
- A rumored 2026 Snapchat "Platinum" tier (~$10/mo) — surfaced only on low-quality SEO aggregator
  sites with no primary-source or reputable corroboration, so it was not added as a second
  Snapchat+ tier.
- Third-party Reddit apps (Apollo, Reddit is Fun) — both shut down after Reddit's 2023 API pricing
  change and are correctly excluded as alternatives per the "never recommend a shut-down product"
  rule, even though they'd otherwise be an obvious "cheaper/free" pick for reddit-premium.
# cluster_watch — sources (2026-09-11)

Written from two research passes that verified vendor pricing pages, App Store in-app-purchase listings and Apple's iTunes Search API.

**Dropped deliberately:**
- Amazon Freevee — shut down 3 September 2025, content folded into Prime Video's free tier. Confirmed by Wikipedia, a TechCrunch article quoting Amazon, and a negative result from Apple's own search API.
- Nebula — nebula.tv is a client-rendered app that returned no pricing to any fetch, and its App Store listing shows eight different active price points with no tier names (legacy creator-supporter pricing). Rather than guess, it is left out until a price can be read in a browser.

**Verified with caveats (confidence: medium):**
- BritBox — britbox.com blocks automated fetches. Prices come from the App Store purchase list and a secondary source that agree: $10.99/mo, $109.99/yr, $149.99/yr Premier.
- CuriosityStream — the site is client-rendered. Basic and Standard show the identical $5.99 in the App Store listing, which reads like a retained legacy product id.
- MagellanTV — App Store shows both $5.99 and $6.99 monthly; $6.99 is consistent with the quarterly and annual figures, so that is what is recorded.
- Hallmark+ — hallmarkplus.com timed out; price from the App Store listing, rebrand confirmed on Wikipedia.

**Kanopy and hoopla:** both are free through a participating library, with monthly play or borrow limits that each library sets for itself. No universal number exists, so the catalog says the limit comes from your library rather than citing a figure.

**The Roku Channel:** there is no dedicated iOS app. Its content is reached through the general Roku app or the website, and the App Store link reflects that.# cluster_money — sources (2026-09-11)

18 services: 7 finance, 6 security, 5 email. Researched via direct vendor-page fetches
(WebFetch + a real Chromium session for JS-rendered pricing pages), WebSearch for pages
that resisted fetching, and Apple's iTunes Search API for every App Store URL (no numeric
id was invented — every `appStoreURL` came back from a live `itunes.apple.com/search` or
`/lookup` call). Every URL in the final JSON was re-checked with a plain `curl` status pass
at the end; all resolve except two Forbes/FreeTaxUSA pages that block curl's user agent but
were already read successfully through the live browser session (see below).

## Finance

- **YNAB** — ynab.com/pricing (direct fetch): $14.99/mo, $109/yr, 34-day trial, student program.
- **Copilot Money** — copilot.money/pricing (direct fetch): $95/yr ($7.92/mo). Vendor page
  doesn't publish a separate non-annual monthly price, said so in the tier note rather than guessing.
- **Monarch Money** — monarchmoney.com redirects (301) to monarch.com; read live via browser
  since WebFetch returned no numbers on first pass. Core $99.99/yr, Plus $199.99/yr, both
  $99.99/$199.99 confirmed on-page along with the 7-day trial. Site now brands as just "Monarch";
  kept the brandId/display name `monarch-money` per the task spec.
- **Rocket Money** — marketing site and help.rocketmoney.com (vendor help center, direct fetch)
  confirm the mechanics factually: "sliding scale" premium price with no published number, and
  a bill-negotiation success fee of exactly 35–60% of first-year savings. Since there's no fixed
  price to report, `priceMonthly` is a representative $9.99 with the range spelled out in the
  note and `confidence: medium` on the service.
- **Quicken Simplifi** — quicken.com/simplifi (direct fetch): standard $6.99/mo billed annually,
  current promo $3.99/mo.
- **TurboTax** — turbotax.intuit.com/personal-taxes/online/deluxe.jsp (direct fetch) confirmed
  Free ($0) and Deluxe ($79 federal + $39/state). Premium ($139 federal) came from a WebSearch
  synthesis, not a page I fetched myself directly, so overall service confidence is `medium`
  even though two of the three tiers are vendor-verified.
  - **Dropped as an alternative: IRS Direct File.** Checked its status specifically before citing
    it and found it was discontinued — the IRS told partner states in November 2025 that Direct
    File "will not be available" for the 2026 season (Federal News Network, Kiplinger, Forbes,
    NSTP all agree). Used **IRS Free File** instead (irs.gov, direct fetch, confirmed live for
    2026, guided software free ≤$89,000 AGI, free fillable forms at any income) — a different,
    still-operating program.
  - Cash App Taxes' "$0 federal + $0 state, no income cap" claim is from a WebSearch synthesis
    (Forbes Advisor, Yahoo Finance) rather than a page I fetched directly — cash.app doesn't
    expose a static pricing page for it — so it's `confidence: medium`.
- **Morningstar Investor** — morningstar.com/products/investor returned a 500 error both times
  it was fetched (screenshot confirmed: "This isn't working, but it's not your fault"). Pricing
  ($34.95/mo, $249/yr, ~$199 first-year promo, $25 student) is a WebSearch synthesis of several
  independent trackers that agreed with each other; `confidence: medium` throughout.

## Security

- **Norton 360** — us.norton.com/products (direct fetch), the non-LifeLock antivirus line:
  Standard $39.99 first year / $94.99 renewal (3 devices), Deluxe $49.99 / $124.99 (5 devices).
  Kept separate from the `lifelock` entry below since they're different product lines on the
  same us.norton.com site.
- **McAfee+** — mcafee.com/antivirus.html, read live via browser (WebFetch timed out twice):
  Essential $39.99→$119.99, Premium $49.99→$149.99, Advanced $89.99→$199.99 (arrow = first
  year → standard renewal, both shown on the same pricing card).
- **LifeLock** — lifelock.norton.com/plans (direct fetch): standalone identity-protection tiers
  Core $124.99/yr, Advanced $199.99/yr, Ultimate Plus $349.99/yr renewal, each with a lower
  first-year rate. This is the identity-monitoring product line; Norton 360 with LifeLock
  bundles also exist but weren't used as the primary entry.
- **Aura** — aura.com/pricing (direct fetch): Individual $15/$12, Couple $29/$22, Family $50/$32
  (month-to-month/annual), 14-day trial, 60-day money-back on annual.
- **Bitdefender Total Security** — bitdefender.com/en-us/consumer/individual (direct fetch)
  confirms only the first-year price ($59.99, 5 devices) — the page explicitly says the renewal
  price is "the applicable renewal price" without stating it. WebSearch on the renewal figure
  produced two different numbers from different trackers ($89.99 vs $99.99); used the more
  commonly cited $99.99/yr and flagged it clearly as medium-confidence in both the tier note and
  the service-level `confidence`.
- **DeleteMe** — joindeleteme.com/pricing/ read live via browser (the plan toggle is
  JS-driven, WebFetch only saw placeholders). Clicked through Single/Couple/Family × 1yr/2yr:
  Single 1-person/1-year is a flat $129/yr with no strikethrough "was" price shown; Family
  4-people/1-year is $329/yr discounted on-page from a $43/mo list rate. Only used the two
  cleanest data points (Single, Family) rather than all eight toggle combinations.
- **Credit freeze is free — verified and led with.** consumer.ftc.gov (direct fetch):
  "There's no cost to place or lift a credit freeze, and it doesn't affect your credit score."
  Used as the lead alternative for both `lifelock` and `aura`.
- **Malwarebytes** — cited only as an alternative (Norton/McAfee/Bitdefender), never as a
  top-level service. malwarebytes.com blocked both WebFetch (truncated) and the browser session
  (navigation denied), so the $44.99/yr figure is a WebSearch synthesis of several independent
  trackers that agreed; `confidence: medium` on every alternative that cites it.
- **Incogni** — incogni.com/pricing (direct fetch), very clear vendor copy: standard monthly
  billing is $15.98/mo, annual prepay drops it to $7.99/mo ($95.88/yr) — used as the "cheaper"
  alternative to DeleteMe rather than as its own top-level entry (it's the same job as DeleteMe,
  and 14–18 services meant picking one to feature).
- **California DROP** — privacy.ca.gov/drop/ (direct fetch, state government site) confirms a
  free, official tool for requesting deletion from all data brokers registered with the state
  at once. Used as the free alternative to DeleteMe.

## Email

- **Fastmail** — fastmail.com/pricing/ (direct fetch): Individual $6/$5, Duo $10/$8,
  Family $14/$11 (month-to-month/annual), plus 24/36-month multi-year discounts.
- **Proton Mail** — proton.me/mail/pricing read live via browser (WebFetch saw only template
  placeholders). Free $0, Mail Plus $4.99 standard/$3.99 annual ($47.88/yr), Proton Unlimited
  $12.99 standard/$9.99 annual ($119.88/yr) — all read directly off the comparison table.
- **HEY** — hey.com/pricing/ (direct fetch): flat $99/yr for HEY for You, no monthly option;
  HEY for Domains is $12/user/mo ($10/mo for the first user).
- **Tuta** — tuta.com/pricing, read live via browser; the page served Chinese-localized copy
  and EUR pricing (Free €0, Revolutionary €3/mo, Legend €8/mo, both billed annually) rather
  than a US/USD version. Converted to USD via a WebSearch cross-check (~$3/mo and ~$8.99/mo,
  ~$34.99/yr for Revolutionary), so the USD figures are approximate and the service is marked
  `confidence: medium`. The EUR figures observed directly on the vendor page are the real
  ground truth; said so in the tier notes rather than presenting the USD numbers as exact.
- **SimpleLogin** — simplelogin.io/pricing/ (direct fetch): $4/mo or $36/yr, and the page
  itself now states Premium includes Proton Pass premium features — Proton owns SimpleLogin.
  Cross-checked against Proton's own pricing page, which lists "Unlimited hide-my-email
  aliases" under Proton Unlimited, confirming the bundle claim independently.
- **Hide My Email / iCloud — corrected mid-research.** First pass wrote "free with any Apple
  ID," which is only true for the narrow Sign-in-with-Apple relay. Checked Apple's own
  iCloud+ guide directly and it states plainly that the general-purpose Hide My Email feature
  (the actual SimpleLogin equivalent — mint a masked address for anything) requires an
  iCloud+ subscription: "When you subscribe to iCloud+, you can generate unique, random email
  addresses with Hide My Email." Recategorized iCloud's edge from `free` to `bundle`
  everywhere it's cited, and added **Firefox Relay** (relay.firefox.com, direct fetch: free
  tier is real but capped at 5 masks) as the genuinely free alternative for SimpleLogin instead.

## Deliberately dropped

- **IRS Direct File** (see TurboTax above) — discontinued for the 2026 filing season.
- **Credit Karma and Empower** as top-level services — both are effectively free products
  (Credit Karma monetizes via lending referrals, Empower's dashboard is free with paid wealth
  management sold separately). Neither fits "a subscription you're paying for and might drop,"
  so both appear only inside other services' `alternatives` (medium confidence — empower.com's
  own dashboard/pricing page 404'd this session; the "free, no subscription" claim is a
  WebSearch synthesis of empower.com/tools plus several independent reviews that agreed).
- **Seeking Alpha and QuickBooks** — on the finance brandId list but cut to stay inside the
  14–18 range; Morningstar was kept instead since it exercises the "no investment advice"
  instruction directly and had a cleaner (if third-party) pricing trail.
- **H&R Block** as a TurboTax alternative — hrblock.com returned 403 to every fetch attempt
  this session and I didn't have a verified current price to put in `priceMonthly`, so it was
  left out rather than guessed. FreeTaxUSA, Cash App Taxes and IRS Free File already cover the
  free/cheaper end well.
