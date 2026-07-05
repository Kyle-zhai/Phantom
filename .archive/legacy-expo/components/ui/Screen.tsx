import { StatusBar } from 'expo-status-bar';
import React from 'react';
import { ScrollView, StyleSheet, View, ViewStyle } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors } from '../../lib/theme';

type Props = {
  children: React.ReactNode;
  scroll?: boolean;
  bg?: string;
  contentStyle?: ViewStyle;
  edges?: ('top' | 'bottom' | 'left' | 'right')[];
};

export function Screen({ children, scroll = true, bg = colors.white, contentStyle, edges }: Props) {
  const Wrapper = scroll ? ScrollView : View;
  return (
    <SafeAreaView edges={edges ?? ['top', 'left', 'right']} style={[styles.safe, { backgroundColor: bg }]}>
      <StatusBar style="dark" />
      <Wrapper
        style={{ flex: 1, backgroundColor: bg }}
        contentContainerStyle={scroll ? [styles.content, contentStyle] : undefined}
        showsVerticalScrollIndicator={false}
      >
        {scroll ? children : <View style={[styles.content, contentStyle]}>{children}</View>}
      </Wrapper>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1 },
  content: { paddingHorizontal: 20, paddingTop: 8, paddingBottom: 40 },
});
