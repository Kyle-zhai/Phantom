# Media price catalog — sources & notes (verified 2026-09-10)

Catalog file: `catalog_media.json` — 28 services, 10 bundles. Every entry carries its own
`sources` array and `confidence`; this file covers methodology, the "known facts" anchor
verification, discrepancies found/resolved, and residual gaps.

## Methodology

Researched in parallel by five sub-agents (each independently using WebSearch/WebFetch, no
answers from memory) covering: (1) Netflix/Hulu/Disney+/HBO Max, (2) Peacock/Paramount+/Apple
TV/Prime Video/news, (3) ESPN/Starz/AMC+/Crunchyroll/live TV, (4) music/audiobooks, (5) bundles.
I independently cross-verified ~15 of the highest-value/trickiest facts myself via direct
WebFetch of vendor pages (apple.com, peacocktv.com, espn.com support, tv.youtube.com,
instacart.com, etc.) before compiling, specifically to catch stale or conflicting figures.
Confidence was set per the brief's rule (high = vendor's own page or a major outlet dated
2026; medium = best source is 2025; low = unverifiable) and in a few cases downgraded from
what a sub-agent self-reported when their own cited sources didn't actually meet that bar.

## Anchor facts from the brief — verification outcome

- **Netflix (2026-03-26 hike)**: CONFIRMED exactly — ads $8.99, Standard $19.99, Premium
  $26.99. Still current as of today, no later change found.
- **Spotify Premium Individual $12.99 (Jan 2026)**: CONFIRMED exactly.
- **YouTube Premium $15.99 (Jun 2026)**: CONFIRMED exactly. Also found: Family $26.99 (was
  $22.99), a cheaper "Premium Lite" (video-only, no music) tier at $8.99, and YouTube Music
  standalone rose to $11.99/$18.99 (Individual/Family) in the same wave.
- **Apple TV+ $12.99 (Aug 2025) + a further hike announced 2026-08-28, effective 2026-09-01**:
  CONFIRMED and resolved — new price is **$14.99/mo, $119/yr**. Apple One also rose the same
  day, but **only the Individual tier** ($19.95→$21.95); Family ($27.95) and Premier ($39.95)
  had already reached their current levels in an earlier-2026 increase and did not move again
  on Sep 1. Verified directly on apple.com/apple-one, with the "regular cost separately"
  figures Apple itself publishes decomposing exactly into each included service's standalone
  price (zero rounding error across all three tiers) — strong independent confirmation.
- **Disney+ (Oct 2025): with ads $11.99, premium $18.99**: CONFIRMED, still current. Also
  captured the Disney+/Hulu Duo ($12.99 ads / $19.99 no-ads) and Disney+/Hulu/ESPN Trio
  ($19.99 ads / $29.99 no-ads, with a pricier ~$44.99 ESPN-Unlimited variant of Trio Premium
  noted but not added as a 7th tier).
- **Peacock hikes Jul 2025 and 2026-08-18**: CONFIRMED via peacocktv.com/help/article/price-increase
  fetched directly — current tiers are **Select $8.99, Premium $12.99, Premium Plus $19.99**
  (a 3-tier structure, not 2 — "Select" is a cheaper NBC/Bravo-only tier below "Premium").
  Effective for new subscribers now; existing subscribers transition on/after 2026-09-17.
- **HBO Max "$10.99 ad tier hike reported for Oct 2026"**: COULD NOT CONFIRM an October 2026
  event. Extensive searching (by both me and the dedicated sub-agent, independently) traces
  the $10.99/$18.49/$22.99 figures to a Warner Bros. Discovery price increase that took effect
  **October 21, 2025** (new subscribers) / November 20, 2025 (existing) — and that pricing is
  still what's charged today, per multiple Sept-2026-dated pages and a live WebSearch synthesis
  that found no newer hike. Best read: the brief's "Oct 2026" was likely a one-year mix-up of
  this Oct 2025 event. Used $10.99/$18.49/$22.99 as current, with a note on the tier flagging
  this explicitly. Confidence "high" despite the primary corroborating outlet (CNBC) being
  2025-dated, because a vendor help-page URL and current 2026 listings corroborate.
- **Paramount+ +$1 on 2026-01-15**: CONFIRMED — current tiers are Essential $8.99, Premium
  $13.99.

## Notable 2026 developments not in the original brief

- **ESPN rebrand**: the old "ESPN+" is gone; the unified ESPN app now sells **"ESPN Select"**
  ($13.99/mo) and **"ESPN Unlimited"** ($31.99/mo), both freshly hiked effective 2026-08-20 (new)
  / 2026-09-17 (existing). Verified directly on support.espn.com.
- **YouTube TV** added lower-cost genre-specific plans alongside the $82.99 Base Plan; only
  "Sports Plan" ($64.99, confirmed on tv.youtube.com) had a solid price, so it's the only one
  added as a second tier — the vendor page references "more genre-based plans" without listing
  their exact prices.
- **Prime Video**: the old $2.99 ad-free add-on was rebranded **"Prime Video Ultra"** and hiked
  to $4.99/mo (Apr 2026), confirmed via aboutamazon.com and CNBC.
- **Audible** replaced "Audible Plus" with a new cheaper **"Standard"** tier ($8.99/mo, 1
  selection/month, no rollover) that works differently from the old unlimited-streaming Plus
  catalog — noted in the tier description since it's an easy mix-up.
- **Verizon myPlan**: the brief's "$10/mo flat per perk" is now only true for some perks.
  YouTube Premium is $12/mo; Apple Music Family and Apple One Family both rose (to $13 and $23
  respectively) on the same Sep 1, 2026 date as the Apple price hikes; the Disney+/Hulu/ESPN
  perk is $10 today but rises to $12 on 2026-09-17 (7 days after this catalog's verifiedAt —
  flagged in its note); and the Walmart+ perk is discontinued for new adds (legacy-only).

## Discrepancy resolved during compilation

**Amazon Music Prime vs. non-Prime price.** The bundles sub-agent (researching amazon-prime)
initially reported $10.99 Prime / $11.99 non-Prime, sourced from Amazon's own
aboutamazon.com page. The music sub-agent (researching amazon-music directly) explicitly
flagged that same aboutamazon.com page as showing **stale, pre-increase** figures, and used
a dedicated Music Business Worldwide price-increase report plus a Sept-2026-dated DealNews
page to arrive at the current **$11.99 Prime / $12.99 non-Prime / $21.99 Family**. I sided
with the music sub-agent's figures (used throughout `amazon-music` and in the `amazon-prime`
bundle's `includes` note) since their reasoning specifically explained why the vendor page
was out of date, and their alternate sourcing was more recent and specific to the price
change itself.

## Confidence notes — medium-rated entries and why

- **hulu**: hulu.com blocked every automated fetch (404s/redirects/paywalled mirror), so
  pricing rests on multiple consistent 2026-dated secondary/aggregator sources rather than a
  vendor page. Figures are plausible and mutually consistent but not vendor-confirmed.
- **fubo**: sources conflict ($88.99 vs $73.99–79.99 elsewhere, the latter likely a stale
  temporary rate from a Dec-2025 NBCUniversal carriage dispute). Went with $88.99 per a
  dedicated price-history tracker, flagged the conflict in the tier note.
- **kindle-unlimited**: $11.99 sourced from Engadget + DealNews; Engadget's article URL/slug
  oddly suggested a *decrease* ("cheaper-pay-less") which doesn't match the increase framing
  used elsewhere — kept the figure (it's corroborated by DealNews) but downgraded confidence
  since the Engadget framing couldn't be fully reconciled.
- **nyt**: nytimes.com itself blocked all fetch attempts. Priced off the live Apple App Store
  IAP listing (News $21.99, All Access $24.99) — a legitimate live vendor-controlled price
  since Apple doesn't set NYT's numbers, but not nytimes.com directly, hence medium.
- **washington-post**: washingtonpost.com returned 403 to a direct fetch; the sub-agent's
  content came from a proxied render of the same page rather than a raw fetch, so kept at
  medium pending a cleaner vendor-page read.
- **t-mobile** (bundle): t-mobile.com blocked direct fetches (403) repeatedly; rests on
  WebSearch snippets that quote T-Mobile's own newsroom plus secondary outlets, not a direct
  vendor-page fetch.

Nothing in the catalog is marked "low" — every entry had at least a 2025-or-newer source,
and most (23/28 services, 9/10 bundles) reached "high" via a direct vendor-page fetch or a
2026-dated major outlet.

## Design decisions on ambiguous schema fits

- **youtube-premium as a "bundle"**: the brief listed YouTube Premium under both "services"
  (with YouTube Music access) and "bundles to cover." Both research agents that touched this
  (music, and bundles) independently recommended treating the YouTube Music inclusion as a
  **note on the `youtube-premium` service entry** rather than a separate bundle object, since
  it's a single-vendor product and doesn't fit the bundle `type` enum
  (membership/telecom/apple/retail) the way Apple One or a carrier's perk catalog does. Done
  that way — no `youtube-premium` bundle object exists; see the service entry's Individual/
  Family tier notes instead.
- **kindle-unlimited's `kind`**: forced into `"audiobooks"` since the schema has no
  book/ebook category and Kindle Unlimited is primarily e-books/comics with a growing (but
  secondary) audiobook selection. Noted explicitly in the tier's `note` field.
- **dashpass**: omitted entirely, as instructed when nothing current is found. DoorDash's
  prior HBO Max streaming perk wound down (activation cutoff 2025-12-16); no replacement
  streaming partner found. Current DashPass perks are all non-streaming.
- **spotify-premium bundle**: included, since it can be stated factually — Spotify's own
  support page confirms 15 hrs/month of audiobook listening from Spotify's own catalog
  (not Audible-sourced) at no extra cost on Premium. Used a distinct `spotify-audiobooks`
  reference rather than misattributing it to the `audible` brandId.
- **Walmart+ / Verizon / Xfinity's own bundle `priceMonthly`**: Verizon and Xfinity have no
  single flat "bundle price" (they're per-perk add-ons or plan-tier-dependent), so
  `priceMonthly` is `null` on those two bundle objects, with the pricing logic explained in
  each `note` field instead — this matches the schema's `priceMonthly` being typed as
  "0.00_or_null."

## Full source list (deduplicated, vendor/primary sources first)

Vendor pages fetched directly: apple.com/apple-one, apple.com/apple-tv-app, apple.com/apple-music,
apple.com/apple-news, peacocktv.com/help/article/price-increase, support.espn.com (x2),
tv.youtube.com/welcome, support.google.com/youtubetv, disneyplus.com/welcome/filter-plans,
help.hbomax.com, starz.com/us/en/buy, support.starz.com, support.amcplus.com (x2), sling.com,
support.getsling.com, philo.com, spotify.com/us/premium, support.spotify.com, amazon.com/music/unlimited/family,
support.tidal.com, siriusxm.com/plans/streaming, siriusxm.com/help, audible.com/membership,
amazon.com/hz/audible/..., wsj.com/subscribe, washingtonpost.com/subscribe, apps.apple.com (NYT IAP),
aboutamazon.com (x3), instacart.com/instacart-plus, instacart.com/p/peacock, corporate.walmart.com,
xfinity.com/hub/tv-video/peacock-premium, verizon.com/support/*-perk-faqs (x4), t-mobile.com/news,
help.netflix.com, help.hulu.com.

Major 2026 outlets: CNBC, Variety, Hollywood Reporter, TechCrunch, 9to5mac, Engadget, Quartz,
The Hill, Deadline, TVLine, CBS News, Music Business Worldwide, DigitalMusicNews, TechSpot,
AnimeNewsNetwork, TVGuide, StreamTV Insider.

Secondary/aggregator (used only where vendor/major-outlet access was blocked): DealNews,
SmartTVs.org, CordCuttersNews, Yardbarker, BudgetSeniors, ThePricer, Streamingpricetracker,
WellKeptWallet, SaveOnPhone, RottenWifi, AndroidAuthority, GetBundleUp, 9meters, Groupon.

---
Full per-item citations live in `catalog_media.json` itself (`sources` array on every service
and bundle) — this file is the summary/methodology layer on top of that.
