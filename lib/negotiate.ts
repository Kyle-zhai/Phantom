import type { Subscription } from './data/types';

export type NegotiationOffer = {
  vendor: string;
  successRate: number;
  averageSaving: number;
  expectedDiscount: string;
  script: string;
  channel: 'phone' | 'chat';
  contact?: string;
};

const REGISTRY: Record<string, Omit<NegotiationOffer, 'vendor' | 'averageSaving'>> = {
  hulu: {
    successRate: 68,
    expectedDiscount: '50% off for 6 months',
    channel: 'chat',
    contact: 'help.hulu.com/chat',
    script:
      'Hi — I\'ve been a Hulu subscriber for a while, but my budget is getting tight and I\'m comparing it with Netflix and Disney+. Before I cancel, is there any retention offer or discount you can apply to my account? I\'d love to stay if there\'s something that brings the cost down.',
  },
  spotify: {
    successRate: 32,
    expectedDiscount: '3 months at $4.99/mo',
    channel: 'chat',
    contact: 'support.spotify.com',
    script:
      'Hi — I\'m thinking about pausing Spotify and switching to YouTube Music for the family plan pricing. Before I do, is there a loyalty discount or promotional rate you can offer existing customers?',
  },
  sirius: {
    successRate: 87,
    expectedDiscount: '$5–9 / month for 12 months',
    channel: 'phone',
    contact: '1-866-635-2349',
    script:
      'Hi — I\'d like to cancel my SiriusXM subscription. The current rate is more than I want to pay. Before I cancel, is there a long-term promotional rate you can offer? I\'ve seen offers around $5/month for a year.',
  },
  'planet-fitness': {
    successRate: 22,
    expectedDiscount: 'Pause for 3 months',
    channel: 'phone',
    contact: 'Your home club',
    script:
      'Hi — I haven\'t been using my membership and would like to either pause it or step down to the basic tier. Can you walk me through my options?',
  },
  audible: {
    successRate: 78,
    expectedDiscount: '3 months at $7.95/mo',
    channel: 'chat',
    contact: 'audible.com/help',
    script:
      'Hi — I\'m thinking about cancelling Audible because I\'m not finishing the credits each month. Before I do, is there a retention offer or a less expensive plan available?',
  },
  'adobe-cc': {
    successRate: 71,
    expectedDiscount: '2 months free',
    channel: 'chat',
    contact: 'helpx.adobe.com/contact',
    script:
      'Hi — I\'d like to cancel my Creative Cloud subscription. Before I confirm, are there any loyalty or retention offers available for long-term customers?',
  },
  'amazon-prime': {
    successRate: 12,
    expectedDiscount: 'Free month',
    channel: 'chat',
    contact: 'amazon.com/contact-us',
    script:
      'Hi — I\'m re-evaluating my Prime subscription. Is there any loyalty offer for long-time customers?',
  },
};

export function negotiationFor(sub: Subscription): NegotiationOffer | null {
  const entry = REGISTRY[sub.id];
  if (!entry) return null;
  return {
    ...entry,
    vendor: sub.name,
    averageSaving: Math.round(sub.amount * 0.4 * 12 * 100) / 100,
  };
}

export function allKnownNegotiations(subs: Subscription[]): NegotiationOffer[] {
  return subs
    .map((s) => negotiationFor(s))
    .filter((x): x is NegotiationOffer => x !== null)
    .sort((a, b) => b.averageSaving - a.averageSaving);
}
