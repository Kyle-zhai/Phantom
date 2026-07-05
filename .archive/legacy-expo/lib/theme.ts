import { Platform, TextStyle } from 'react-native';

export const colors = {
  ink: '#0A0A0A',
  black: '#000000',
  white: '#FFFFFF',
  mute: '#6B7280',
  mute2: '#9CA3AF',
  border: '#E5E7EB',
  surface: '#F4F4F5',
  surface2: '#FAFAFA',
  success: '#10B981',
  successSoft: '#D1FAE5',
  danger: '#EF4444',
  dangerSoft: '#FEE2E2',
  warn: '#F59E0B',
  warnSoft: '#FEF3C7',
  info: '#3B82F6',
  infoSoft: '#DBEAFE',
} as const;

export const radius = {
  xs: 8,
  sm: 12,
  md: 16,
  lg: 20,
  xl: 28,
  pill: 999,
} as const;

export const space = {
  xs: 4,
  s: 8,
  m: 12,
  l: 16,
  xl: 24,
  xxl: 32,
  xxxl: 48,
} as const;

const sfFamily = Platform.select({
  ios: 'System',
  android: 'sans-serif',
  default: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", system-ui, sans-serif',
});

export const type = {
  display: {
    fontFamily: sfFamily,
    fontSize: 44,
    lineHeight: 48,
    fontWeight: '800',
    letterSpacing: -1,
  } satisfies TextStyle,
  h1: {
    fontFamily: sfFamily,
    fontSize: 32,
    lineHeight: 36,
    fontWeight: '800',
    letterSpacing: -0.6,
  } satisfies TextStyle,
  h2: {
    fontFamily: sfFamily,
    fontSize: 24,
    lineHeight: 28,
    fontWeight: '700',
    letterSpacing: -0.3,
  } satisfies TextStyle,
  h3: {
    fontFamily: sfFamily,
    fontSize: 18,
    lineHeight: 22,
    fontWeight: '700',
    letterSpacing: -0.2,
  } satisfies TextStyle,
  body: {
    fontFamily: sfFamily,
    fontSize: 16,
    lineHeight: 24,
    fontWeight: '400',
  } satisfies TextStyle,
  bodyBold: {
    fontFamily: sfFamily,
    fontSize: 16,
    lineHeight: 24,
    fontWeight: '600',
  } satisfies TextStyle,
  small: {
    fontFamily: sfFamily,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '400',
  } satisfies TextStyle,
  smallBold: {
    fontFamily: sfFamily,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '600',
  } satisfies TextStyle,
  micro: {
    fontFamily: sfFamily,
    fontSize: 11,
    lineHeight: 14,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase' as const,
  } satisfies TextStyle,
} as const;

export const shadow = {
  card: Platform.select({
    ios: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.05,
      shadowRadius: 8,
    },
    android: { elevation: 2 },
    default: { boxShadow: '0 2px 8px rgba(0,0,0,0.05)' as unknown as never },
  }),
  lift: Platform.select({
    ios: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 8 },
      shadowOpacity: 0.12,
      shadowRadius: 24,
    },
    android: { elevation: 8 },
    default: { boxShadow: '0 8px 24px rgba(0,0,0,0.12)' as unknown as never },
  }),
} as const;

export function fmtUSD(amount: number, options: Intl.NumberFormatOptions = {}): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
    ...options,
  }).format(amount);
}
