import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';
import { Button } from '../../components/ui/Button';
import { Screen } from '../../components/ui/Screen';
import { colors, radius, type } from '../../lib/theme';

const items = [
  {
    icon: 'radio' as const,
    title: 'Subscription Radar',
    body: 'We scan every recurring charge — Netflix, Hulu, that gym you forgot about.',
  },
  {
    icon: 'activity' as const,
    title: 'Zombie Score',
    body: '0–100 score per subscription. You see exactly which ones are bleeding you dry.',
  },
  {
    icon: 'mail' as const,
    title: 'Dispute Letters',
    body: 'One tap = an EFTA-compliant letter to claim back wrongful charges.',
  },
  {
    icon: 'bell' as const,
    title: 'Price-Hike Alerts',
    body: '7 days before any price increase. No more surprise charges.',
  },
];

export default function OnboardingValue() {
  return (
    <Screen scroll>
      <View style={styles.topBar}>
        <Text style={[type.smallBold, { color: colors.mute }]}>2 / 3</Text>
      </View>

      <Text style={[type.h1, { color: colors.ink, marginTop: 8 }]}>
        Here's what you{'\n'}get.
      </Text>

      <View style={{ marginTop: 28, gap: 18 }}>
        {items.map((item) => (
          <View key={item.title} style={styles.row}>
            <View style={styles.iconBox}>
              <Feather name={item.icon} size={20} color={colors.ink} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={[type.bodyBold, { color: colors.ink }]}>{item.title}</Text>
              <Text style={[type.small, { color: colors.mute, marginTop: 3 }]}>{item.body}</Text>
            </View>
          </View>
        ))}
      </View>

      <View style={{ height: 32 }} />
      <Button label="Continue" onPress={() => router.push('/onboarding/connect')} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  topBar: { paddingTop: 12 },
  row: { flexDirection: 'row', gap: 16, alignItems: 'flex-start' },
  iconBox: {
    width: 44,
    height: 44,
    borderRadius: radius.sm,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
