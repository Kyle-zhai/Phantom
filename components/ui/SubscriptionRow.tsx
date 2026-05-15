import { Feather } from '@expo/vector-icons';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Subscription } from '../../lib/data/types';
import { monthlyAmount } from '../../lib/score';
import { colors, fmtUSD, radius, type } from '../../lib/theme';
import { Avatar } from './Avatar';
import { Badge } from './Badge';

type Props = {
  sub: Subscription & { score: number };
  onPress?: () => void;
  cancelled?: boolean;
  showScore?: boolean;
};

export function SubscriptionRow({ sub, onPress, cancelled, showScore = true }: Props) {
  const monthly = monthlyAmount(sub);
  const tone = sub.score >= 80 ? 'zombie' : sub.score >= 50 ? 'review' : 'keep';
  const label = sub.score >= 80 ? 'Zombie' : sub.score >= 50 ? 'Review' : 'Keep';

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.row,
        pressed && { opacity: 0.85 },
        cancelled && { opacity: 0.5 },
      ]}
    >
      <Avatar label={sub.name} bg={sub.brandColor} fg={colors.white} size={44} />
      <View style={{ flex: 1, marginLeft: 12 }}>
        <View style={styles.titleLine}>
          <Text style={[type.bodyBold, { color: colors.ink, flex: 1 }]} numberOfLines={1}>
            {sub.name}
          </Text>
          <Text style={[type.bodyBold, { color: colors.ink }]}>
            {fmtUSD(monthly)}
          </Text>
        </View>
        <View style={styles.metaLine}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, flex: 1 }}>
            {cancelled ? (
              <Badge label="Cancelled" tone="neutral" />
            ) : showScore ? (
              <Badge label={label} tone={tone} />
            ) : null}
            <Text style={[type.small, { color: colors.mute }]} numberOfLines={1}>
              {sub.cycle === 'yearly' ? `${fmtUSD(sub.amount)}/yr` : 'per month'}
            </Text>
          </View>
          <Feather name="chevron-right" size={18} color={colors.mute2} />
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 4,
  },
  titleLine: { flexDirection: 'row', alignItems: 'center' },
  metaLine: { flexDirection: 'row', alignItems: 'center', marginTop: 4 },
});
