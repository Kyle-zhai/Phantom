import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useMemo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Screen } from '../../components/ui/Screen';
import { Section } from '../../components/ui/Section';
import { SubscriptionRow } from '../../components/ui/SubscriptionRow';
import { monthlyAmount } from '../../lib/score';
import {
  selectActiveSubs,
  selectMonthlyTotal,
  selectPotentialSavings,
  selectZombieCount,
  useStore,
} from '../../lib/store';
import { colors, fmtUSD, radius, type } from '../../lib/theme';

export default function Radar() {
  const state = useStore();
  const subs = selectActiveSubs(state);
  const total = selectMonthlyTotal(state);
  const savings = selectPotentialSavings(state);
  const zombieCount = selectZombieCount(state);
  const unreadAlerts = state.alerts.filter((a) => !a.read).length;

  const grouped = useMemo(() => {
    const zombies = subs.filter((s) => s.score >= 80).sort((a, b) => b.score - a.score);
    const review = subs.filter((s) => s.score >= 50 && s.score < 80).sort((a, b) => b.score - a.score);
    const keep = subs.filter((s) => s.score < 50).sort((a, b) => monthlyAmount(b) - monthlyAmount(a));
    return { zombies, review, keep };
  }, [subs]);

  const cancelled = state.subscriptions.filter((s) => state.cancelledIds.includes(s.id));

  return (
    <Screen>
      <View style={styles.header}>
        <View>
          <Text style={[type.smallBold, { color: colors.mute }]}>RADAR</Text>
          <Text style={[type.h1, { color: colors.ink, marginTop: 2 }]}>Your subscriptions</Text>
        </View>
        <Pressable onPress={() => router.push('/(tabs)/settings')} style={styles.profile}>
          <Feather name="user" size={20} color={colors.ink} />
        </Pressable>
      </View>

      <View style={styles.hero}>
        <Text style={[type.smallBold, { color: '#9CA3AF' }]}>EVERY MONTH</Text>
        <Text style={[type.display, { color: colors.white, marginTop: 8 }]}>{fmtUSD(total)}</Text>
        <View style={styles.heroStats}>
          <View style={styles.heroStat}>
            <Text style={[type.smallBold, { color: '#9CA3AF' }]}>ACTIVE</Text>
            <Text style={[type.h3, { color: colors.white, marginTop: 2 }]}>{subs.length}</Text>
          </View>
          <View style={styles.heroDivider} />
          <View style={styles.heroStat}>
            <Text style={[type.smallBold, { color: '#9CA3AF' }]}>ZOMBIES</Text>
            <Text style={[type.h3, { color: colors.danger, marginTop: 2 }]}>{zombieCount}</Text>
          </View>
          <View style={styles.heroDivider} />
          <View style={styles.heroStat}>
            <Text style={[type.smallBold, { color: '#9CA3AF' }]}>ALERTS</Text>
            <Text style={[type.h3, { color: colors.white, marginTop: 2 }]}>{unreadAlerts}</Text>
          </View>
        </View>
      </View>

      {savings > 0 && (
        <Card style={styles.savingsCard}>
          <View style={styles.savingsRow}>
            <View style={styles.savingsIcon}>
              <Feather name="trending-down" size={20} color={colors.success} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={[type.smallBold, { color: colors.success }]}>POTENTIAL MONTHLY SAVINGS</Text>
              <Text style={[type.h1, { color: colors.ink, marginTop: 2 }]}>{fmtUSD(savings)}</Text>
              <Text style={[type.small, { color: colors.mute, marginTop: 4 }]}>
                Cancel the {zombieCount} zombie {zombieCount === 1 ? 'subscription' : 'subscriptions'} below to claim it.
              </Text>
            </View>
          </View>
        </Card>
      )}

      {grouped.zombies.length > 0 && (
        <Section
          title="Zombies"
          caption="These have been silent. Score ≥ 80."
          right={<Badge label={`${grouped.zombies.length}`} tone="zombie" />}
        >
          <View style={styles.list}>
            {grouped.zombies.map((sub) => (
              <SubscriptionRow
                key={sub.id}
                sub={sub}
                onPress={() => router.push(`/subscription/${sub.id}`)}
              />
            ))}
          </View>
        </Section>
      )}

      {grouped.review.length > 0 && (
        <Section
          title="Worth a second look"
          caption="Use is dropping. Score 50–79."
          right={<Badge label={`${grouped.review.length}`} tone="review" />}
        >
          <View style={styles.list}>
            {grouped.review.map((sub) => (
              <SubscriptionRow
                key={sub.id}
                sub={sub}
                onPress={() => router.push(`/subscription/${sub.id}`)}
              />
            ))}
          </View>
        </Section>
      )}

      {grouped.keep.length > 0 && (
        <Section title="In active use" caption="You're getting value here.">
          <View style={styles.list}>
            {grouped.keep.map((sub) => (
              <SubscriptionRow
                key={sub.id}
                sub={sub}
                onPress={() => router.push(`/subscription/${sub.id}`)}
              />
            ))}
          </View>
        </Section>
      )}

      {cancelled.length > 0 && (
        <Section
          title="Cancelled this session"
          right={<Badge label={fmtUSD(cancelled.reduce((s, x) => s + monthlyAmount(x), 0))} tone="keep" />}
        >
          <View style={styles.list}>
            {cancelled.map((sub) => (
              <SubscriptionRow
                key={sub.id}
                sub={{ ...sub, score: state.subscriptions.find((x) => x.id === sub.id)?.score ?? 0 }}
                onPress={() => router.push(`/subscription/${sub.id}`)}
                cancelled
                showScore={false}
              />
            ))}
          </View>
        </Section>
      )}

      <View style={{ height: 20 }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    marginTop: 4,
  },
  profile: {
    width: 40,
    height: 40,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hero: {
    marginTop: 20,
    backgroundColor: colors.black,
    borderRadius: radius.lg,
    padding: 24,
  },
  heroStats: { flexDirection: 'row', marginTop: 22, alignItems: 'center' },
  heroStat: { flex: 1 },
  heroDivider: { width: 1, height: 36, backgroundColor: '#2A2A2A', marginHorizontal: 8 },
  savingsCard: { marginTop: 16 },
  savingsRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 14 },
  savingsIcon: {
    width: 44,
    height: 44,
    borderRadius: radius.sm,
    backgroundColor: colors.successSoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  list: {
    backgroundColor: colors.white,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: 12,
    paddingVertical: 4,
  },
});
