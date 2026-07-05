import { Feather, Ionicons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { Alert, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { Avatar } from '../../components/ui/Avatar';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Screen } from '../../components/ui/Screen';
import { Section } from '../../components/ui/Section';
import { ZombieMeter } from '../../components/ui/ZombieMeter';
import { computeZombieScore, daysSince, monthlyAmount, tierFor } from '../../lib/score';
import { useStore } from '../../lib/store';
import { colors, fmtUSD, radius, type } from '../../lib/theme';

export default function SubscriptionDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const sub = useStore((s) => s.subscriptions.find((x) => x.id === id));
  const cancelled = useStore((s) => s.cancelledIds.includes(id ?? ''));
  const cancelSub = useStore((s) => s.cancelSubscription);
  const reactivate = useStore((s) => s.reactivateSubscription);

  if (!sub) {
    return (
      <Screen>
        <Text style={[type.h2, { color: colors.ink }]}>Not found</Text>
      </Screen>
    );
  }

  const breakdown = computeZombieScore(sub);
  const tier = tierFor(breakdown.score);
  const monthly = monthlyAmount(sub);
  const yearly = monthly * 12;
  const sinceLastUse = daysSince(sub.lastUsedAt);
  const accruedSinceLastUse = (sinceLastUse / 30) * monthly;

  const confirmCancel = () => {
    const doIt = () => {
      cancelSub(sub.id);
      router.back();
    };
    if (Platform.OS === 'web') {
      doIt();
    } else {
      Alert.alert(
        `Cancel ${sub.name}?`,
        `This stops the recurring charge. You'll save ${fmtUSD(monthly)} per month.`,
        [
          { text: 'Keep it', style: 'cancel' },
          { text: 'Cancel subscription', style: 'destructive', onPress: doIt },
        ],
      );
    }
  };

  return (
    <Screen>
      <View style={styles.topBar}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <Feather name="chevron-left" size={22} color={colors.ink} />
        </Pressable>
        <Text style={[type.smallBold, { color: colors.mute }]}>{sub.category.toUpperCase()}</Text>
        <View style={{ width: 40 }} />
      </View>

      <View style={styles.heroRow}>
        <Avatar label={sub.name} bg={sub.brandColor} fg={colors.white} size={72} />
        <View style={{ flex: 1, marginLeft: 16 }}>
          <Text style={[type.h2, { color: colors.ink }]}>{sub.name}</Text>
          <Text style={[type.small, { color: colors.mute, marginTop: 4 }]}>{sub.vendor}</Text>
        </View>
      </View>

      <Card style={styles.priceCard}>
        <View style={styles.priceRow}>
          <View style={{ flex: 1 }}>
            <Text style={[type.smallBold, { color: colors.mute }]}>YOU PAY</Text>
            <Text style={[type.display, { color: colors.ink, marginTop: 4 }]}>
              {fmtUSD(monthly)}
            </Text>
            <Text style={[type.small, { color: colors.mute }]}>
              per month{sub.cycle === 'yearly' ? ` · ${fmtUSD(sub.amount)} billed yearly` : ''}
            </Text>
          </View>
          <Badge label={tier.toUpperCase()} tone={tier === 'zombie' ? 'zombie' : tier === 'review' ? 'review' : 'keep'} />
        </View>

        <View style={{ marginTop: 18 }}>
          <ZombieMeter score={breakdown.score} size="lg" />
        </View>
      </Card>

      <Section title="Why this score">
        <View style={styles.breakdownGroup}>
          <BreakdownRow
            label="Last opened"
            value={sub.lastUsedAt ? `${sinceLastUse}d ago` : 'Never'}
            weight="35%"
            score={breakdown.recencyOfLastUse}
          />
          <View style={styles.div} />
          <BreakdownRow
            label="Use vs price"
            value={`${sub.sessionsLast30d} sessions / 30d`}
            weight="25%"
            score={breakdown.usageVsPrice}
          />
          <View style={styles.div} />
          <BreakdownRow
            label="Overlap"
            value={sub.hasOverlapWith?.length ? `${sub.hasOverlapWith.length} similar subs` : 'None detected'}
            weight="20%"
            score={breakdown.overlap}
          />
          <View style={styles.div} />
          <BreakdownRow
            label="Your rating"
            value={sub.userRating ? `${sub.userRating}/5` : 'Not rated'}
            weight="15%"
            score={breakdown.userRating}
          />
          <View style={styles.div} />
          <BreakdownRow
            label="Vs market"
            value={
              sub.marketAverage > 0
                ? monthly > sub.marketAverage
                  ? `+${fmtUSD(monthly - sub.marketAverage)} above avg`
                  : 'At or below market'
                : '—'
            }
            weight="5%"
            score={breakdown.priceVsMarket}
          />
        </View>
      </Section>

      {sub.hasPriceHike && (
        <Section>
          <View style={styles.alertBox}>
            <Feather name="trending-up" size={20} color={colors.danger} />
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={[type.bodyBold, { color: colors.ink }]}>Price went up</Text>
              <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>
                {fmtUSD(sub.hasPriceHike.from)} → {fmtUSD(sub.hasPriceHike.to)} per month
              </Text>
            </View>
          </View>
        </Section>
      )}

      {sub.trialEndsAt && (
        <Section>
          <View style={[styles.alertBox, { backgroundColor: colors.warnSoft }]}>
            <Feather name="clock" size={20} color={colors.warn} />
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={[type.bodyBold, { color: colors.ink }]}>Trial ending soon</Text>
              <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>
                You'll be billed in {daysSince(new Date().toISOString()) - daysSince(sub.trialEndsAt) + 3} days unless you cancel.
              </Text>
            </View>
          </View>
        </Section>
      )}

      <Section title="The numbers">
        <View style={styles.stats}>
          <Stat label="Started" value={fmtRelDate(sub.startedAt)} />
          <Stat label="Yearly cost" value={fmtUSD(yearly)} highlight />
          <Stat label="Next bill" value={fmtRelDate(sub.nextBilling)} />
          {accruedSinceLastUse > 0 && sub.lastUsedAt && (
            <Stat label="Spent since last use" value={fmtUSD(accruedSinceLastUse)} highlight={breakdown.score >= 80} />
          )}
        </View>
      </Section>

      {sub.notes && (
        <Section>
          <View style={styles.notes}>
            <Ionicons name="information-circle-outline" size={18} color={colors.mute} />
            <Text style={[type.small, { color: colors.mute, flex: 1 }]}>{sub.notes}</Text>
          </View>
        </Section>
      )}

      <View style={{ height: 24 }} />

      {!cancelled ? (
        <View style={{ gap: 12 }}>
          <Button
            label={`Cancel — save ${fmtUSD(monthly)}/mo`}
            variant="danger"
            onPress={confirmCancel}
            icon={<Feather name="x-circle" size={18} color={colors.white} />}
          />
          <Button
            label="Try to negotiate first"
            variant="secondary"
            onPress={() => router.push(`/negotiate/${sub.id}`)}
            icon={<Feather name="message-circle" size={18} color={colors.ink} />}
          />
          <Button
            label="Generate dispute letter"
            variant="ghost"
            onPress={() => router.push(`/dispute/${sub.id}`)}
            icon={<Feather name="mail" size={18} color={colors.ink} />}
          />
        </View>
      ) : (
        <View style={{ gap: 12 }}>
          <View style={styles.cancelledBanner}>
            <Feather name="check-circle" size={20} color={colors.success} />
            <View style={{ flex: 1 }}>
              <Text style={[type.bodyBold, { color: colors.ink }]}>Cancelled this session</Text>
              <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>
                We'll log you out at the vendor on your behalf shortly.
              </Text>
            </View>
          </View>
          <Button label="Undo cancel" variant="secondary" onPress={() => reactivate(sub.id)} />
          <Button
            label="Generate dispute letter for past charges"
            variant="ghost"
            onPress={() => router.push(`/dispute/${sub.id}`)}
            icon={<Feather name="mail" size={18} color={colors.ink} />}
          />
        </View>
      )}

      <View style={{ height: 30 }} />
    </Screen>
  );
}

function BreakdownRow({ label, value, weight, score }: { label: string; value: string; weight: string; score: number }) {
  return (
    <View style={styles.brRow}>
      <View style={{ flex: 1 }}>
        <Text style={[type.bodyBold, { color: colors.ink }]}>{label}</Text>
        <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>
          {value} · weight {weight}
        </Text>
      </View>
      <View style={styles.brBar}>
        <ZombieMeter score={score} size="sm" />
      </View>
    </View>
  );
}

function Stat({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <View style={styles.stat}>
      <Text style={[type.smallBold, { color: colors.mute }]}>{label.toUpperCase()}</Text>
      <Text style={[type.h3, { color: highlight ? colors.danger : colors.ink, marginTop: 4 }]}>{value}</Text>
    </View>
  );
}

function fmtRelDate(iso: string): string {
  const d = new Date(iso);
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(d);
}

const styles = StyleSheet.create({
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  backBtn: {
    width: 40,
    height: 40,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroRow: { flexDirection: 'row', alignItems: 'center', marginTop: 24 },
  priceCard: { marginTop: 22 },
  priceRow: { flexDirection: 'row', alignItems: 'flex-start' },
  breakdownGroup: {
    backgroundColor: colors.white,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    overflow: 'hidden',
  },
  brRow: { flexDirection: 'row', alignItems: 'center', padding: 16, gap: 16 },
  brBar: { width: 100 },
  div: { height: 1, backgroundColor: colors.border },
  alertBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.dangerSoft,
    padding: 16,
    borderRadius: radius.md,
  },
  stats: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  stat: {
    width: '47.5%',
    backgroundColor: colors.surface,
    padding: 16,
    borderRadius: radius.md,
  },
  notes: {
    flexDirection: 'row',
    gap: 10,
    alignItems: 'flex-start',
    backgroundColor: colors.surface,
    padding: 14,
    borderRadius: radius.sm,
  },
  cancelledBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: colors.successSoft,
    padding: 16,
    borderRadius: radius.md,
  },
});
