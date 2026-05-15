import { Feather, Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Screen } from '../../components/ui/Screen';
import { Section } from '../../components/ui/Section';
import { useStore } from '../../lib/store';
import { colors, radius, type } from '../../lib/theme';

type RowProps = {
  icon: keyof typeof Feather.glyphMap;
  label: string;
  value?: string;
  toggle?: boolean;
  on?: boolean;
  onToggle?: (v: boolean) => void;
  onPress?: () => void;
  destructive?: boolean;
};

function Row({ icon, label, value, toggle, on, onToggle, onPress, destructive }: RowProps) {
  return (
    <Pressable
      onPress={onPress}
      disabled={!onPress}
      style={({ pressed }) => [styles.row, pressed && onPress ? { opacity: 0.8 } : null]}
    >
      <View style={[styles.rowIcon, destructive && { backgroundColor: colors.dangerSoft }]}>
        <Feather name={icon} size={18} color={destructive ? colors.danger : colors.ink} />
      </View>
      <Text style={[type.body, { color: destructive ? colors.danger : colors.ink, flex: 1 }]}>{label}</Text>
      {toggle ? (
        <Switch
          value={on}
          onValueChange={onToggle}
          trackColor={{ true: colors.ink, false: colors.border }}
          thumbColor={colors.white}
          ios_backgroundColor={colors.border}
        />
      ) : value ? (
        <Text style={[type.small, { color: colors.mute, marginRight: 6 }]}>{value}</Text>
      ) : null}
      {!toggle && <Feather name="chevron-right" size={18} color={colors.mute2} />}
    </Pressable>
  );
}

export default function Settings() {
  const isPro = useStore((s) => s.isPro);
  const togglePro = useStore((s) => s.togglePro);
  const resetOnboarding = useStore((s) => s.resetOnboarding);
  const [hikeAlerts, setHikeAlerts] = React.useState(true);
  const [trialAlerts, setTrialAlerts] = React.useState(true);
  const [usageAnalysis, setUsageAnalysis] = React.useState(true);

  return (
    <Screen>
      <View style={styles.header}>
        <Text style={[type.smallBold, { color: colors.mute }]}>YOU</Text>
        <Text style={[type.h1, { color: colors.ink, marginTop: 2 }]}>Jordan Lee</Text>
        <Text style={[type.body, { color: colors.mute, marginTop: 6 }]}>jordan@phantom.com</Text>
      </View>

      {!isPro ? (
        <Card style={styles.proCard}>
          <View style={{ flex: 1 }}>
            <View style={styles.proTag}>
              <Ionicons name="sparkles" size={12} color={colors.white} />
              <Text style={[type.micro, { color: colors.white }]}>UNLOCK PRO</Text>
            </View>
            <Text style={[type.h2, { color: colors.white, marginTop: 12 }]}>
              Save $47/mo on average.
            </Text>
            <Text style={[type.small, { color: '#9CA3AF', marginTop: 8 }]}>
              Unlimited dispute letters, price-hike alerts, negotiation scripts.
            </Text>
            <View style={{ marginTop: 16 }}>
              <Button
                label="See plans"
                variant="secondary"
                fullWidth={false}
                onPress={() => router.push('/paywall')}
              />
            </View>
          </View>
        </Card>
      ) : (
        <Card style={styles.proActiveCard}>
          <View style={styles.proActiveRow}>
            <View style={styles.proCheckmark}>
              <Feather name="check" size={18} color={colors.white} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={[type.bodyBold, { color: colors.ink }]}>Phantom Pro is active</Text>
              <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>
                Annual · renews next year
              </Text>
            </View>
          </View>
        </Card>
      )}

      <Section title="Notifications">
        <View style={styles.group}>
          <Row icon="trending-up" label="Price-hike alerts" toggle on={hikeAlerts} onToggle={setHikeAlerts} />
          <View style={styles.div} />
          <Row icon="clock" label="Trial-ending alerts" toggle on={trialAlerts} onToggle={setTrialAlerts} />
          <View style={styles.div} />
          <Row icon="moon" label="Zombie-subscription analysis" toggle on={usageAnalysis} onToggle={setUsageAnalysis} />
        </View>
      </Section>

      <Section title="Connected accounts">
        <View style={styles.group}>
          <Row icon="link" label="Chase ····4218" value="Connected" />
          <View style={styles.div} />
          <Row icon="plus-circle" label="Add another bank" onPress={() => router.push('/onboarding/connect')} />
        </View>
      </Section>

      <Section title="Privacy" caption="The three things Phantom will never do.">
        <View style={styles.privacy}>
          <View style={styles.privacyRow}>
            <Ionicons name="shield-checkmark" size={20} color={colors.success} />
            <Text style={[type.small, { color: colors.ink, flex: 1 }]}>
              We <Text style={{ fontWeight: '700' }}>never sell</Text> your data to anyone.
            </Text>
          </View>
          <View style={styles.privacyRow}>
            <Ionicons name="shield-checkmark" size={20} color={colors.success} />
            <Text style={[type.small, { color: colors.ink, flex: 1 }]}>
              We <Text style={{ fontWeight: '700' }}>never push</Text> loans or credit cards.
            </Text>
          </View>
          <View style={styles.privacyRow}>
            <Ionicons name="shield-checkmark" size={20} color={colors.success} />
            <Text style={[type.small, { color: colors.ink, flex: 1 }]}>
              We <Text style={{ fontWeight: '700' }}>never store</Text> your card number — read-only via Plaid.
            </Text>
          </View>
        </View>
      </Section>

      <Section title="Support">
        <View style={styles.group}>
          <Row icon="help-circle" label="Help center" />
          <View style={styles.div} />
          <Row icon="message-square" label="Contact us" />
          <View style={styles.div} />
          <Row icon="file-text" label="Terms & Privacy" />
        </View>
      </Section>

      <Section title="Debug">
        <View style={styles.group}>
          <Row
            icon="award"
            label={isPro ? 'Disable Pro (debug)' : 'Enable Pro (debug)'}
            onPress={togglePro}
          />
          <View style={styles.div} />
          <Row
            icon="refresh-cw"
            label="Restart onboarding"
            onPress={() => {
              resetOnboarding();
              router.replace('/');
            }}
          />
          <View style={styles.div} />
          <Row icon="log-out" label="Sign out" destructive />
        </View>
      </Section>

      <Text style={[type.small, { color: colors.mute2, textAlign: 'center', marginTop: 24 }]}>
        Phantom · v1.0 · Made for people who hate losing money.
      </Text>

      <View style={{ height: 24 }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: { marginTop: 4 },
  proCard: {
    backgroundColor: colors.black,
    borderColor: colors.black,
    marginTop: 20,
    padding: 24,
  },
  proTag: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: radius.pill,
    backgroundColor: 'rgba(255,255,255,0.12)',
  },
  proActiveCard: { marginTop: 20 },
  proActiveRow: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  proCheckmark: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.success,
    alignItems: 'center',
    justifyContent: 'center',
  },
  group: {
    backgroundColor: colors.white,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 14,
  },
  rowIcon: {
    width: 36,
    height: 36,
    borderRadius: radius.sm,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  div: { height: 1, backgroundColor: colors.border, marginLeft: 66 },
  privacy: {
    backgroundColor: colors.successSoft,
    padding: 18,
    borderRadius: radius.md,
    gap: 12,
  },
  privacyRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
});
