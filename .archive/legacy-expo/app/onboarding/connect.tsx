import { Feather, Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { router } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { Button } from '../../components/ui/Button';
import { Screen } from '../../components/ui/Screen';
import { useStore } from '../../lib/store';
import { colors, radius, type } from '../../lib/theme';

const BANKS = [
  { id: 'chase', name: 'Chase', color: '#117ACA' },
  { id: 'boa', name: 'Bank of America', color: '#012169' },
  { id: 'wells', name: 'Wells Fargo', color: '#D71E28' },
  { id: 'citi', name: 'Citibank', color: '#0066B3' },
  { id: 'amex', name: 'Amex', color: '#016FD0' },
  { id: 'capone', name: 'Capital One', color: '#004977' },
];

export default function OnboardingConnect() {
  const completeOnboarding = useStore((s) => s.completeOnboarding);
  const [connecting, setConnecting] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);

  const handleConnect = (bankId: string) => {
    if (Platform.OS !== 'web') Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
    setConnecting(bankId);
    setProgress(0);
    const steps = [
      'Authenticating with Plaid…',
      'Reading recent transactions…',
      'Detecting recurring charges…',
      'Scoring subscriptions…',
    ];
    let i = 0;
    const tick = setInterval(() => {
      i += 1;
      setProgress(i);
      if (i >= steps.length) {
        clearInterval(tick);
        setTimeout(() => {
          completeOnboarding();
          router.replace('/(tabs)');
        }, 400);
      }
    }, 650);
    (handleConnect as any).steps = steps;
  };

  const steps = [
    'Authenticating with Plaid…',
    'Reading recent transactions…',
    'Detecting recurring charges…',
    'Scoring subscriptions…',
  ];

  if (connecting) {
    const bank = BANKS.find((b) => b.id === connecting)!;
    return (
      <Screen scroll={false}>
        <View style={styles.connectWrap}>
          <View style={[styles.bankLogoLg, { backgroundColor: bank.color }]}>
            <Text style={[type.h2, { color: colors.white }]}>{bank.name[0]}</Text>
          </View>
          <Text style={[type.h2, { color: colors.ink, marginTop: 28 }]}>Connecting to {bank.name}</Text>
          <Text style={[type.small, { color: colors.mute, marginTop: 8, textAlign: 'center' }]}>
            Read-only access via Plaid. We never store your credentials.
          </Text>

          <View style={{ marginTop: 36, width: '100%' }}>
            {steps.map((s, idx) => {
              const done = idx < progress;
              const active = idx === progress;
              return (
                <View key={s} style={styles.stepRow}>
                  <View
                    style={[
                      styles.stepDot,
                      done && { backgroundColor: colors.success },
                      active && { backgroundColor: colors.ink },
                    ]}
                  >
                    {done ? (
                      <Feather name="check" size={14} color={colors.white} />
                    ) : active ? (
                      <ActivityIndicator size="small" color={colors.white} />
                    ) : null}
                  </View>
                  <Text
                    style={[
                      type.body,
                      { color: done ? colors.ink : active ? colors.ink : colors.mute2, fontWeight: active ? '700' : '400' },
                    ]}
                  >
                    {s}
                  </Text>
                </View>
              );
            })}
          </View>
        </View>
      </Screen>
    );
  }

  return (
    <Screen scroll>
      <Text style={[type.smallBold, { color: colors.mute, marginTop: 12 }]}>3 / 3</Text>
      <Text style={[type.h1, { color: colors.ink, marginTop: 8 }]}>
        Connect a bank{'\n'}to begin.
      </Text>
      <Text style={[type.body, { color: colors.mute, marginTop: 10 }]}>
        Read-only via Plaid (same provider used by Venmo and Coinbase). We see merchant + amount, never your card number.
      </Text>

      <View style={styles.privacyBox}>
        <View style={styles.privacyRow}>
          <Ionicons name="shield-checkmark" size={18} color={colors.success} />
          <Text style={[type.smallBold, { color: colors.ink }]}>Bank-level encryption</Text>
        </View>
        <View style={styles.privacyRow}>
          <Ionicons name="shield-checkmark" size={18} color={colors.success} />
          <Text style={[type.smallBold, { color: colors.ink }]}>Never sold to anyone</Text>
        </View>
        <View style={styles.privacyRow}>
          <Ionicons name="shield-checkmark" size={18} color={colors.success} />
          <Text style={[type.smallBold, { color: colors.ink }]}>Disconnect anytime</Text>
        </View>
      </View>

      <Text style={[type.h3, { color: colors.ink, marginTop: 32 }]}>Pick your bank</Text>
      <View style={styles.grid}>
        {BANKS.map((bank) => (
          <Pressable key={bank.id} onPress={() => handleConnect(bank.id)} style={styles.bankCard}>
            <View style={[styles.bankLogo, { backgroundColor: bank.color }]}>
              <Text style={[type.bodyBold, { color: colors.white }]}>{bank.name[0]}</Text>
            </View>
            <Text style={[type.smallBold, { color: colors.ink, textAlign: 'center' }]} numberOfLines={2}>
              {bank.name}
            </Text>
          </Pressable>
        ))}
      </View>

      <View style={{ height: 24 }} />
      <Button
        label="Skip — explore with demo data"
        variant="secondary"
        onPress={() => {
          useStore.getState().completeOnboarding();
          router.replace('/(tabs)');
        }}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  privacyBox: {
    marginTop: 22,
    padding: 16,
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    gap: 12,
  },
  privacyRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  grid: {
    marginTop: 14,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  bankCard: {
    width: '47.5%',
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    padding: 16,
    alignItems: 'center',
    gap: 12,
  },
  bankLogo: {
    width: 44,
    height: 44,
    borderRadius: radius.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bankLogoLg: {
    width: 84,
    height: 84,
    borderRadius: radius.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  connectWrap: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  stepRow: { flexDirection: 'row', gap: 14, alignItems: 'center', marginVertical: 8 },
  stepDot: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
