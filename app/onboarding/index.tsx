import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';
import { Button } from '../../components/ui/Button';
import { Screen } from '../../components/ui/Screen';
import { colors, type } from '../../lib/theme';

export default function OnboardingWelcome() {
  return (
    <Screen scroll={false} bg={colors.black}>
      <View style={styles.wrap}>
        <View style={styles.brandRow}>
          <View style={styles.logo}>
            <Feather name="radio" size={26} color={colors.black} />
          </View>
          <Text style={[type.h3, { color: colors.white }]}>SubSpy</Text>
        </View>

        <View style={styles.center}>
          <Text style={[type.display, { color: colors.white, textAlign: 'left' }]}>
            Find the{'\n'}money{'\n'}you're losing.
          </Text>
          <Text style={[type.body, { color: '#9CA3AF', marginTop: 20, maxWidth: 320 }]}>
            The average American pays for 4.5 subscriptions they never use. SubSpy finds them, scores them, and helps you cancel — in seconds.
          </Text>
        </View>

        <View style={styles.footer}>
          <Button label="Get started" variant="light" onPress={() => router.push('/onboarding/value')} />
          <Text style={[type.small, { color: colors.mute, marginTop: 14, textAlign: 'center' }]}>
            We don't sell your data. We don't push loans.
          </Text>
        </View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, paddingVertical: 24 },
  brandRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  logo: {
    width: 36,
    height: 36,
    borderRadius: 10,
    backgroundColor: colors.white,
    alignItems: 'center',
    justifyContent: 'center',
  },
  center: { flex: 1, justifyContent: 'center' },
  footer: { paddingBottom: 16 },
});
