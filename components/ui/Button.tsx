import * as Haptics from 'expo-haptics';
import React from 'react';
import { ActivityIndicator, Platform, Pressable, StyleSheet, Text, View, ViewStyle } from 'react-native';
import { colors, radius, type } from '../../lib/theme';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'light';
type Size = 'lg' | 'md' | 'sm';

type Props = {
  label: string;
  onPress?: () => void;
  variant?: Variant;
  size?: Size;
  icon?: React.ReactNode;
  trailingIcon?: React.ReactNode;
  loading?: boolean;
  disabled?: boolean;
  fullWidth?: boolean;
  haptic?: boolean;
  style?: ViewStyle;
};

const heights: Record<Size, number> = { lg: 56, md: 48, sm: 38 };
const paddings: Record<Size, number> = { lg: 24, md: 18, sm: 14 };
const fontStyles: Record<Size, any> = { lg: type.bodyBold, md: type.bodyBold, sm: type.smallBold };

export function Button({
  label,
  onPress,
  variant = 'primary',
  size = 'lg',
  icon,
  trailingIcon,
  loading,
  disabled,
  fullWidth = true,
  haptic = true,
  style,
}: Props) {
  const handlePress = () => {
    if (loading || disabled) return;
    if (haptic && Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
    }
    onPress?.();
  };

  const palette = palettes[variant];

  return (
    <Pressable
      onPress={handlePress}
      disabled={loading || disabled}
      style={({ pressed }) => [
        styles.base,
        {
          height: heights[size],
          paddingHorizontal: paddings[size],
          backgroundColor: palette.bg,
          borderColor: palette.border,
          borderWidth: palette.border === 'transparent' ? 0 : 1,
          opacity: disabled ? 0.4 : pressed ? 0.85 : 1,
          alignSelf: fullWidth ? 'stretch' : 'flex-start',
        },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={palette.fg} />
      ) : (
        <View style={styles.inner}>
          {icon ? <View style={styles.iconL}>{icon}</View> : null}
          <Text style={[fontStyles[size], { color: palette.fg }]} numberOfLines={1}>
            {label}
          </Text>
          {trailingIcon ? <View style={styles.iconR}>{trailingIcon}</View> : null}
        </View>
      )}
    </Pressable>
  );
}

const palettes: Record<Variant, { bg: string; fg: string; border: string }> = {
  primary: { bg: colors.black, fg: colors.white, border: 'transparent' },
  secondary: { bg: colors.white, fg: colors.ink, border: colors.border },
  ghost: { bg: 'transparent', fg: colors.ink, border: 'transparent' },
  danger: { bg: colors.danger, fg: colors.white, border: 'transparent' },
  light: { bg: colors.white, fg: colors.ink, border: 'transparent' },
};

const styles = StyleSheet.create({
  base: {
    borderRadius: radius.xl,
    justifyContent: 'center',
    alignItems: 'center',
  },
  inner: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center' },
  iconL: { marginRight: 8 },
  iconR: { marginLeft: 8 },
});
