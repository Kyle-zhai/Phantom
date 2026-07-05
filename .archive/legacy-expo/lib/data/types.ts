export type Category = 'Entertainment' | 'Tools' | 'Health' | 'Shopping' | 'News' | 'Other';

export type BillingCycle = 'monthly' | 'yearly' | 'weekly';

export type Subscription = {
  id: string;
  name: string;
  vendor: string;
  brandColor: string;
  category: Category;
  amount: number;
  cycle: BillingCycle;
  nextBilling: string; // ISO
  startedAt: string; // ISO
  lastUsedAt: string | null; // ISO or null
  sessionsLast30d: number;
  userRating: 1 | 2 | 3 | 4 | 5 | null;
  marketAverage: number;
  trialEndsAt?: string;
  hasPriceHike?: { from: number; to: number; effective: string };
  hasOverlapWith?: string[]; // subscription ids
  notes?: string;
};

export type PriceAlert = {
  id: string;
  subscriptionId: string;
  type: 'hike' | 'trial-ending' | 'new-charge' | 'unused';
  title: string;
  message: string;
  createdAt: string;
  read: boolean;
};
