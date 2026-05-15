import { create } from 'zustand';
import { MOCK_ALERTS, MOCK_SUBSCRIPTIONS } from './data/mock';
import type { PriceAlert, Subscription } from './data/types';
import { computeZombieScore, monthlyAmount } from './score';

export type SubWithScore = Subscription & { score: number };

type State = {
  isOnboarded: boolean;
  subscriptions: SubWithScore[];
  alerts: PriceAlert[];
  isPro: boolean;
  cancelledIds: string[];

  completeOnboarding: () => void;
  resetOnboarding: () => void;
  cancelSubscription: (id: string) => void;
  reactivateSubscription: (id: string) => void;
  markAlertRead: (id: string) => void;
  togglePro: () => void;
};

const withScores = (subs: Subscription[]): SubWithScore[] =>
  subs.map((s) => ({ ...s, score: computeZombieScore(s).score }));

export const useStore = create<State>((set) => ({
  isOnboarded: false,
  subscriptions: withScores(MOCK_SUBSCRIPTIONS),
  alerts: MOCK_ALERTS,
  isPro: false,
  cancelledIds: [],

  completeOnboarding: () => set({ isOnboarded: true }),
  resetOnboarding: () => set({ isOnboarded: false }),
  cancelSubscription: (id) =>
    set((s) => ({ cancelledIds: Array.from(new Set([...s.cancelledIds, id])) })),
  reactivateSubscription: (id) =>
    set((s) => ({ cancelledIds: s.cancelledIds.filter((x) => x !== id) })),
  markAlertRead: (id) =>
    set((s) => ({
      alerts: s.alerts.map((a) => (a.id === id ? { ...a, read: true } : a)),
    })),
  togglePro: () => set((s) => ({ isPro: !s.isPro })),
}));

export function selectActiveSubs(state: State): SubWithScore[] {
  return state.subscriptions.filter((s) => !state.cancelledIds.includes(s.id));
}

export function selectMonthlyTotal(state: State): number {
  return selectActiveSubs(state).reduce((sum, s) => sum + monthlyAmount(s), 0);
}

export function selectPotentialSavings(state: State): number {
  return selectActiveSubs(state)
    .filter((s) => s.score >= 80)
    .reduce((sum, s) => sum + monthlyAmount(s), 0);
}

export function selectZombieCount(state: State): number {
  return selectActiveSubs(state).filter((s) => s.score >= 80).length;
}
