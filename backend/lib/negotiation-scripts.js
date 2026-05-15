// Server-side negotiation registry — easier to update without app releases.
// Each entry: known success rate (from public data + observed user reports), channel,
// real contact, script crafted with retention research best practices.

export const negotiationScripts = {
  hulu: {
    vendor: 'Hulu',
    successRate: 68,
    channel: 'chat',
    contact: 'help.hulu.com/chat',
    expectedDiscount: '50% off for 6 months',
    script:
      "Hi — I've been a Hulu subscriber for a while, but my budget is getting tight and I'm comparing it with Netflix and Disney+. Before I cancel, is there any retention offer or discount you can apply to my account? I'd love to stay if there's something that brings the cost down.",
  },
  spotify: {
    vendor: 'Spotify',
    successRate: 32,
    channel: 'chat',
    contact: 'support.spotify.com',
    expectedDiscount: '3 months at $4.99/mo',
    script:
      "Hi — I'm thinking about pausing Spotify and switching to YouTube Music for the family plan pricing. Before I do, is there a loyalty discount or promotional rate you can offer existing customers?",
  },
  sirius: {
    vendor: 'SiriusXM',
    successRate: 87,
    channel: 'phone',
    contact: '1-866-635-2349',
    expectedDiscount: '$5–9 / month for 12 months',
    script:
      "Hi — I'd like to cancel my SiriusXM subscription. The current rate is more than I want to pay. Before I cancel, is there a long-term promotional rate you can offer? I've seen offers around $5/month for a year.",
  },
  'planet-fitness': {
    vendor: 'Planet Fitness Black Card',
    successRate: 22,
    channel: 'phone',
    contact: 'Your home club',
    expectedDiscount: 'Pause for 3 months',
    script:
      "Hi — I haven't been using my membership and would like to either pause it or step down to the basic tier. Can you walk me through my options?",
  },
  audible: {
    vendor: 'Audible Premium',
    successRate: 78,
    channel: 'chat',
    contact: 'audible.com/help',
    expectedDiscount: '3 months at $7.95/mo',
    script:
      "Hi — I'm thinking about cancelling Audible because I'm not finishing the credits each month. Before I do, is there a retention offer or a less expensive plan available?",
  },
  'adobe-cc': {
    vendor: 'Adobe Creative Cloud',
    successRate: 71,
    channel: 'chat',
    contact: 'helpx.adobe.com/contact',
    expectedDiscount: '2 months free',
    script:
      "Hi — I'd like to cancel my Creative Cloud subscription. Before I confirm, are there any loyalty or retention offers available for long-term customers?",
  },
  'amazon-prime': {
    vendor: 'Amazon Prime',
    successRate: 12,
    channel: 'chat',
    contact: 'amazon.com/contact-us',
    expectedDiscount: 'Free month',
    script:
      "Hi — I'm re-evaluating my Prime subscription. Is there any loyalty offer for long-time customers?",
  },
  'directv-stream': {
    vendor: 'DirecTV Stream',
    successRate: 79,
    channel: 'phone',
    contact: '1-800-531-5000',
    expectedDiscount: '$20/mo off for 12 months',
    script:
      "Hi — my promotional rate has ended and the new price is too high. Before I cancel, can you check what retention offers are available on my account?",
  },
  comcast: {
    vendor: 'Xfinity / Comcast',
    successRate: 73,
    channel: 'phone',
    contact: '1-800-934-6489',
    expectedDiscount: '$30–60/mo off for 12 months',
    script:
      "Hi — I'd like to cancel my service. My bill has gone up and I'm comparing with competitors in my area. Can you transfer me to the retention team?",
  },
  'youtube-premium': {
    vendor: 'YouTube Premium',
    successRate: 18,
    channel: 'web',
    contact: 'support.google.com',
    expectedDiscount: 'Family plan downgrade ($22.99 → $13.99 individual)',
    script:
      "I'm cancelling YouTube Premium. Before I do, can you confirm whether downgrading from Family to Individual is available?",
  },
};
