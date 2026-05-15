import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { plaidClient } from './lib/plaid.js';
import { detectRecurring } from './lib/recurring.js';
import { knownPrices, monitorPrices } from './lib/prices.js';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true, ts: Date.now() }));

// 6. Account delete — App Store Review Guideline 5.1.1(v) requires accounts can be deleted.
//    In production: revoke Plaid Item, purge user from DB, send confirmation email.
app.post('/account/delete', async (req, res) => {
  try {
    const { userId, accessToken } = req.body || {};
    if (!userId) return res.status(400).json({ error: 'user_id_required' });
    if (accessToken) {
      try { await plaidClient.itemRemove({ access_token: accessToken }); } catch {}
    }
    // TODO(prod): purge user rows here once you persist user data server-side
    res.json({ ok: true, deletedUserId: userId });
  } catch (err) {
    res.status(500).json({ error: 'delete_failed', detail: String(err) });
  }
});

// 1. Issue a Link token for the iOS Plaid Link flow
app.post('/plaid/link-token', async (req, res) => {
  try {
    const { userId = `subspy-${Date.now()}` } = req.body || {};
    const r = await plaidClient.linkTokenCreate({
      user: { client_user_id: userId },
      client_name: 'SubSpy',
      products: ['transactions'],
      country_codes: ['US'],
      language: 'en',
      redirect_uri: undefined,
    });
    res.json({ linkToken: r.data.link_token, expiration: r.data.expiration });
  } catch (err) {
    console.error('link-token error', err?.response?.data || err);
    res.status(500).json({ error: 'link_token_failed', detail: err?.response?.data || String(err) });
  }
});

// 2. Exchange public_token (returned by Link) for a long-lived access_token
app.post('/plaid/exchange', async (req, res) => {
  try {
    const { publicToken } = req.body || {};
    if (!publicToken) return res.status(400).json({ error: 'public_token_required' });
    const r = await plaidClient.itemPublicTokenExchange({ public_token: publicToken });
    res.json({ accessToken: r.data.access_token, itemId: r.data.item_id });
  } catch (err) {
    console.error('exchange error', err?.response?.data || err);
    res.status(500).json({ error: 'exchange_failed', detail: err?.response?.data || String(err) });
  }
});

// 3. Fetch transactions, detect recurring, decorate with zombie hints
app.post('/plaid/transactions', async (req, res) => {
  try {
    const { accessToken, days = 90 } = req.body || {};
    if (!accessToken) return res.status(400).json({ error: 'access_token_required' });
    const end = new Date();
    const start = new Date(end.getTime() - days * 86_400_000);
    const fmt = (d) => d.toISOString().split('T')[0];
    let all = [];
    let cursor = undefined;
    // /transactions/sync gives a deterministic cursor-paged response
    while (true) {
      const r = await plaidClient.transactionsSync({
        access_token: accessToken,
        cursor,
        count: 500,
      });
      all = all.concat(r.data.added);
      cursor = r.data.next_cursor;
      if (!r.data.has_more) break;
    }
    const filtered = all.filter((t) => {
      const d = new Date(t.date);
      return d >= start && d <= end;
    });
    const subscriptions = detectRecurring(filtered);
    res.json({ count: filtered.length, subscriptions });
  } catch (err) {
    console.error('transactions error', err?.response?.data || err);
    res.status(500).json({ error: 'transactions_failed', detail: err?.response?.data || String(err) });
  }
});

// 4. Price-hike monitor: returns known current prices for major subscription services
app.get('/prices', async (_req, res) => {
  const prices = await knownPrices();
  res.json({ prices, count: prices.length, updatedAt: new Date().toISOString() });
});

app.post('/prices/refresh', async (_req, res) => {
  try {
    const live = process.env.PRICE_MONITOR_LIVE === 'true';
    const prices = await monitorPrices({ live });
    res.json({ prices, live, updatedAt: new Date().toISOString() });
  } catch (err) {
    console.error('prices error', err);
    res.status(500).json({ error: 'prices_failed', detail: String(err) });
  }
});

// 5. Vendor negotiation registry — server-side so we can update without app updates
app.get('/negotiate/scripts', async (_req, res) => {
  const { negotiationScripts } = await import('./lib/negotiation-scripts.js');
  res.json({ scripts: negotiationScripts, updatedAt: new Date().toISOString() });
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => {
  console.log(`SubSpy backend listening on :${port}`);
});

export default app;
