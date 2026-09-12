# Catalog sources & notes (verified 2026-09-10)

35 services + 8 bundles written to `catalog_tools.json`. Confidence: 19 high / 15 medium / 1 low (services); 7 high / 1 medium (bundles).

## Method
WebSearch for each service/bundle, then WebFetch of the vendor's own pricing page wherever it would load (succeeded for Apple, Google One, Dropbox, Microsoft, Notion, Adobe, 1Password, Bitwarden, Claude). Many vendor pricing pages actively block automated fetches with HTTP 403 (OpenAI, ExpressVPN ×2 URLs, NordVPN, Uber, Planet Fitness, LastPass rendered price placeholders instead of values) — for those, pricing rests on cross-checked secondary sources instead, marked `medium`. The session's WebSearch budget (200 calls) was exhausted before I could independently re-verify gym/delivery "pause or freeze" policies, so most `pause.supported` fields default to `false` with a note flagging where this wasn't independently confirmed (Planet Fitness, Equinox, Peloton) rather than asserting a specific freeze fee.

## Low confidence
- **equinox** — no public pricing exists; all figures are third-party aggregator estimates for 2026 ($222–415/mo range depending on tier/city). Marked `low` per instructions.

## Medium confidence (notable ones worth double-checking before shipping)
- **chatgpt** — Free/Go/Plus $0/$8/$20 are solid, but the "$100 Pro" tier (alongside the existing $200 Pro) could not be confirmed on openai.com (403'd twice) or any major outlet; it only appears on SEO aggregator sites, several of which look like programmatic/AI-generated content mills (costbench.com, felloai.com, theaicareerlab.com, aipricing.guru all repeat identical phrasing). Treat the $100 Pro tier as unverified; $20 Plus and $200 Pro top tier are consistent with well-established facts.
- **duolingo** — Max at $29.99/mo is corroborated by multiple sources including Duolingo Fandom wiki, but multiple sources also note Max "no longer appears as a new subscription option on some accounts," suggesting it may be mid-deprecation/restructuring in 2026.
- **expressvpn / nordvpn / proton-vpn** — vendor pages blocked automated fetches; tier names/prices reconstructed from aggregator consensus (ExpressVPN in particular restructured to Basic/Advanced/Pro tiers recently and figures varied $12.95–$22.99 across sources).
- **lastpass** — vendor pricing page returned template placeholders (`{LPPremium}`) instead of rendered values; used secondary-source figures ($3/$4 billed annually).
- **calm** — monthly price consistent at $16.99, but annual figure conflicts between sources ($79.99 vs $69.99); noted both in the tier.
- **noom** — pricing is commitment-length-based (4/6/12-month) rather than simple monthly/yearly tiers; modeled as three tiers by commitment length.

## Notable 2026 changes found (not in the original brief's assumptions)
- **Google AI Pro** now includes **5TB** storage, not 2TB — Google raised it from 2TB to 5TB at the same $19.99/mo price around April 2026 (confirmed on Google's own pricing page plus Android Central/gHacks/Yahoo Tech coverage). The brief's brand description assumed 2TB; I used the current, verified 5TB figure and noted the change.
- **Adobe Creative Cloud** restructured into "Standard" ($54.99/mo) and "Pro" ($69.99/mo, adds unlimited Firefly AI + web/mobile) — this replaces the old single "All Apps" tier naming.
- **Amex Platinum** refreshed in 2025: annual fee now $895/yr (up from $695), Digital Entertainment credit unchanged at $25/mo but Peacock is excluded when bundled/third-party as of Aug 1, 2026.
- **Chase Sapphire Reserve** refreshed in 2025: $795/yr fee (up from $550), added complimentary Apple TV+/Music.
- **1Password** raised consumer annual prices ~$12/yr on March 27, 2026 (first hike in years).

## Amex Gold — no subscription-relevant "includes"
Per the brief's own instruction to include "only subscription-relevant perks," I left `includes: []`. Amex Gold's Uber Cash ($10/mo) is general-purpose ride/Eats credit, not a dedicated Uber One membership reimbursement (unlike Amex Platinum, which has a *separate*, explicit "$120/yr statement credit for an auto-renewing Uber One membership" benefit — confirmed on americanexpress.com). Dunkin' and Resy credits have no corresponding subscription brandId in this catalog.

## Bilt — skipped entirely
Checked Bilt's three 2026 cards (Blue/Obsidian/Palladium). None bundle a subscription service from this catalog — perks are rent-payment point multipliers, dining/grocery category bonuses, travel credits, and Priority Pass lounge access. Per the brief's "skip if none" instruction, no `bilt` bundle entry was written.

## Modeling notes
- **Convention used for priceMonthly/priceYearly**: `priceMonthly` = price under monthly billing cadence; `priceYearly` = total charge if paid once annually (often cheaper per-month equivalent, e.g. Dropbox Plus $11.99/mo vs $119.88/yr ≈ $9.99/mo). Left `null` where I could not source an exact annual figure rather than compute/guess one.
- **Amex Platinum digital entertainment credit** is a *single shared* $25/mo pool across Disney+/Hulu/ESPN/Peacock/NYT/WSJ, not $25 per service — each `includes` entry notes "not additive" to avoid the JSON implying $150/mo of combined value.
- **google-ai-pro bundle** intentionally "includes" both `google-one` (storage) and `gemini` (AI) — this models the real product structure where "Google AI Pro" is itself a bundle of what used to be two separate Google subscriptions.
- Streaming-service brandIds referenced inside bundle `includes` (`disney-plus`, `hulu`, `espn-plus`, `peacock`, `nyt`, `wsj`, `apple-tv`, `apple-music`, `walmart-plus`) are **out of this curator's scope** per the task brief (another curator owns those `services` entries) — referenced by brandId only, for merge.

## Full source list by entry
- **icloud**: apple.com/icloud
- **google-one / gemini**: one.google.com/about/plans; androidcentral.com; ghacks.net (Apr 2026 storage increase)
- **dropbox**: dropbox.com/plans; cloudwards.net
- **microsoft-365**: microsoft.com compare page; support.microsoft.com Basic FAQ; microsoft.com Copilot pricing
- **adobe-cc / adobe-photography / adobe**: adobe.com/creativecloud/plans.html; adobe.com/creativecloud/photography.html; petapixel.com; xodo.com; weandthecolor.com
- **1password**: 1password.com/sign-up; macrumors.com (Mar 2026 price increase)
- **lastpass**: securden.com; comparedge.com
- **bitwarden**: bitwarden.com/pricing
- **apple-passwords**: macworld.com; techradar.com
- **expressvpn**: cybernews.com; security.org
- **nordvpn**: allaboutcookies.org; security.org
- **proton-vpn**: cybernews.com; vpnoverview.com
- **chatgpt**: cometapi.com; aipricing.guru (medium confidence — see above)
- **claude**: claude.com/pricing
- **perplexity**: finout.io; screenapp.io
- **github-copilot**: github.blog; automationatlas.io
- **cursor**: lowcode.agency; eesel.ai
- **notion**: notion.com/pricing
- **duolingo**: dealnews.com; duolingo.fandom.com
- **masterclass**: upskillwise.com
- **headspace**: lifestack.ai; carepaths.com
- **calm**: choosingtherapy.com; carepaths.com
- **noom**: noom.com/blog; prettysweet.com
- **peloton**: support.onepeloton.com (official); cbsnews.com
- **apple-fitness**: apple.com/apple-fitness-plus; exercisepick.com
- **planet-fitness**: planetfitness.com/gym-memberships; athletechnews.com
- **equinox**: luxe.digital; equinomembershippricing.com (low confidence)
- **dashpass**: dealnews.com; billboard.com
- **uber-one**: getridewise.com; dealnews.com
- **lyft-pink**: lyft.com; getridewise.com
- **instacart-plus**: instacart.com/instacart-plus; sprouts.com FAQ
- **grubhub-plus**: aboutamazon.com (official Amazon newsroom); amazon.com/prime/offer/grubhub
- **amex-platinum**: americanexpress.com; cnbc.com; global.americanexpress.com (Uber One credit page); upgradedpoints.com
- **amex-gold**: upgradedpoints.com (Resy + Uber credit pages)
- **chase-sapphire-reserve**: cnbc.com; 9to5mac.com; joinkudos.com
- **chase-sapphire-preferred**: nerdwallet.com; awardwallet.com; joinkudos.com
- **capital-one-venture-x**: awardwallet.com; cnbc.com
- **amazon-prime-grubhub**: aboutamazon.com; amazon.com
