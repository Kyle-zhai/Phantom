// Detect recurring (subscription-like) charges from a list of Plaid transactions.
// Strategy:
//   1. Group by normalized merchant name
//   2. For each group with ≥ 2 charges, compute median gap-in-days
//   3. If gap ∈ {6..9, 13..16, 28..32, 88..95, 363..368} flag as weekly/biweekly/monthly/quarterly/yearly
//   4. Stable-id each subscription, infer next billing, brand from merchant_name + category

const CYCLE_RULES = [
  { min: 6, max: 9, label: 'weekly' },
  { min: 13, max: 16, label: 'biweekly' },
  { min: 28, max: 32, label: 'monthly' },
  { min: 88, max: 95, label: 'quarterly' },
  { min: 363, max: 368, label: 'yearly' },
];

function normalizeMerchant(name) {
  if (!name) return '';
  return name
    .toLowerCase()
    .replace(/^(payment to|recurring |autopay )/, '')
    .replace(/\s+(co|inc|llc|ltd|corp)\.?$/i, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function slug(name) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function median(arr) {
  const s = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

const CATEGORY_MAP = {
  'Service Subscription': 'Entertainment',
  'Subscription': 'Entertainment',
  'Streaming Services': 'Entertainment',
  'Music and Audio': 'Entertainment',
  'Gym and Fitness Centers': 'Health',
  'Health and Fitness': 'Health',
  'Software': 'Tools',
  'Computers and Electronics': 'Tools',
  'Shops': 'Shopping',
  'Digital Purchase': 'Tools',
  'News and Magazines': 'News',
};

function pickCategory(t) {
  const cats = t.personal_finance_category?.primary || t.category?.[0];
  if (!cats) return 'Other';
  for (const [k, v] of Object.entries(CATEGORY_MAP)) {
    if (cats.toLowerCase().includes(k.toLowerCase())) return v;
  }
  return 'Other';
}

function brandColorHash(s) {
  // Stable color per merchant — deterministic, not random
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) & 0xffffff;
  const hue = h % 360;
  // Pick a saturated, mid-light color
  const s1 = 70 + (h % 20);
  const l = 45 + (h % 10);
  return hslToHex(hue, s1, l);
}

function hslToHex(h, s, l) {
  s /= 100; l /= 100;
  const k = (n) => (n + h / 30) % 12;
  const a = s * Math.min(l, 1 - l);
  const f = (n) =>
    Math.round(255 * (l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)))));
  return `${f(0).toString(16).padStart(2, '0')}${f(8).toString(16).padStart(2, '0')}${f(4).toString(16).padStart(2, '0')}`.toUpperCase();
}

export function detectRecurring(transactions) {
  const groups = new Map();
  for (const t of transactions) {
    if (t.amount <= 0) continue; // skip credits
    const merchant = t.merchant_name || t.name || 'Unknown';
    const key = normalizeMerchant(merchant);
    if (!key) continue;
    if (!groups.has(key)) groups.set(key, { merchant, items: [] });
    groups.get(key).items.push(t);
  }

  const subs = [];
  for (const [key, group] of groups) {
    if (group.items.length < 2) continue;
    const sortedByDate = [...group.items].sort((a, b) => new Date(a.date) - new Date(b.date));
    const gaps = [];
    for (let i = 1; i < sortedByDate.length; i++) {
      const d1 = new Date(sortedByDate[i - 1].date);
      const d2 = new Date(sortedByDate[i].date);
      gaps.push(Math.round((d2 - d1) / 86_400_000));
    }
    const medGap = median(gaps);
    const rule = CYCLE_RULES.find((r) => medGap >= r.min && medGap <= r.max);
    if (!rule) continue;

    // Amount stability: charges within ±15% of median amount
    const amounts = sortedByDate.map((t) => t.amount);
    const medAmt = median(amounts);
    const stableCharges = amounts.filter((a) => Math.abs(a - medAmt) / medAmt < 0.15);
    if (stableCharges.length < 2) continue;

    const latest = sortedByDate[sortedByDate.length - 1];
    const startedAt = new Date(sortedByDate[0].date).toISOString();
    const lastChargedAt = new Date(latest.date).toISOString();
    const nextBilling = new Date(new Date(latest.date).getTime() + medGap * 86_400_000).toISOString();

    subs.push({
      id: slug(key),
      name: titleCase(group.merchant),
      vendor: group.merchant,
      brandHex: brandColorHash(key),
      category: pickCategory(latest),
      amount: Math.round(medAmt * 100) / 100,
      cycle: rule.label,
      nextBilling,
      startedAt,
      lastChargedAt,
      chargesObserved: sortedByDate.length,
      // Defaults — to be enriched client-side with user-supplied data
      sessionsLast30d: null,
      lastUsedAt: null,
      userRating: null,
      marketAverage: medAmt,
      hasPriceHike: null,
      hasOverlapWith: [],
      notes: null,
    });
  }

  // Sort by amount desc so biggest spends surface first
  return subs.sort((a, b) => b.amount - a.amount);
}

function titleCase(s) {
  return s
    .split(/\s+/)
    .map((w) => (w.length ? w[0].toUpperCase() + w.slice(1).toLowerCase() : w))
    .join(' ');
}
