# docs/ — GitHub Pages site

This directory is served by GitHub Pages at `https://kyle-zhai.github.io/Phantom/`.

## Files

| File | Purpose |
|---|---|
| `index.html` | Landing page |
| `privacy.html` | Privacy Policy (Apple requires a public URL for App Store submission) |
| `terms.html` | Terms of Service |
| `data/prices.json` | Subscription price catalog the iOS app fetches at runtime — no backend needed |

## Enable GitHub Pages

After pushing this repo:

1. Go to **https://github.com/Kyle-zhai/Phantom/settings/pages**
2. Source: deploy from a branch
3. Branch: `main`, folder: `/docs`
4. Save

Within ~60 seconds the site goes live at:

- Landing:  https://kyle-zhai.github.io/Phantom/
- Privacy:  https://kyle-zhai.github.io/Phantom/privacy.html
- Terms:    https://kyle-zhai.github.io/Phantom/terms.html
- Prices:   https://kyle-zhai.github.io/Phantom/data/prices.json

These are the URLs you paste into App Store Connect under *App Privacy* and *Support URL*.

## Custom domain (later, optional)

If you eventually buy `phantom.app` (or any domain):

1. DNS provider → add `CNAME` record: `phantom.app` → `kyle-zhai.github.io`
2. Repo settings → Pages → Custom domain → enter `phantom.app` → save
3. GitHub auto-provisions HTTPS in ~10 minutes
4. Update `ios-native/Phantom/Services/AppConfig.swift` → `priceCatalogURL` to `https://phantom.app/data/prices.json`

Until then the default `kyle-zhai.github.io/Phantom/` URLs work perfectly for App Store submission.

## What to fill in before launch

Open `privacy.html` and `terms.html`, search for `[YOUR LEGAL NAME]` and `[YOUR ADDRESS OR VIRTUAL MAILBOX]`, replace with your real info.

Search: `Kyle Zhai` is recommended for legal name if that's your real name. Address can be your home address or a virtual-mailbox service like iPostal1 ($9/month) if you want privacy.
