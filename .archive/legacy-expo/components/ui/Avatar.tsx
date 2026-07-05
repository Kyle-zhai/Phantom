import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { colors, radius } from '../../lib/theme';

type Props = { label: string; bg?: string; fg?: string; size?: number };

export function Avatar({ label, bg, fg, size = 44 }: Props) {
  const initial = (label?.[0] ?? '?').toUpperCase();
  return (
    <View
      style={[
        styles.avatar,
        {
          width: size,
          height: size,
          borderRadius: size <= 28 ? radius.sm : radius.md,
          backgroundColor: bg ?? colors.surface,
        },
      ]}
    >
      <Text
        style={{
          color: fg ?? colors.ink,
          fontWeight: '700',
          fontSize: size * 0.45,
        }}
      >
        {initial}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  avatar: { justifyContent: 'center', alignItems: 'center' },
});
