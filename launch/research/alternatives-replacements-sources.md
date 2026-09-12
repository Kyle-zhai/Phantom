# Replacements data — sources & methodology notes

Compiled 2026-09-10/11 via live WebSearch (no prices written from memory). Full
citation URLs are embedded per-entry in `replacements.json` (`sources` array);
this file gives the methodology, category source clusters, and caveats.

## Method

1. Ran ~35 WebSearch queries clustered by category (password managers, creative,
   music, video, live TV, fitness, news, VPN, AI assistant, AI coding, cloud
   storage, productivity, learning, meditation, delivery, audiobooks) to pull
   September 2026 pricing from vendor pages, 2026 buyer's-guide roundups, and
   tech-press price-hike coverage.
2. Cross-checked conflicting figures (e.g. Duolingo Super, YouTube TV base plan)
   against a second query before picking the figure used.
3. Where only a promotional/introductory rate was findable (most newspaper
   subscriptions), I searched specifically for the **standard renewal rate**
   and used that instead, since intro pricing isn't representative.
4. Ran targeted `apps.apple.com` searches for the ~20 most-reused alternatives
   (VPNs, delivery apps, live-TV apps, Libby/Everand/Libro.fm, Insight Timer,
   Nike Training Club, Pixelmator Pro, Pluto TV) and only filled `appStoreURL`
   when a real apps.apple.com link was returned by search — 33/205 entries
   have a verified link; the rest are `null` rather than guessed IDs.
5. Built the JSON via a validated Python script (`build_replacements.py` in
   this same folder) that asserts: no service recommends itself, edge is one
   of free/cheaper/better/bundle, priceNote ≤ 40 chars, why ≤ 90 chars,
   confidence is high/medium/low, and every entry has non-empty sources.
   Final run: 63/63 services, 205 alternative entries, 0 validation errors.

## Key figures used (high-confidence, vendor/major-outlet sourced)

- **Password managers**: 1Password $2.99/mo, Bitwarden free (Premium $19.80/yr),
  NordPass from $2.99/mo, Dashlane $4.99/mo (free tier retired Sept 2025),
  Proton Pass free tier confirmed.
- **Creative**: Affinity (Photo/Designer/Publisher) went **fully free** under
  Canva ownership — a major 2025–2026 market shift, used as the top "free" pick
  for all three Adobe entries.
- **Music**: Spotify $12.99, Apple Music $11.99, YouTube Music $11.99, Amazon
  Music $10.99 (Prime), Tidal $11.99 (post Aug-2026 hike).
- **Video**: Netflix Standard-with-Ads $8.99, Disney+ (ads) $11.99, Hulu (ads)
  $11.99, Max (ads) $10.99, Peacock Select $8.99, Paramount+ Essential $8.99,
  Prime Video (ads) $8.99, Apple TV+ $14.99, Starz $11.99, AMC+ $10.99,
  Crunchyroll Fan $9.99, ESPN Select (=ESPN+) $13.99. Philo's $35 tier
  confirmed to bundle Max/Discovery+/AMC+ add-ons.
- **Live TV**: YouTube TV base $82.99 (verified against a stale $72.99 figure
  from an older cached article — used the more recent, more specific source),
  Sling $45.99, Fubo Pro $88.99, Philo $25.
- **News**: NYT All Access standard $25/mo, WaPo standard ~$12/4wk, WSJ
  standalone digital $38.99/mo, Apple News+ $12.99/mo (confirmed to include
  most WSJ content — used as a "cheaper" pick for the wsj entry specifically).
- **VPN**: NordVPN from $3.49/mo, ExpressVPN from $4.99/mo, Proton VPN from
  $2.99/mo with a genuine unlimited-data free tier, Mullvad flat ~€5/mo.
- **AI assistants**: ChatGPT Plus / Claude Pro / Perplexity Pro all $20/mo;
  Google AI Pro (Gemini) $19.99/mo and bundles 2TB storage; Microsoft Copilot
  has a genuinely free web/app tier.
- **AI coding**: GitHub Copilot Pro $10/mo, Cursor Pro $20/mo, Windsurf Pro
  $20/mo (hiked from $15 in March 2026).
- **Cloud storage**: Google One 100GB $1.99/2TB $9.99, iCloud+ 50GB $0.99/2TB
  $9.99, Dropbox 2TB $9.99 (annual).
- **Productivity**: Microsoft 365 Personal $99.99/yr, Google Workspace Starter
  $7/user/mo, Notion Plus $10/seat/mo.
- **Fitness**: Nike Training Club fully free, Peloton App One $15.99/mo,
  Apple Fitness+ $9.99/mo, Planet Fitness Classic from $15/mo, WeightWatchers
  Core from $23/mo (cheaper than Noom's ~$59–70/mo).
- **Delivery**: DashPass / Uber One / Grubhub+ all $9.99/mo ($96/yr); Walmart+
  $98/yr (bundles Paramount+).
- **Audiobooks**: Audible Standard $8.99/mo, Kindle Unlimited $11.99/mo, Libby
  free with a library card, Everand $11.99/mo, Libro.fm $14.99/mo.

## Caveats / lower-confidence spots

- **noom → MyFitnessPal** is the only `low`-confidence entry — MyFitnessPal's
  current price wasn't independently re-verified this session (its free tier
  claim is solid; the paid-tier figure omitted from `priceNote` to avoid
  overstating confidence — priceMonthly is 0 for the free tier used).
- **Tidal, Duolingo, WSJ, Washington Post, Everand, NordPass, Mullvad**: search
  results gave a spread of numbers (regional/promo variance); I used the
  figure most consistent across 2+ independent sources and marked confidence
  `medium`.
- **appStoreURL**: only filled where a real apps.apple.com link was returned
  by a search this session (33 of 205 entries). Left `null` everywhere else
  rather than guess numeric app IDs — several well-known apps (ChatGPT,
  Gemini, Netflix, Spotify, Dropbox, Notion, etc.) are legitimately available
  on iOS but their exact App Store URLs weren't independently confirmed this
  session.
- Prices reflect standalone/base tiers as of September 2026 and will drift;
  `updatedAt` is stamped 2026-09-10 per the task spec.
