import React from 'react';
import { StyleSheet, Text, View, ViewStyle } from 'react-native';
import { colors, type } from '../../lib/theme';

type Props = {
  title?: string;
  caption?: string;
  right?: React.ReactNode;
  children?: React.ReactNode;
  style?: ViewStyle;
};

export function Section({ title, caption, right, children, style }: Props) {
  return (
    <View style={[styles.wrap, style]}>
      {(title || right) && (
        <View style={styles.head}>
          <View style={{ flex: 1 }}>
            {title ? <Text style={[type.h3, { color: colors.ink }]}>{title}</Text> : null}
            {caption ? <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>{caption}</Text> : null}
          </View>
          {right}
        </View>
      )}
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { marginTop: 28 },
  head: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: 12, gap: 12 },
});
