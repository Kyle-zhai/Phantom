import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { colors, radius, type } from '../../lib/theme';

type Props = { score: number; size?: 'sm' | 'md' | 'lg' };

const colorFor = (score: number) => {
  if (score >= 80) return colors.danger;
  if (score >= 50) return colors.warn;
  return colors.success;
};

const labelFor = (score: number) => {
  if (score >= 80) return 'Zombie';
  if (score >= 50) return 'Review';
  return 'Keep';
};

export function ZombieMeter({ score, size = 'md' }: Props) {
  const fill = Math.max(0, Math.min(100, score));
  const c = colorFor(fill);
  const heights = { sm: 6, md: 8, lg: 10 };
  return (
    <View style={{ width: '100%' }}>
      <View style={[styles.track, { height: heights[size] }]}>
        <View style={[styles.fill, { width: `${fill}%`, backgroundColor: c }]} />
      </View>
      {size !== 'sm' && (
        <View style={styles.row}>
          <Text style={[type.smallBold, { color: c }]}>{labelFor(fill)}</Text>
          <Text style={[type.smallBold, { color: colors.mute }]}>{fill}/100</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  track: { width: '100%', backgroundColor: colors.surface, borderRadius: radius.pill, overflow: 'hidden' },
  fill: { height: '100%', borderRadius: radius.pill },
  row: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 6 },
});
