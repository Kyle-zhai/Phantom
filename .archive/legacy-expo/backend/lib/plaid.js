import { Configuration, PlaidApi, PlaidEnvironments } from 'plaid';

const env = (process.env.PLAID_ENV || 'sandbox').toLowerCase();

const baseUrl = PlaidEnvironments[env];
if (!baseUrl) {
  throw new Error(`Unknown PLAID_ENV: ${env}. Expected sandbox | development | production.`);
}

if (!process.env.PLAID_CLIENT_ID || !process.env.PLAID_SECRET) {
  console.warn(
    '[plaid] Missing PLAID_CLIENT_ID or PLAID_SECRET. ' +
      'Sign up free at https://dashboard.plaid.com and add them to backend/.env',
  );
}

const config = new Configuration({
  basePath: baseUrl,
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
      'Plaid-Version': '2020-09-14',
    },
  },
});

export const plaidClient = new PlaidApi(config);
