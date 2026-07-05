import type { Subscription } from './data/types';

export type ScoreBreakdown = {
  score: number;
  recencyOfLastUse: number;
  usageVsPrice: number;
  overlap: number;
  userRating: number;
  priceVsMarket: number;
};

const clamp = (n: number, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, n));

export function daysSince(iso: string | null, now: Date = new Date()): number {
  if (!iso) return 9999;
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return 9999;
  return Math.max(0, Math.floor((now.getTime() - t) / 86_400_000));
}

export function computeZombieScore(sub: Subscription, now: Date = new Date()): ScoreBreakdown {
  // 35% — recency of last use. 0d → 0, 60d+ → 100. Linear in between.
  const days = daysSince(sub.lastUsedAt, now);
  const recencyOfLastUse = clamp((days / 60) * 100);

  // 25% — usage vs price. sessions per dollar. <0.05 → 100, >2 → 0.
  const monthlyAmt = sub.cycle === 'yearly' ? sub.amount / 12 : sub.cycle === 'weekly' ? sub.amount * 4.33 : sub.amount;
  const ratio = monthlyAmt > 0 ? sub.sessionsLast30d / monthlyAmt : 0;
  const usageVsPrice = clamp(100 - clamp(ratio / 2 * 100));

  // 20% — overlap with similar-category subs.
  const overlapCount = sub.hasOverlapWith?.length ?? 0;
  const overlap = clamp(overlapCount * 50);

  // 15% — user rating, inverted. 5 → 0, 1 → 100, null → 50.
  const userRating = sub.userRating == null ? 50 : clamp((5 - sub.userRating) * 25);

  // 5% — price vs market. premium above market.
  const premium = sub.marketAverage > 0 ? (monthlyAmt - sub.marketAverage) / sub.marketAverage : 0;
  const priceVsMarket = clamp(premium * 200);

  const score = Math.round(
    recencyOfLastUse * 0.35 +
      usageVsPrice * 0.25 +
      overlap * 0.2 +
      userRating * 0.15 +
      priceVsMarket * 0.05,
  );

  return {
    score: clamp(score),
    recencyOfLastUse: Math.round(recencyOfLastUse),
    usageVsPrice: Math.round(usageVsPrice),
    overlap: Math.round(overlap),
    userRating: Math.round(userRating),
    priceVsMarket: Math.round(priceVsMarket),
  };
}

export function tierFor(score: number): 'zombie' | 'review' | 'keep' {
  if (score >= 80) return 'zombie';
  if (score >= 50) return 'review';
  return 'keep';
}

export function monthlyAmount(sub: Subscription): number {
  if (sub.cycle === 'yearly') return sub.amount / 12;
  if (sub.cycle === 'weekly') return sub.amount * 4.33;
  return sub.amount;
}
