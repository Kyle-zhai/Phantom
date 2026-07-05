import React from 'react';
import { Pressable, StyleSheet, View, ViewStyle } from 'react-native';
import { colors, radius, shadow } from '../../lib/theme';

type Props = {
  children: React.ReactNode;
  style?: ViewStyle | ViewStyle[];
  onPress?: () => void;
  padded?: boolean;
  elevated?: boolean;
};

export function Card({ children, style, onPress, padded = true, elevated = true }: Props) {
  const base = [
    styles.card,
    padded && styles.padded,
    elevated && (shadow.card as ViewStyle),
    style as ViewStyle,
  ];
  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        style={({ pressed }) => [base, pressed && { transform: [{ scale: 0.99 }], opacity: 0.96 }]}
      >
        {children}
      </Pressable>
    );
  }
  return <View style={base}>{children}</View>;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.white,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
  },
  padded: { padding: 20 },
});
