import { Feather, Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Badge } from '../components/ui/Badge';
import { Button } from '../components/ui/Button';
import { Screen } from '../components/ui/Screen';
import { useStore } from '../lib/store';
import { colors, radius, type } from '../lib/theme';

type Plan = 'monthly' | 'yearly';

const PERKS = [
  'Unlimited subscription scans',
  'Zombie Score on every subscription',
  '7-day price-hike alerts',
  'Unlimited dispute letters',
  'Retention negotiation scripts',
  'Priority chat support',
];

export default function Paywall() {
  const togglePro = useStore((s) => s.togglePro);
  const [plan, setPlan] = useState<Plan>('yearly');

  const subscribe = () => {
    togglePro();
    router.back();
  };

  return (
    <Screen scroll>
      <View style={styles.topBar}>
        <Pressable onPress={() => router.back()} style={styles.closeBtn}>
          <Feather name="x" size={22} color={colors.ink} />
        </Pressable>
        <View style={{ width: 40 }} />
      </View>

      <View style={styles.hero}>
        <View style={styles.logo}>
          <Ionicons name="sparkles" size={28} color={colors.white} />
        </View>
        <Text style={[type.h1, { color: colors.ink, marginTop: 22, textAlign: 'center' }]}>
          Phantom Pro
        </Text>
        <Text style={[type.body, { color: colors.mute, marginTop: 8, textAlign: 'center', maxWidth: 320 }]}>
          Most Pro users save $47/month on average. Pro pays for itself in week one.
        </Text>
      </View>

      <View style={styles.plans}>
        <Pressable onPress={() => setPlan('yearly')} style={[styles.plan, plan === 'yearly' && styles.planActive]}>
          {plan === 'yearly' && (
            <View style={styles.bestTag}>
              <Text style={[type.micro, { color: colors.white }]}>BEST VALUE</Text>
            </View>
          )}
          <View style={styles.planHead}>
            <Text style={[type.h3, { color: colors.ink }]}>Annual</Text>
            <View style={[styles.radio, plan === 'yearly' && styles.radioOn]}>
              {plan === 'yearly' && <View style={styles.radioInner} />}
            </View>
          </View>
          <Text style={[type.display, { color: colors.ink, marginTop: 8 }]}>$29.99</Text>
          <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>
            per year · $2.50 / month · save 37%
          </Text>
          <Badge label="Refund within 30 days" tone="keep" style={{ marginTop: 12 }} />
        </Pressable>

        <Pressable onPress={() => setPlan('monthly')} style={[styles.plan, plan === 'monthly' && styles.planActive]}>
          <View style={styles.planHead}>
            <Text style={[type.h3, { color: colors.ink }]}>Monthly</Text>
            <View style={[styles.radio, plan === 'monthly' && styles.radioOn]}>
              {plan === 'monthly' && <View style={styles.radioInner} />}
            </View>
          </View>
          <Text style={[type.display, { color: colors.ink, marginTop: 8 }]}>$3.99</Text>
          <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>per month · cancel anytime</Text>
        </Pressable>
      </View>

      <View style={styles.perks}>
        {PERKS.map((perk) => (
          <View key={perk} style={styles.perkRow}>
            <View style={styles.checkmark}>
              <Feather name="check" size={14} color={colors.white} />
            </View>
            <Text style={[type.body, { color: colors.ink, flex: 1 }]}>{perk}</Text>
          </View>
        ))}
      </View>

      <View style={styles.guarantee}>
        <Ionicons name="shield-checkmark" size={20} color={colors.success} />
        <Text style={[type.small, { color: colors.ink, flex: 1 }]}>
          We <Text style={{ fontWeight: '700' }}>never</Text> sell your data and <Text style={{ fontWeight: '700' }}>never</Text> push loans. Cancel any time.
        </Text>
      </View>

      <View style={{ height: 20 }} />
      <Button label={plan === 'yearly' ? 'Start Pro · $29.99 / year' : 'Start Pro · $3.99 / month'} onPress={subscribe} />
      <View style={{ height: 12 }} />
      <Button label="Continue with Free" variant="ghost" onPress={() => router.back()} />

      <Text style={[type.small, { color: colors.mute2, textAlign: 'center', marginTop: 16 }]}>
        Auto-renews. Cancel any time in Settings.
      </Text>

      <View style={{ height: 20 }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  topBar: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 4 },
  closeBtn: {
    width: 40,
    height: 40,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hero: { alignItems: 'center', marginTop: 8 },
  logo: {
    width: 72,
    height: 72,
    borderRadius: radius.lg,
    backgroundColor: colors.black,
    alignItems: 'center',
    justifyContent: 'center',
  },
  plans: { marginTop: 30, gap: 12 },
  plan: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    padding: 18,
    backgroundColor: colors.white,
  },
  planActive: { borderColor: colors.ink, borderWidth: 2 },
  bestTag: {
    position: 'absolute',
    top: -10,
    right: 16,
    backgroundColor: colors.ink,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: radius.pill,
  },
  planHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  radio: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    borderColor: colors.mute2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioOn: { borderColor: colors.ink },
  radioInner: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.ink },
  perks: { marginTop: 30, gap: 14 },
  perkRow: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  checkmark: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.success,
    alignItems: 'center',
    justifyContent: 'center',
  },
  guarantee: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginTop: 24,
    padding: 16,
    backgroundColor: colors.successSoft,
    borderRadius: radius.md,
  },
});
