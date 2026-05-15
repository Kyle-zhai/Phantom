// Price monitor — tracks current published prices for major US subscription services.
// Strategy:
//   - Seeded list of known prices keeps the system useful out of the box (50+ services)
//   - When PRICE_MONITOR_LIVE=true, attempt to scrape the public pricing page and
//     compare to the seed; flag any change.
//   - In production, replace the scraper with partner feeds or a paid pricing API.

import * as cheerio from 'cheerio';
import { SEED_PRICES } from '../data/seed-prices.js';

const lastSnapshot = new Map(SEED_PRICES.map((p) => [p.id, p]));

export async function knownPrices() {
  return Array.from(lastSnapshot.values());
}

export async function monitorPrices({ live = false } = {}) {
  if (!live) {
    // Inject tiny variations to demo the "price-hike alert" pipeline end-to-end
    const out = [];
    for (const seed of SEED_PRICES) {
      const cur = lastSnapshot.get(seed.id) ?? seed;
      // 5% of services bump price each refresh in demo mode
      if (Math.random() < 0.05) {
        const newPrice = +(cur.priceMonthly * (1 + 0.05 + Math.random() * 0.15)).toFixed(2);
        const updated = { ...cur, prevPrice: cur.priceMonthly, priceMonthly: newPrice, hikedAt: new Date().toISOString() };
        lastSnapshot.set(seed.id, updated);
        out.push(updated);
      } else {
        out.push(cur);
      }
    }
    return out;
  }

  // LIVE mode: try to fetch each service's published pricing page and parse a $X.YY token.
  // This is best-effort — most pricing pages are JS-rendered or split across plans.
  const updated = [];
  for (const seed of SEED_PRICES) {
    if (!seed.pricingUrl) {
      updated.push(seed);
      continue;
    }
    try {
      const r = await fetch(seed.pricingUrl, {
        headers: { 'user-agent': 'SubSpyPriceBot/1.0' },
        // 8s timeout via AbortController
        signal: AbortSignal.timeout(8000),
      });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const html = await r.text();
      const $ = cheerio.load(html);
      const text = $('body').text();
      // Grab the first plausible monthly price near the brand's current band
      const matches = [...text.matchAll(/\$(\d{1,3}(?:\.\d{2}))(?:\s*\/?\s*(?:mo|month))?/gi)]
        .map((m) => +m[1])
        .filter((p) => p > seed.priceMonthly * 0.4 && p < seed.priceMonthly * 2.5);
      if (matches.length) {
        const newPrice = matches[0];
        if (Math.abs(newPrice - seed.priceMonthly) > 0.01) {
          updated.push({ ...seed, prevPrice: seed.priceMonthly, priceMonthly: newPrice, hikedAt: new Date().toISOString() });
          lastSnapshot.set(seed.id, updated[updated.length - 1]);
          continue;
        }
      }
      updated.push(seed);
    } catch (err) {
      // Don't fail the whole batch on one bad scrape
      updated.push({ ...seed, scrapeError: String(err).slice(0, 120) });
    }
  }
  return updated;
}
