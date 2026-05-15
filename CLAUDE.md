# Phantom — Project Context for Claude Code

> A subscription-management iOS app that surfaces "zombie subscriptions," generates EFTA-compliant dispute letters, warns about price hikes, and helps users negotiate retention discounts. Sees PRD at `Phantom_PRD.md`. Designed to ship on the App Store; UI inspired by Uber (black-and-white, large type, generous spacing).

## 1. Product (one-liner per surface)

| Surface | Job-to-be-done |
|---|---|
| Onboarding | Sell the value in 3 screens, then connect a bank (mocked Plaid) |
| Radar (Home) | Show monthly spend + biggest savings opportunity + every subscription, sorted by zombie score |
| Detail | Explain *why* a subscription is a zombie, expose cancel / negotiate / dispute actions |
| Dispute Letter | Generate an EFTA-compliant letter; copy/share |
| Alerts | Price hikes, trial ends, new charges |
| Negotiate | Per-vendor scripts for retention discounts |
| Settings / Pro | Plan tiers, three-no privacy promise, account |

## 2. Tech stack

- **Expo SDK 54+** with **Expo Router** (file-based routing, App Store-shippable via EAS Build)
- **TypeScript strict**
- **NativeWind v4** (Tailwind for RN) — single source of styling truth
- `@expo/vector-icons` (Feather + Ionicons subsets) for iconography
- `expo-haptics`, `expo-clipboard`, `expo-sharing` for native polish
- `zustand` for app state (no Redux — overkill for this surface area)
- `react-native-svg` for charts and the brand mark
- `@react-native-async-storage/async-storage` for persistence
- **No real Plaid integration in this build** — `lib/data/mock.ts` provides deterministic mock data so we can run end-to-end without secrets

## 3. Repo layout

```
Phantom/
├── app/                       # Expo Router (file-based)
│   ├── _layout.tsx            # Root stack
│   ├── index.tsx              # Splash → routes to onboarding or tabs
│   ├── onboarding/            # 3-screen value pitch + connect
│   ├── (tabs)/                # Bottom tab nav: Radar / Alerts / Negotiate / Settings
│   ├── subscription/[id].tsx  # Detail
│   ├── dispute/[id].tsx       # Dispute letter generator
│   └── paywall.tsx            # Pro modal
├── components/                # Reusable: Button, Card, Badge, ZombieMeter, SpendHero…
├── lib/
│   ├── theme.ts               # Tokens (colors, type, radii, spacing)
│   ├── score.ts               # Zombie score algorithm (matches PRD §3.2)
│   ├── data/mock.ts           # Mock subscriptions, alerts, usage
│   └── store.ts               # Zustand store
├── assets/                    # Icons, fonts
├── Phantom_PRD.md              # Source of truth for product decisions
└── CLAUDE.md                  # This file
```

## 4. Design language — "Uber-clean"

- **Palette**: `#000` (primary), `#FFF` (canvas), `#0A0A0A` (ink), `#6B7280` (mute), `#F4F4F5` (surface), `#10B981` (success/save), `#EF4444` (zombie danger), `#F59E0B` (warn)
- **Type**: SF system font; weights 400 / 600 / 700 / 900. Headlines are oversized and tight (`-0.02em` tracking). Body 16px / 24px line-height.
- **Spacing**: 4-px base, prefer 8 / 12 / 16 / 24 / 32. Cards have 20px inner padding.
- **Radius**: 16 for cards, 999 for pills, 28 for primary CTAs.
- **Buttons**: black-filled, white text, 56-tall, full-bleed for primary actions. Secondary is white with 1px `#E5E7EB` border.
- **Motion**: tap → 200ms ease-out, haptic light. No flashy transitions.

## 5. Zombie score (PRD §3.2 → `lib/score.ts`)

Single function `computeZombieScore(sub) → 0–100`. Weights:

```
recencyOfLastUse 35%   (days since last open → 0 if today, 100 if 60d+)
usageVsPrice     25%   (sessions per dollar — low = zombie)
overlap          20%   (count of same-category subs → more = zombie)
userRating       15%   (1–5 → inverted)
priceVsMarket     5%   (above-market premium → zombie)
```

Score ≥ 80 → flagged + push prompt. Score 50–79 → "review." <50 → keep.

## 6. Conventions

- Never use real PII / real bank tokens. All sample data lives in `lib/data/mock.ts`.
- Currency formatting: `Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })`.
- All screens must work on iPhone 14-class viewport (390×844). Verify via Expo web before claiming done.
- Tap targets ≥ 44pt.
- Trigger haptics on every destructive or value-changing tap.
- Keep components stateless when possible; hoist state into Zustand.
- Do not add comments that restate the code. Only annotate non-obvious invariants (e.g., the score weights cite PRD §3.2).

## 7. Skills I should reach for

These come from this workstation and are relevant here:

- **superpowers:brainstorming / writing-plans** — before any *new* multi-step feature.
- **superpowers:test-driven-development** — for any pure logic (`lib/score.ts`) where I can write a test before the code.
- **superpowers:verification-before-completion** — checklist gate before marking a feature done.
- **frontend-design:frontend-design** — for major visual decisions on a new screen.
- **design-html / design-shotgun** — if I need design variants on a specific surface.
- **vercel-plugin:react-best-practices** — after non-trivial TSX changes.
- **browse / gstack / qa** — to dogfood the running Expo-web build, take screenshots, file regressions.
- **investigate** — any time something breaks; **never** patch around symptoms.
- **claude-md-management:revise-claude-md** — keep this file accurate as the codebase evolves.

## 8. Running locally

```bash
npm install
npm run web        # opens Expo web on http://localhost:8081
npm run ios        # iOS simulator (requires Xcode)
```

I verify the build by running `npm run web` and driving it with Playwright (via the available browser tools), taking screenshots on each major route, and listening for console errors.

## 9. Shipping to the App Store (out of scope for this session, recorded for future runs)

- EAS Build (`eas build -p ios --profile production`)
- App Store Connect listing copy lives in `store/` (TBD)
- Pre-submit: replace mock data adapter with real Plaid Link + server, configure `app.json` bundle identifier `com.yinanzhai.phantom`

## 10. What "done" means for this session

1. Every PRD §3 feature has a real screen the user can navigate to.
2. Zombie score, dispute letter generation, and price alerts produce real (mocked but plausible) output.
3. `npm run web` boots cleanly with zero console errors.
4. Screenshots of every primary surface have been captured and reviewed.
5. CLAUDE.md and this list are still accurate at end of session.
