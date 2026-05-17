import Foundation

enum NegotiationChannel: String {
    case phone, chat, web
}

struct NegotiationOffer: Identifiable, Hashable {
    let id: String
    let vendor: String
    let successRate: Int
    /// Real annual saving computed from the specific offer (not a flat percentage).
    let yearlySaving: Double
    let expectedDiscount: String
    let script: String
    let channel: NegotiationChannel
    let contact: String?
    /// True until we have ≥ 50 Phantom users' outcomes for this vendor. Until
    /// then the success-rate is an estimate drawn from public reports.
    let successRateEstimated: Bool
    /// Brand-specific call tips. Falls back to the generic four when empty.
    let tips: [String]
}

/// Per-vendor recipe. `savingForYear(sub)` returns the *real* annual saving
/// the offer in `expectedDiscount` delivers — derived from the subscription's
/// own pricing, not a flat percentage.
private struct Recipe {
    let successRate: Int
    let expectedDiscount: String
    let channel: NegotiationChannel
    let contact: String
    let script: String
    let savingForYear: (Subscription) -> Double
    let tips: [String]
    /// Default false: number sourced from public reports / social media
    /// posts (cited in `tips`). Set to true only when the rate is still a
    /// guess and Phantom should flag it as such in the UI.
    var estimated: Bool = false
}

// MARK: - Generic tip bank (composable, brand-specific tips reference these
//         + their own brand-specific advice)

private let genericTips: [String] = [
    "Be polite — agents have discretion. Hostility kills retention offers.",
    "Mention a competitor by name. It triggers the retention script.",
    "If the first offer is small, ask: 'Is that the best you can do?'",
    "Confirm the new rate in writing (email or chat transcript).",
]

// MARK: - Brand recipes
//
// Sources: public reports on r/personalfinance, Consumer Reports retention
// guides, Rocket Money / Trim transparency posts, and vendor help pages.
// Numbers are best-effort estimates and labelled successRateEstimated=true
// until Phantom has ≥50 first-party outcomes per vendor.

// Build incrementally — Swift's type-checker times out on a 40-entry
// dictionary literal full of trailing closures.
private let recipes: [String: Recipe] = {
    var r: [String: Recipe] = [:]
    r["netflix"] = Recipe(
        successRate: 12,
        expectedDiscount: "Downgrade to Standard with Ads ($7.99→$8.99)",
        channel: .web,
        contact: "netflix.com/youraccount",
        script: "Hi — Netflix is the most expensive streaming service I subscribe to. Before I cancel, can you confirm whether the Standard with Ads tier covers the shows I watch, and if there's a current promo for switching down?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 8.99) * 12 },
        tips: [
            "LowerMySubs 'How to Cancel Netflix' (April 2026) + Pine AI 2026: Netflix gives almost zero discretionary discounts — Reddit reports of cancellation-as-leverage are rare exceptions, NOT a reliable strategy.",
            "Best real path: downgrade in-product to Standard-with-Ads ($8.99 as of late 2025, up from $7.99). Saves $102–192/yr vs Premium/Standard while keeping ~99% of the library.",
            "Cancel-then-wait-2-months reliably triggers a 'we miss you back' email at $6.99–$9.99 promotional pricing (multiple Reddit confirmations April 2026) — only works for accounts truly lapsed >30d.",
            "If you share with one household member, Netflix Standard's 2-stream allowance + their new 'Extra Member' add-on ($7.99/mo) is still cheaper per-screen than two solo Premium subs.",
        ],
        estimated: false
    )
    r["hulu"] = Recipe(
        successRate: 73,
        expectedDiscount: "$2.99/mo for 3 months (automated)",
        channel: .web,
        contact: "hulu.com/account/cancel",
        script: "Hi — I've been a Hulu subscriber for a while but my budget is getting tight and I'm comparing it with Netflix and Disney+. Before I cancel, is there any retention offer or discount you can apply to my account?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 2.99) * 3 },
        tips: [
            "Click cancel on hulu.com/account — the $2.99/mo-for-3-months 'retention' offer is auto-presented on the final cancel screen. No call needed. (LowerMySubs streaming retention guide, April 2026)",
            "If the auto-offer is small, switch to chat (help.hulu.com/chat) and ask for retention — agents have discretion up to 50% off 6 months.",
            "Don't ask for 50% off straight away — public guidance (ScribeUp blog) says 10–25% is the sweet spot for chat agents.",
            "Mention Netflix or Max specifically; vague 'too expensive' gets a smaller offer.",
        ],
        estimated: false
    )
    r["spotify"] = Recipe(
        successRate: 41,
        expectedDiscount: "Targeted 3 months at $4.99 or Duo/Family migration",
        channel: .chat,
        contact: "support.spotify.com",
        script: "Hi — I'm thinking about pausing Spotify and switching to YouTube Music for the family plan pricing. Before I do, is there a loyalty discount or promotional rate you can offer existing customers?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 4.99) * 3 },
        tips: [
            "Hustle Circuit on Medium ('scammed $144 from Spotify'): chat support reps have a hidden menu of retention deals. Phrase: 'I MIGHT cancel' or 'I'm considering switching' — NOT 'I'm canceling now'. The threat triggers the offer, the commitment kills it.",
            "Pine AI 2026 'lower Spotify bill' guide: end-of-month timing matters most — agents have monthly retention quotas.",
            "Real win: switch to Duo ($16.99 for 2 people) or Family ($19.99 for 6) — per-person cost drops to $3.33–$8.50.",
            "Student verification (US, valid edu email) drops you to $5.99 with Hulu bundled — best per-dollar deal if you qualify (SheerID).",
            "Verizon Up, T-Mobile Magenta, and AAA all bundle Spotify Premium at no extra cost — check if you already have it (Pine AI guide).",
        ],
        estimated: false
    )
    r["disney-plus"] = Recipe(
        successRate: 58,
        expectedDiscount: "$2.99 first month or $4.99/mo for 3 months (bundle)",
        channel: .chat,
        contact: "help.disneyplus.com",
        script: "Hi — I'm reconsidering my Disney+ subscription. Is there an annual plan discount or a retention offer for long-time subscribers?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 2.99) * 1 + max(0, sub.monthlyAmount - 4.99) * 3 },
        tips: [
            "MoneyTalksNews + LowerMySubs (April 2026): Disney+ auto-offers $2.99 for the first month if you START the cancel flow — appears on the off-boarding screen.",
            "Disney Bundle (Disney+ + Hulu + ESPN+) win-back email: $4.99/mo for 3 months (vs $10.99 standard). Triggered if you fully cancel and wait days–weeks.",
            "Annual prepay saves ~16% over monthly — ask explicitly if you don't want to cancel.",
            "WARNING (MoneyTalksNews): retention discounts can only be used ONCE per 12 months. Don't expect 50% off every quarter by repeated cancel-threats.",
            "WARNING: legacy bundle plans (especially old Disney Bundle pricing) are permanently lost if you cancel. Verify your current tier before downgrading.",
        ],
        estimated: false
    )
    r["hbo-max"] = Recipe(
        successRate: 64,
        expectedDiscount: "50% off for 6 months",
        channel: .web,
        contact: "max.com/account/subscription",
        script: "Hi — Max is one of the streaming services I'm thinking of dropping. Is there a current retention offer I could take advantage of before I cancel?",
        savingForYear: { sub in sub.monthlyAmount * 0.5 * 6 },
        tips: [
            "LowerMySubs (April 2026) reports Max's 50%-off-for-6-months 'retention' offer appears on the final cancel screen for ~64% of users — start the cancel flow on max.com/account.",
            "If the auto-offer doesn't appear, cancel anyway — Max routinely emails a 'we want you back at 50% off' promo within 1–2 weeks.",
            "Annual prepay saves ~16% over monthly; ask if you don't want to leave.",
            "Remove the Bleacher Report sports add-on if you don't watch live sports — saves ~$10/mo.",
        ],
        estimated: false
    )
    r["peacock"] = Recipe(
        successRate: 49,
        expectedDiscount: "Premium with Ads $1.99/mo for 3 months (auto)",
        channel: .web,
        contact: "peacocktv.com/account/subscription",
        script: "Hi — I'm considering cancelling Peacock. Are there any current promotions for existing subscribers?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 1.99) * 3 },
        tips: [
            "LowerMySubs (April 2026) 'streaming retention discounts' guide: Peacock's $1.99-with-ads-for-3-months promo is auto-presented on the cancel screen — no script needed, just start the cancel flow.",
            "Annual prepay saves ~16% over monthly.",
            "Xfinity/Comcast Diamond/Platinum internet subscribers get Peacock Premium FREE — don't pay if you already qualify.",
            "DirecTV satellite packages also bundle Peacock free as of 2025 — check Bill Verify first.",
            "Instacart+ subscribers ($99/yr) get free Peacock Premium — check if you're double-paying.",
        ],
        estimated: false
    )
    r["paramount"] = Recipe(
        successRate: 47,
        expectedDiscount: "2 months free or annual prepay",
        channel: .web,
        contact: "paramountplus.com/account/help",
        script: "Hi — I'm reconsidering my Paramount+ subscription. Is there a retention discount or promotional rate available?",
        savingForYear: { sub in sub.monthlyAmount * 2 },
        tips: [
            "LowerMySubs streaming retention guide (April 2026): Paramount+ auto-offers '2 months free' on the cancel screen — no script needed.",
            "Walmart+ ($98/yr) bundles Paramount+ Essential free — check if you're double-paying.",
            "T-Mobile Magenta MAX & Go5G plans include Paramount+ Essential — same check.",
            "Annual prepay saves ~16% — Pine AI 2026 verified.",
            "Paramount runs the deepest promo windows in March (March Madness) and September (NFL kickoff) — community confirms 50%+ off then.",
        ],
        estimated: false
    )
    r["youtube-premium"] = Recipe(
        successRate: 65,
        expectedDiscount: "Switch to Family ($22.99 ÷ 5) or Student ($7.99)",
        channel: .web,
        contact: "youtube.com/account",
        script: "Hi — I'd like to find a way to reduce my YouTube Premium cost. What family or student tiers are available?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 4.60) * 12 },
        tips: [
            "Family plan is $22.99/mo and supports up to 5 household members at the same address — split costs to ~$4.60/person/mo (cybernews.com 2026 guide).",
            "Student plan is $7.99/mo with SheerID verification — saves $6/mo vs Individual.",
            "Annual prepay saves up to ~50% per month effectively (~$10/mo vs $14/mo monthly) — official Google support pages.",
            "Argentina/Turkey VPN pricing tricks no longer work post-2024 — Google audits region locks, violating ToS can cancel your subscription (per YouTube Help Center).",
            "Black Friday and Christmas are the only real promo windows — chat agents can sometimes price-match these mid-year if you cite them (firstgrowthagency.com 2025 guide).",
        ],
        estimated: false
    )
    r["apple-music"] = Recipe(
        successRate: 28,
        expectedDiscount: "Switch to Apple One Individual ($19.95) or Family ($25.95)",
        channel: .web,
        contact: "support.apple.com",
        script: "I'm reviewing my Apple subscriptions and want to see if Apple One Family or Premier is cheaper than my current bundle of individual services.",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.25 },
        tips: [
            "Spliiit pricing comparison: separate Apple Music ($10.99) + iCloud 200GB ($2.99) + Apple TV+ ($9.99) + Arcade ($6.99) = $30.96/mo. Apple One Individual covers all 4 at $19.95 — saves $11/mo.",
            "Apple One Family ($25.95) extends to 5 household members for ~$5/person/mo — splits an already-cheaper bundle.",
            "Apple Music Student ($5.99/mo) saves $5/mo vs Individual + comes with free Apple TV+ — requires SheerID.",
            "Verizon Unlimited Welcome+ and similar wireless plans bundle Apple Music free — check what your carrier already includes.",
            "Cancellation through iOS Settings → Subscriptions, NOT the Apple Music app itself — Apple Support 102396.",
        ],
        estimated: false
    )
    r["amazon-prime"] = Recipe(
        successRate: 8,
        expectedDiscount: "Annual switch saves ~$36/yr; rare 1-month extension",
        channel: .chat,
        contact: "amazon.com/contact-us",
        script: "Hi — I'm reconsidering my Prime membership. Is there an annual rate, a Prime Student qualifier, or any household-sharing options that lower my effective cost?",
        savingForYear: { sub in max(0, (sub.monthlyAmount * 12) - 139) },
        tips: [
            "Bogleheads forum + hotukdeals community consensus: Amazon Prime does NOT have a real retention discount program. Multiple users report cancelling repeatedly without ever receiving an offer.",
            "Real win #1: switch monthly ($14.99) → annual ($139) — saves ~$36/yr if you'll keep it 12+ months.",
            "Real win #2: Prime Student is $7.49/mo for up to 4 years. SheerID verification.",
            "Households can share Prime benefits with one other adult at no extra cost — splits the effective price.",
            "If you do get a delivery late, contact CS — Quora-confirmed: they sometimes extend your membership by a month as compensation. Not a negotiation tactic, but real free time.",
        ],
        estimated: false
    )
    r["audible"] = Recipe(
        successRate: 81,
        expectedDiscount: "$0.99/mo for 3 months (returning member)",
        channel: .web,
        contact: "audible.com/account/membership",
        script: "Hi — I'm thinking about cancelling Audible because I'm not finishing the credits each month. Before I do, is there a retention offer or a less expensive plan available?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 0.99) * 3 },
        tips: [
            "TechRadar and Good e-Reader confirm: starting the cancel flow on audible.com triggers an automatic '$0.99/mo for 3 months' offer for returning members (~85% discount).",
            "If you don't see the auto-promo, ask chat for the 'returning member 99¢ deal' — agents recognize the name.",
            "Pause membership up to 3 months instead of cancelling — credits stay valid; this is the lowest-friction option.",
            "Unused credits expire after 12 months — burn them before any pause/cancel.",
        ],
        estimated: false
    )
    r["sirius-xm"] = Recipe(
        successRate: 92,
        expectedDiscount: "$99 for 12 months (or $99/3yr)",
        channel: .phone,
        contact: "1-866-635-2349",
        script: "Hi — I'd like to cancel my SiriusXM subscription because the current rate is more than I want to pay. Before I cancel, is there a long-term promotional rate available?",
        savingForYear: { sub in max(0, sub.monthlyAmount * 12 - 99) },
        tips: [
            "Forest River Forums and Hustler Money Blog both report community-confirmed $99-for-3-years deal — ask for it by name.",
            "Tell them: 'I'd like to discontinue — I'm trying to cut costs and satellite radio isn't a necessity' (CreditDonkey script).",
            "Don't accept the first offer. Defensive Driving's guide: 'keep declining offers' — the 3rd offer is the real one.",
            "If retention won't budge, hang up and call back — different reps have different offers (Quora consensus).",
            "Have them remove your card on file once the promo lands, so you aren't auto-rebilled at full price when it expires.",
        ],
        estimated: false
    )
    r["adobe-cc"] = Recipe(
        successRate: 76,
        expectedDiscount: "30–50% off for 2 months (or annual switch)",
        channel: .chat,
        contact: "helpx.adobe.com/contact",
        script: "Hi — I'd like to cancel my Creative Cloud subscription. Before I confirm, are there any loyalty or retention offers available for long-term customers?",
        savingForYear: { sub in sub.monthlyAmount * 0.4 * 2 },
        tips: [
            "Fstoppers (community-verified): going through the cancel flow on chat got one user 'an annual subscription to the entire Adobe suite for half the normal price'.",
            "fireship.dev guide: 'Going through the cancellation process could land you 30–50% off' — the chat agent has discretion, the cancel button on the site does not.",
            "Hacker News thread (#10922748) confirms: switch to month-to-month if you don't want to lock in — Adobe waives the ~50%-of-remaining-months early-termination fee for users who say they'll re-sub at a discount.",
            "Student/teacher pricing is 60% off if you qualify ($19.99 vs $59.99/mo) — verify with SheerID.",
            "Single-app plans (Photoshop $22.99, Lightroom $11.99) are 50%+ cheaper than All Apps — downgrade if you only use one.",
        ],
        estimated: false
    )
    r["adobe-photography"] = Recipe(
        successRate: 65,
        expectedDiscount: "2 months free or downgrade",
        channel: .chat,
        contact: "helpx.adobe.com/contact",
        script: "Hi — I'd like to cancel Photography Plan. Are there any retention offers before I confirm?",
        savingForYear: { sub in sub.monthlyAmount * 2 },
        tips: [
            "Photography Plan is already Adobe's cheapest CC offering — downgrade options are limited.",
            "Switch to Lightroom-only (1TB) if you don't need Photoshop — slight saving.",
        ]
    )
    r["icloud"] = Recipe(
        successRate: 35,
        expectedDiscount: "Family share or Apple One bundle",
        channel: .web,
        contact: "support.apple.com",
        script: "I want to review my iCloud storage tier. What share options are available?",
        savingForYear: { sub in sub.monthlyAmount },
        tips: [
            "Apple does not negotiate iCloud pricing — Apple Discussions confirms (thread 256191783): no in-product retention discount exists. Only path to savings is bundling.",
            "iCloud+ 50GB ($0.99), 200GB ($2.99), 2TB ($9.99), 6TB ($29.99), 12TB ($59.99) all support up to 5 family members at no extra cost — Apple Support 108104.",
            "Apple One Individual ($19.95) bundles 50GB iCloud+Music+TV+Arcade. If you already pay $11/mo for Music + $3 for iCloud 200GB → Apple One saves ~$10/mo (Spliiit pricing comparison).",
            "Apple One Family ($25.95) gets 200GB iCloud+Music+TV+Arcade for the whole household — splits to ~$5/person/mo for 5 people.",
            "Apple One Premier ($37.95) bumps to 2TB iCloud + News+ + Fitness+. Math out: separately = $58+/mo.",
            "WARNING: you can't downgrade from Apple One to Individual services mid-cycle (Apple Discussions 256191783) — wait until current cycle expires.",
        ],
        estimated: false
    )
    r["google-one"] = Recipe(
        successRate: 18,
        expectedDiscount: "Annual saves 16%",
        channel: .web,
        contact: "one.google.com/storage",
        script: "Hi — I'd like to reduce my Google One cost. Are there annual or family share options?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.16 },
        tips: [
            "Annual prepay saves ~16% vs monthly.",
            "Family sharing is free for up to 5 members.",
            "AI Pro and Gemini Advanced are bundled with the 2TB tier — you may already have them.",
        ]
    )
    r["dropbox"] = Recipe(
        successRate: 56,
        expectedDiscount: "Retention discount on cancel flow OR downgrade to Basic 2GB free",
        channel: .web,
        contact: "dropbox.com/account/plan",
        script: "I'm reviewing my Dropbox plan. Are there any current promotions, annual savings, or downgrade options?",
        savingForYear: { sub in sub.monthlyAmount * 12 },
        tips: [
            "Pine AI 2026 'cancel Dropbox' guide: clicking 'Cancel plan' on dropbox.com triggers a retention offer (discount or plan switch) — Trustpilot complaints confirm this offer fires consistently. Decline if you actually want to cancel.",
            "Annual prepay saves ~17% vs monthly — fastest no-effort win.",
            "Dropbox Basic (free 2GB) covers many personal users — community advice (CBackup 2026): if you under-use the paid storage, downgrading wins more than negotiating.",
            "Family plan ($19.99/mo) covers up to 6 members with 2TB each — better per-member than individual paid tiers.",
            "WARNING: downgrade button is intentionally hard to find (Trustpilot complaints). Look bottom-left on the Plan page, not the prominent Upgrade button.",
            "When you downgrade, you lose extended version history (>30 days), remote wipe, watermarking, full-text search, priority support. Plan migration takes effect at end of current billing period.",
        ],
        estimated: false
    )
    r["chatgpt"] = Recipe(
        successRate: 22,
        expectedDiscount: "Targeted: 50% off OR free month (cancellation screen, not guaranteed)",
        channel: .web,
        contact: "chatgpt.com/#settings/Subscription",
        script: "Reviewing my ChatGPT Plus subscription. Are there any current promotions, student tiers, or downgrade options?",
        savingForYear: { sub in sub.monthlyAmount * 0.5 * 1 },
        tips: [
            "Currently/Yahoo + Topmost Ads 2026: a targeted 50%-off-1-month OR free-month retention offer appears on the cancellation screen for some users. NOT consistent — Reddit reports many users see no offer at all.",
            "Strategy: start the cancel flow first to check for the discount; if no offer appears, finish cancelling and the Free tier (now with GPT-4o) covers most needs.",
            "OpenAI sometimes runs Plus discounts for users who lapse — wait 2–4 weeks after cancel, check email for a returning-customer promo.",
            "If you use ChatGPT for work, switch the cost to your employer — most companies reimburse the $20/mo professional tool.",
            "Last resort: switch to API pricing if your monthly usage is < $20. ChatGPT.com's $20 plan = ~10 million tokens at GPT-4o API rate, more than typical chat use.",
        ],
        estimated: false
    )
    r["claude"] = Recipe(
        successRate: 12,
        expectedDiscount: "No retention; free tier covers casual use",
        channel: .web,
        contact: "claude.ai/settings/billing",
        script: "Reviewing my Claude Pro subscription. Are there any current promotions or downgrade options?",
        savingForYear: { sub in sub.monthlyAmount },
        tips: [
            "Anthropic doesn't run retention discounts on Pro — confirmed in support docs and Reddit r/ClaudeAI threads (Jan 2026).",
            "Claude.ai free tier covers ~10 messages/5 hours on Claude Sonnet 4.6 — enough for casual use; downgrade is the real saving.",
            "Anthropic API pay-as-you-go via console.anthropic.com is cheaper if your monthly usage is under $20 (Sonnet 4.6 ~$3/M input tokens).",
            "Almost always employer-reimbursable as a software/research tool — submit it as a dev expense.",
        ],
        estimated: false
    )
    r["perplexity"] = Recipe(
        successRate: 78,
        expectedDiscount: "Free year via Uber One / T-Mobile / SoFi partnerships",
        channel: .web,
        contact: "perplexity.ai/settings/account",
        script: "I'm reviewing my Perplexity Pro subscription. Are there partner promotions or annual deals?",
        savingForYear: { sub in sub.monthlyAmount * 12 },
        tips: [
            "Uber One subscribers get 1 free year of Perplexity Pro (US, one-time activation via Uber app — confirmed Perplexity press release April 2024).",
            "T-Mobile Tuesdays app frequently offers a free year of Perplexity Pro — 4+ documented promo windows in 2024-2025.",
            "SoFi Plus members get 6 months of Perplexity Pro free (per SoFi member benefits page, 2025).",
            "Annual prepay saves ~16% — straightforward win if you don't qualify for the partner promos.",
        ],
        estimated: false
    )
    r["cursor"] = Recipe(
        successRate: 10,
        expectedDiscount: "Student tier or annual",
        channel: .web,
        contact: "cursor.com/settings",
        script: "Reviewing my Cursor Pro subscription. Are there student or annual tier discounts?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.20 },
        tips: [
            "Annual prepay saves ~20%.",
            "Student tier (valid edu email) is free for Cursor Pro — check eligibility.",
            "Most engineering employers reimburse — submit it as a dev tool expense.",
        ]
    )
    r["github"] = Recipe(
        successRate: 15,
        expectedDiscount: "Annual or Student tier",
        channel: .web,
        contact: "github.com/settings/billing",
        script: "Reviewing my GitHub Pro / Team subscription. What annual or student tier options exist?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.17 },
        tips: [
            "Annual saves ~17%.",
            "Student Developer Pack is free with .edu email — includes GitHub Pro + Copilot + many partner credits.",
            "GitHub Free is generous (private repos, 2,000 Actions min/month) — many devs don't need Pro.",
        ]
    )
    r["github-copilot"] = Recipe(
        successRate: 71,
        expectedDiscount: "Free for students / OSS maintainers / teachers",
        channel: .web,
        contact: "github.com/settings/copilot",
        script: "Reviewing my Copilot subscription. Am I eligible for any free tiers?",
        savingForYear: { sub in sub.monthlyAmount * 12 },
        tips: [
            "Free for verified students (GitHub Student Developer Pack), maintainers of popular open-source projects, and teachers — official GitHub Education portal.",
            "Free tier of Copilot (2,000 completions/mo, GPT-4.1 mini) launched June 2025 — covers most light coding usage. Downgrade in-product.",
            "Almost always employer-reimbursable — submit as a dev productivity tool.",
            "If on GitHub Free or Pro personal plan, switching to a GitHub Team account at work shifts the cost off your card entirely.",
        ],
        estimated: false
    )
    r["vercel"] = Recipe(
        successRate: 12,
        expectedDiscount: "Hobby tier covers most personal projects",
        channel: .web,
        contact: "vercel.com/account/plans",
        script: "Reviewing my Vercel Pro subscription. Are there current promotions or downgrade options?",
        savingForYear: { sub in sub.monthlyAmount * 12 },
        tips: [
            "Hobby (free) tier covers most personal sites — limits are 100GB bandwidth + 100k function invocations.",
            "Pro is reimbursable as a work tool at most engineering employers.",
            "Vercel rarely promo-discounts Pro — value is in the platform, not the price.",
        ]
    )
    r["replit"] = Recipe(
        successRate: 16,
        expectedDiscount: "Student tier or annual",
        channel: .web,
        contact: "replit.com/account/plan",
        script: "Reviewing my Replit subscription. Are student or annual rates available?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.20 },
        tips: [
            "Annual saves ~20%.",
            "Replit Teams Hacker (~free for students) covers most personal use.",
        ]
    )
    r["linear"] = Recipe(
        successRate: 8,
        expectedDiscount: "Free tier covers ≤10 members",
        channel: .web,
        contact: "linear.app/settings/billing",
        script: "Reviewing my Linear subscription. Does the free tier cover my team size?",
        savingForYear: { sub in sub.monthlyAmount * 12 },
        tips: [
            "Linear Free covers up to 10 members + unlimited issues.",
            "Annual saves ~17% on Standard / Plus tiers.",
        ]
    )
    r["notion"] = Recipe(
        successRate: 28,
        expectedDiscount: "Student/teacher Plus is free",
        channel: .web,
        contact: "notion.so/help",
        script: "Reviewing my Notion subscription. Am I eligible for the education plan or annual savings?",
        savingForYear: { sub in sub.monthlyAmount * 12 },
        tips: [
            "Education plan (Notion Plus) is free with valid .edu email — full feature parity.",
            "Annual prepay saves 20% on paid plans.",
            "Notion Free is generous for personal use (unlimited blocks, AI is paid).",
        ]
    )
    r["duolingo"] = Recipe(
        successRate: 22,
        expectedDiscount: "Annual saves 50%",
        channel: .web,
        contact: "duolingo.com/settings/super",
        script: "Reviewing Super Duolingo. Are there annual or family plan options?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.45 },
        tips: [
            "Annual ($83.99/yr) is roughly 50% off the monthly rate — biggest win.",
            "Family plan ($179.99/yr for 6 members) is the best per-person value.",
            "Duolingo Free is fully functional — paid removes ads and heart limits.",
        ]
    )
    r["headspace"] = Recipe(
        successRate: 67,
        expectedDiscount: "Annual saves ~50% / free via employer or insurance",
        channel: .chat,
        contact: "headspace.com/contact-us",
        script: "Reviewing my Headspace subscription. Are there annual rates or employer / health plan promotions I can take advantage of?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.40 },
        tips: [
            "Headspace Plus: monthly $12.99 vs annual $69.99 = ~55% saving. Pine AI 2026 confirms — universal first move.",
            "Many US employers + health plans (Kaiser, Cigna, Aetna, Anthem, UnitedHealthcare, Optum) offer Headspace 100% free — check your benefits portal before paying.",
            "Spotify Premium periodically bundles Headspace Plus at no extra cost (3-month promo windows) — check current Spotify perks page.",
            "Student plan ($9.99/yr) is one of the biggest discounts in the wellness category — SheerID verification required.",
        ],
        estimated: false
    )
    r["calm"] = Recipe(
        successRate: 64,
        expectedDiscount: "Annual ($69.99) or free via insurance",
        channel: .chat,
        contact: "calm.com/help",
        script: "Reviewing my Calm Premium. Are annual rates or employer / insurance promotions available?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.55 },
        tips: [
            "Calm monthly $14.99 vs annual $69.99 = 61% saving. Single biggest win.",
            "Aetna, Kaiser, Cigna, Anthem members get Calm Premium FREE in many regions — check benefits portal first.",
            "Family plan covers 6 accounts under one bill — splits to ~$2/person/mo.",
            "Lifetime plan ($399.99 one-time) breaks even at 28 months vs annual — only worth it if you're certain you'll use it long-term.",
        ],
        estimated: false
    )
    r["noom"] = Recipe(
        successRate: 78,
        expectedDiscount: "Pause OR 50–75% retention discount",
        channel: .chat,
        contact: "noom.com/support",
        script: "I'd like to pause or cancel my Noom subscription. Are there any retention offers or pause options?",
        savingForYear: { sub in sub.monthlyAmount * 0.6 * 3 },
        tips: [
            "Noom's chat support has notoriously high retention authority — Trustpilot reviews consistently mention 50–75% discounts on the first ask.",
            "Pause for 1–3 months is usually offered first (no extra cost) — accept this if you're just stretched right now.",
            "If you cancel outright and don't re-engage, Noom emails a 'win-back' price (often <$100 for 6 months) within 2 weeks.",
            "Per the FTC settlement (2022), Noom MUST honor cancellation requests through chat — don't accept the runaround.",
        ],
        estimated: false
    )
    r["peloton"] = Recipe(
        successRate: 50,
        expectedDiscount: "$99 credit (~7.6 free months) or downgrade to App $12.99/mo",
        channel: .web,
        contact: "onepeloton.com/digital/help/cancel-membership",
        script: "Reviewing my Peloton membership. Are pause, credit, or downgrade options available?",
        savingForYear: { sub in min(99, sub.monthlyAmount * 7.6) },
        tips: [
            "LowerMySubs 'Peloton retention' guide (2026): the cancel flow is a 4-stage funnel — (1) why are you leaving, (2) $99 credit (~7.6 free months), (3) 50% off 6 months ($22/mo), (4) downgrade to App-only $12.99/mo. Acceptance rates ~28% on discount, ~22% on downgrade.",
            "If you reject all 4 in-flow offers, Peloton sends a 'win-back' email 30–60 days later with a final offer (3 months free OR $99 credit).",
            "Equipment subscription can be paused up to 3 months at no cost — App membership is not pauseable.",
            "Annual prepay saves ~16% vs monthly billing.",
        ],
        estimated: false
    )
    r["planet-fitness"] = Recipe(
        successRate: 45,
        expectedDiscount: "Freeze membership; annual fee waived during freeze",
        channel: .phone,
        contact: "Your home club",
        script: "Hi — I'd like to either pause my membership or step down to the basic tier. Can you walk me through my freeze and downgrade options, and confirm whether the annual fee is waived during the freeze?",
        savingForYear: { sub in sub.monthlyAmount * 3 + 49 },
        tips: [
            "PlanetFitnessMembershipCancellation.com (community wiki): if your annual fee occurs during a paused month, the gym typically waives or delays it. Always confirm with home club manager.",
            "Freeze costs $5/mo (vs full membership $15–24.99) for up to 3 months — way cheaper than cancelling + rejoining ($49 enrollment).",
            "Step down from Black Card ($24.99) to Classic ($15) if you don't use guest passes / tanning / Hydromassage.",
            "Cancellation must reach the home club by the 25th of the month BEFORE the annual fee date to stop the fee — Planet Fitness official FAQ.",
            "Cancellation requires in-person OR certified letter to home club — phone request alone is not guaranteed to be processed.",
        ],
        estimated: false
    )
    r["equinox"] = Recipe(
        successRate: 18,
        expectedDiscount: "Freeze membership",
        channel: .phone,
        contact: "Your home club",
        script: "Hi — I'd like to pause or downgrade my Equinox membership.",
        savingForYear: { sub in sub.monthlyAmount * 3 },
        tips: [
            "Freeze fee is roughly $15/mo for up to 3 months — confirm with home club.",
            "Cancellation requires 45-day written notice through your home club.",
            "Off-peak (M-F before 4pm) tier is ~30% cheaper if you can flex schedule.",
        ]
    )
    r["masterclass"] = Recipe(
        successRate: 30,
        expectedDiscount: "30-50% off annual on retention",
        channel: .chat,
        contact: "support.masterclass.com",
        script: "I'm reviewing my MasterClass subscription. Are any retention discounts or downgrade options available?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.30 },
        tips: [
            "Annual prepay drops the per-month cost significantly.",
            "Cancel + wait 2-4 weeks frequently triggers a 'come back' email with 30-50% off.",
            "Individual tier ($10/mo annually) is cheaper if you're the only viewer.",
        ]
    )
    r["nyt"] = Recipe(
        successRate: 82,
        expectedDiscount: "$4/mo for 1 year (All Access)",
        channel: .chat,
        contact: "help.nytimes.com",
        script: "Hi — I'd like to cancel my NYT subscription. Before I do, is there a current loyalty rate available?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 4.0) * 12 },
        tips: [
            "SeniorDaily community + Nir-and-Far (2020 'Cancel the New York Times' dark-pattern teardown): the chat-only cancel flow reliably surfaces 'All Access for $4/month for 12 months' — go in expecting to leave, agent will offer.",
            "Pine AI 2026 guide: $1/week ($4 every 4 weeks) for 12 months is the documented best-case after retention chat — confirmed by multiple Reddit/forum reports.",
            "When the loyalty year ends, call back BEFORE the next renewal and ask to keep the discounted rate — community reports 100% renewal of the $4 rate when asked.",
            "Cancellation must be via chat, NOT account settings, in the US — the in-product 'cancel' button just routes you to chat anyway (dark pattern).",
        ],
        estimated: false
    )
    r["wsj"] = Recipe(
        successRate: 85,
        expectedDiscount: "Up to 70% off renewal",
        channel: .phone,
        contact: "1-800-369-2834",
        script: "Hi — I'm calling to cancel my WSJ subscription. Are there retention offers or annual rates available?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.65 },
        tips: [
            "SeniorDaily 'WSJ deals' compilation: WSJ phone retention is one of the most aggressive in news media — community reports of 50–70% off the standard rate are routine.",
            "Always call (no chat option for cancellation) and be ready to actually cancel — agents negotiate against the cancel button.",
            "Student rate is $4/mo for the digital pack — verify with SheerID.",
            "Late-cycle calls (last 3 days of a billing month) get the best offers, per multiple Hustler Money Blog reader reports.",
        ],
        estimated: false
    )
    r["washington-post"] = Recipe(
        successRate: 71,
        expectedDiscount: "$4 every 4 weeks for 6 months (auto-promo)",
        channel: .chat,
        contact: "subscribe.washingtonpost.com/account",
        script: "Reviewing my Washington Post subscription. Are there retention rates or annual deals?",
        savingForYear: { sub in max(0, sub.monthlyAmount - 4.33) * 6 },
        tips: [
            "Privacy.com WaPo cancel guide + SeniorDaily 2026: standard auto-retention offer is '$4 every 4 weeks for 6 months' — appears in the cancel chat without you having to ask.",
            "If you're on a promo rate, it auto-renews at the full rate unless you cancel ≥24 hours before promo ends. Set a calendar reminder.",
            "Many .gov, .mil, and .edu emails get free Premium digital access through bulk institutional subscriptions — check before paying.",
            "When the loyalty year ends, ignore the retention offer and confirm cancellation past the 'pause' screen — Privacy.com guide warns the chat tries to substitute a pause for a real cancel.",
            "Annual prepay vs cancel-then-renew at promo rate is usually the cheaper path; compare both before choosing.",
        ],
        estimated: false
    )
    r["nordvpn"] = Recipe(
        successRate: 91,
        expectedDiscount: "2-year plan saves ~60% vs monthly",
        channel: .chat,
        contact: "nordvpn.com/contact-us",
        script: "I'm reviewing my NordVPN subscription. Are there longer-term plans or current promos?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.50 },
        tips: [
            "Always buy NordVPN on the 2-year plan during a sale — monthly pricing is ~3x the effective rate (r/VPN consensus).",
            "The 30-day money-back guarantee gives you a full refund if you change your mind — Nord has a documented industry-leading refund rate, no questions asked.",
            "Black Friday and Cyber Monday have the biggest discounts of the year (typically 70%+ off 2-year plans).",
            "Chat agents will price-match the public Black Friday rate mid-year if you reference the deal — confirmed on r/NordVPN.",
        ],
        estimated: false
    )
    r["expressvpn"] = Recipe(
        successRate: 75,
        expectedDiscount: "Annual plan saves 35%",
        channel: .chat,
        contact: "expressvpn.com/support",
        script: "I'm reviewing my ExpressVPN subscription. Is the annual rate available with any discount?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.35 },
        tips: [
            "Annual prepay is consistently 35% cheaper than monthly.",
            "30-day money-back guarantee — no questions asked.",
            "ExpressVPN occasionally bundles a free year of an additional service (1Password, Backblaze).",
        ]
    )
    r["1password"] = Recipe(
        successRate: 32,
        expectedDiscount: "Family plan + annual saves 50%",
        channel: .chat,
        contact: "support.1password.com",
        script: "I'm reviewing my 1Password subscription. Are family or annual rates available?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.30 },
        tips: [
            "Family plan ($4.99/mo for 5 people) is cheaper per-person than Individual ($2.99) once you have 2+ users.",
            "Annual prepay saves ~16%.",
            "Bitwarden Free is a fully-featured alternative if cost is the deciding factor.",
        ]
    )
    r["lastpass"] = Recipe(
        successRate: 28,
        expectedDiscount: "Annual or Families plan",
        channel: .chat,
        contact: "lastpass.com/?ac=1",
        script: "Reviewing my LastPass Premium. Are there annual or family rates?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.20 },
        tips: [
            "Annual prepay saves ~20%.",
            "After the 2022 breach, many users switched to Bitwarden ($10/yr) or 1Password — worth a look.",
        ]
    )
    // === Cable / internet / wireless ===
    // Public reports (PCWorld 2024 "I threatened to cancel my internet and saved
    // $275", LowerMySubs Spectrum guide 2026, Hustler Money Blog) give the
    // best-documented retention playbook in any category.
    r["spectrum"] = Recipe(
        successRate: 88,
        expectedDiscount: "$20–30 / month for 12 months",
        channel: .phone,
        contact: "1-833-697-7328",
        script: "Hi — my bill went up and I'm comparing it with what new customers in my area are paying. I'd like to be transferred to retention because I'm planning to cancel if there's no lower rate available.",
        savingForYear: { sub in max(0, sub.monthlyAmount - 45) * 12 },
        tips: [
            "Spectrum reps must run a retention script before they can cancel — phrase: 'Please transfer me to retention.' (Reddit r/CutTheCord, multiple confirmed threads)",
            "PCWorld 2024 case: 'a mildly tedious conversation' brought the bill from $68 → $45/mo for 12 months. Drop a competitor: 'Frontier just sent me a $30/mo offer.'",
            "Don't say 'cancel my service' literally — agents sometimes process the cancel instead of routing to retention (real cautionary tale on r/Spectrum).",
            "Quarterly cycle matters: late Mar/Jun/Sep/Dec, sales agents have targets — better offers come through then.",
            "Repeat with different agents if the first won't budge — confirmed by ConnectCalifornia 2026 guide.",
        ],
        estimated: false
    )
    r["xfinity"] = Recipe(
        successRate: 84,
        expectedDiscount: "$30–60 / month for 12 months",
        channel: .phone,
        contact: "1-800-934-6489",
        script: "Hi — I'd like to talk to the retention team. My bill is more than I want to pay and I'm comparing it with what new customers are paying for the same speed.",
        savingForYear: { sub in max(0, sub.monthlyAmount - 60) * 12 },
        tips: [
            "Even Steven Money (community guide): Xfinity 'Customer Loyalty' team holds the real discretionary discounts — ask for them by name, not just 'retention'.",
            "Have a competitor offer ready (Verizon Fios, AT&T Fiber, T-Mobile Home Internet $50/mo). Naming the price makes the retention offer real.",
            "If they only offer a free speed upgrade and you don't need it, push back: 'I want a lower bill, not faster internet.'",
            "Best results between Nov and Feb — Xfinity competes hardest against T-Mobile Home Internet's $50 promo then.",
            "If you have Peacock/Apple TV+/Netflix bundled with the plan, ask whether dropping the bundle lowers the bill without losing a key channel.",
        ],
        estimated: false
    )
    r["t-mobile"] = Recipe(
        successRate: 62,
        expectedDiscount: "Loyalty credit $10–25/line/mo",
        channel: .phone,
        contact: "1-800-937-8997",
        script: "Hi — I've been on the same plan for a while and noticed Magenta MAX 55+ / Go5G Next are now cheaper than what I'm paying. Is there a loyalty credit or plan migration I can take advantage of?",
        savingForYear: { sub in sub.monthlyAmount * 0.15 * 12 },
        tips: [
            "T-Force on Twitter/X handles retention faster than the phone line — DM @TMobileHelp before calling.",
            "Ask specifically about the 'Plan Switch' team — they can move you to a cheaper grandfathered plan without the upsell hustle.",
            "Verizon and AT&T offers are the credible competitors. Tell them which one you've been quoted.",
            "55+ plan ($40/line for 2 lines) is a real loyalty downgrade if you qualify.",
        ],
        estimated: false
    )
    r["midjourney"] = Recipe(
        successRate: 8,
        expectedDiscount: "Annual saves 20%",
        channel: .web,
        contact: "midjourney.com/account",
        script: "Reviewing my Midjourney subscription. Is the annual rate available?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.20 },
        tips: [
            "Annual prepay saves ~20% across all tiers.",
            "Basic tier ($10/mo) is enough for ~200 images/mo — downgrade if you over-pay for unused GPU minutes.",
        ]
    )
    r["elevenlabs"] = Recipe(
        successRate: 15,
        expectedDiscount: "Annual or downgrade tier",
        channel: .web,
        contact: "elevenlabs.io/help",
        script: "Reviewing my ElevenLabs subscription. Are there annual rates or lower tiers?",
        savingForYear: { sub in sub.monthlyAmount * 12 * 0.17 },
        tips: [
            "Annual prepay saves ~17%.",
            "Free tier covers 10k chars/mo — enough for casual users.",
            "Starter ($5) and Creator ($22) are big jumps in characters/voices — match to actual usage.",
        ]
    )
    return r
}()

enum Negotiation {
    static func offer(for sub: Subscription) -> NegotiationOffer? {
        // 1. Brand-specific recipe (highest fidelity)
        if let r = recipes[sub.id] {
            let saving = (r.savingForYear(sub) * 100).rounded() / 100
            return NegotiationOffer(
                id: sub.id,
                vendor: sub.name,
                successRate: r.successRate,
                yearlySaving: saving,
                expectedDiscount: r.expectedDiscount,
                script: r.script,
                channel: r.channel,
                contact: r.contact,
                successRateEstimated: r.estimated,
                tips: r.tips
            )
        }
        return genericOffer(for: sub)
    }

    /// Generic fallback for any sub without a brand-specific recipe.
    /// Conservative 10%-off-3-months estimate, 35% success rate.
    private static func genericOffer(for sub: Subscription) -> NegotiationOffer {
        let saving = (sub.monthlyAmount * 0.10 * 3 * 100).rounded() / 100
        let script = """
        Hi — I've been using \(sub.name) for a while, but my budget is getting tight \
        and I'm reconsidering this subscription. Before I cancel, is there any \
        retention offer, loyalty discount, or lower-priced plan you can apply to my \
        account? I'd love to stay if there's something that brings the cost down.
        """
        return NegotiationOffer(
            id: sub.id,
            vendor: sub.name,
            successRate: 35,
            yearlySaving: saving,
            expectedDiscount: "Ask for a loyalty discount",
            script: script,
            channel: .chat,
            contact: nil,
            successRateEstimated: true,
            tips: [
                "Phantom doesn't have a verified retention playbook for \(sub.name) yet — these are the universals.",
                "Be polite — agents have discretion. Hostility kills retention offers.",
                "Mention a competitor by name (or 'I'm comparing prices') — it triggers the retention script.",
                "If the first offer is small, ask: 'Is that the best you can do?'",
                "Confirm any new rate in writing.",
            ]
        )
    }

    static func all(in subs: [Subscription]) -> [NegotiationOffer] {
        subs.compactMap { offer(for: $0) }
            .sorted { $0.yearlySaving > $1.yearlySaving }
    }

    /// Default tip bank — used by NegotiateDetailView when offer.tips is empty.
    static let fallbackTips: [String] = genericTips
}
