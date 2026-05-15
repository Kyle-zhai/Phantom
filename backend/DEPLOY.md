# Deploying the Phantom backend

The backend is a vanilla Express app. We use **Vercel** because it's free for small projects and one command from here to production.

## One-time setup

```bash
# 1. Install Vercel CLI
npm i -g vercel@latest

# 2. From /backend/, link the directory to a Vercel project
cd backend
vercel link
# Pick "Create a new project", name it "phantom-backend"

# 3. Set production env vars (these are encrypted by Vercel, not stored in git)
vercel env add PLAID_CLIENT_ID production
# paste your client_id when prompted

vercel env add PLAID_SECRET production
# paste your PRODUCTION secret (only after Plaid approves you)

vercel env add PLAID_ENV production
# type: production
```

For sandbox / preview deployments use `vercel env add VAR preview` with your sandbox secret.

## Deploy

```bash
vercel deploy --prod
```

Output:
```
✅ Production: https://phantom-backend.vercel.app
```

Copy that URL. You'll plug it into the iOS app in the next step.

## Wire iOS to production backend

Edit `ios-native/Phantom.xcconfig` (or `Release.xcconfig` if you split, see `production-xcconfig` task):

```
PHANTOM_API_BASE = https://phantom-backend.vercel.app
PLAID_ENVIRONMENT = production
```

Then rebuild — the app reads from `Info.plist` which is populated from these.

## Smoke test

```bash
curl https://phantom-backend.vercel.app/health
# → {"ok":true,"ts":1729...}

curl https://phantom-backend.vercel.app/prices | jq '.count'
# → 55  (or whatever your seed contains)
```

## Custom domain (optional)

```bash
vercel domains add api.phantom.com
# Follow the DNS-record instructions Vercel prints out
vercel alias set phantom-backend.vercel.app api.phantom.com
```

Then update `PHANTOM_API_BASE = https://api.phantom.com`.

## Monitoring

Vercel includes:
- Function logs at https://vercel.com/[your-team]/phantom-backend/logs
- Request analytics
- Build status

For alerts (page on errors), add the Vercel Slack or Discord integration in dashboard → Integrations.

## Rolling back

```bash
vercel ls --prod          # see recent prod deployments
vercel rollback <url>     # promote an older one to prod
```

## Cost expectations

| Tier | When you hit it |
|---|---|
| Hobby (free) | Up to ~100K invocations / month |
| Pro ($20/mo) | If you grow past hobby; includes team features, larger functions |

For Phantom's MVP traffic (a few hundred users), free tier is enough indefinitely. Plaid will be your bigger cost — see `plaid/SECURITY_QUESTIONNAIRE.md`.
