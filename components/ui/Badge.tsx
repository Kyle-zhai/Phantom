import React from 'react';
import { StyleSheet, Text, View, ViewStyle } from 'react-native';
import { colors, radius, type } from '../../lib/theme';

type Tone = 'zombie' | 'review' | 'keep' | 'warn' | 'info' | 'neutral';

const tones: Record<Tone, { bg: string; fg: string }> = {
  zombie: { bg: colors.dangerSoft, fg: '#991B1B' },
  review: { bg: colors.warnSoft, fg: '#92400E' },
  keep: { bg: colors.successSoft, fg: '#065F46' },
  warn: { bg: colors.warnSoft, fg: '#92400E' },
  info: { bg: colors.infoSoft, fg: '#1E40AF' },
  neutral: { bg: colors.surface, fg: colors.ink },
};

type Props = { label: string; tone?: Tone; icon?: React.ReactNode; style?: ViewStyle };

export function Badge({ label, tone = 'neutral', icon, style }: Props) {
  const palette = tones[tone];
  return (
    <View style={[styles.badge, { backgroundColor: palette.bg }, style]}>
      {icon ? <View style={{ marginRight: 6 }}>{icon}</View> : null}
      <Text style={[type.micro, { color: palette.fg }]} numberOfLines={1}>
        {label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: radius.pill,
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
  },
});
