import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Avatar } from '../../components/ui/Avatar';
import { Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Screen } from '../../components/ui/Screen';
import { useMemo } from 'react';
import { allKnownNegotiations } from '../../lib/negotiate';
import { useStore } from '../../lib/store';
import { colors, fmtUSD, radius, type } from '../../lib/theme';

export default function NegotiateTab() {
  const subscriptions = useStore((s) => s.subscriptions);
  const cancelledIds = useStore((s) => s.cancelledIds);
  const { subs, offers, totalPotential } = useMemo(() => {
    const activeSubs = subscriptions.filter((s) => !cancelledIds.includes(s.id));
    const list = allKnownNegotiations(activeSubs);
    return {
      subs: activeSubs,
      offers: list,
      totalPotential: list.reduce((sum, o) => sum + o.averageSaving, 0),
    };
  }, [subscriptions, cancelledIds]);

  return (
    <Screen>
      <View style={styles.header}>
        <Text style={[type.smallBold, { color: colors.mute }]}>NEGOTIATE</Text>
        <Text style={[type.h1, { color: colors.ink, marginTop: 2 }]}>
          Save without cancelling.
        </Text>
        <Text style={[type.body, { color: colors.mute, marginTop: 10 }]}>
          Some services hand out retention discounts when asked the right way. We give you the script.
        </Text>
      </View>

      <Card style={styles.totalCard}>
        <Text style={[type.smallBold, { color: '#9CA3AF' }]}>POTENTIAL ANNUAL SAVINGS</Text>
        <Text style={[type.display, { color: colors.white, marginTop: 6 }]}>{fmtUSD(totalPotential)}</Text>
        <Text style={[type.small, { color: '#9CA3AF', marginTop: 8 }]}>
          Across {offers.length} services in your library.
        </Text>
      </Card>

      <View style={{ marginTop: 24, gap: 12 }}>
        {offers.map((offer) => {
          const sub = subs.find((s) => s.name === offer.vendor)!;
          return (
            <Pressable
              key={offer.vendor}
              onPress={() => router.push(`/negotiate/${sub.id}`)}
              style={({ pressed }) => [styles.row, pressed && { opacity: 0.85 }]}
            >
              <Avatar label={offer.vendor} bg={sub.brandColor} fg={colors.white} />
              <View style={{ flex: 1, marginLeft: 12 }}>
                <View style={styles.rowTitle}>
                  <Text style={[type.bodyBold, { color: colors.ink, flex: 1 }]}>{offer.vendor}</Text>
                  <Text style={[type.bodyBold, { color: colors.success }]}>
                    save {fmtUSD(offer.averageSaving)}/yr
                  </Text>
                </View>
                <View style={styles.rowMeta}>
                  <Badge label={`${offer.successRate}% success`} tone={offer.successRate >= 60 ? 'keep' : 'review'} />
                  <Text style={[type.small, { color: colors.mute, marginLeft: 8, flex: 1 }]} numberOfLines={1}>
                    {offer.expectedDiscount}
                  </Text>
                  <Feather name="chevron-right" size={18} color={colors.mute2} />
                </View>
              </View>
            </Pressable>
          );
        })}
      </View>

      <View style={{ height: 32 }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: { marginTop: 4 },
  totalCard: {
    marginTop: 20,
    backgroundColor: colors.black,
    borderColor: colors.black,
  },
  row: {
    backgroundColor: colors.white,
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
  },
  rowTitle: { flexDirection: 'row', alignItems: 'center' },
  rowMeta: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
});
