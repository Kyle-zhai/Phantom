import { Feather } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { Avatar } from '../../components/ui/Avatar';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Screen } from '../../components/ui/Screen';
import { Section } from '../../components/ui/Section';
import { negotiationFor } from '../../lib/negotiate';
import { useStore } from '../../lib/store';
import { colors, fmtUSD, radius, type } from '../../lib/theme';

export default function NegotiateDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const sub = useStore((s) => s.subscriptions.find((x) => x.id === id));
  const [copied, setCopied] = useState(false);

  if (!sub) {
    return (
      <Screen>
        <Text style={[type.h2, { color: colors.ink }]}>Not found</Text>
      </Screen>
    );
  }

  const offer = negotiationFor(sub);

  const copy = async (text: string) => {
    if (Platform.OS !== 'web') Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
    await Clipboard.setStringAsync(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 1800);
  };

  if (!offer) {
    return (
      <Screen>
        <View style={styles.topBar}>
          <Pressable onPress={() => router.back()} style={styles.backBtn}>
            <Feather name="chevron-left" size={22} color={colors.ink} />
          </Pressable>
        </View>
        <View style={{ marginTop: 60, alignItems: 'center' }}>
          <Feather name="message-circle" size={48} color={colors.mute2} />
          <Text style={[type.h2, { color: colors.ink, marginTop: 16, textAlign: 'center' }]}>
            No retention script yet
          </Text>
          <Text style={[type.body, { color: colors.mute, marginTop: 8, textAlign: 'center', maxWidth: 320 }]}>
            We don't have a proven negotiation playbook for {sub.name} yet. Try the script below — it works for most subscriptions.
          </Text>
          <Card style={{ marginTop: 24, width: '100%' }}>
            <Text style={[type.body, { color: colors.ink, lineHeight: 24 }]}>
              "Hi — I'd like to cancel my subscription. Before I do, are there any loyalty discounts, retention offers, or downgrade options I should know about?"
            </Text>
          </Card>
        </View>
      </Screen>
    );
  }

  return (
    <Screen>
      <View style={styles.topBar}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <Feather name="chevron-left" size={22} color={colors.ink} />
        </Pressable>
        <Text style={[type.smallBold, { color: colors.mute }]}>NEGOTIATE</Text>
        <View style={{ width: 40 }} />
      </View>

      <View style={styles.hero}>
        <Avatar label={sub.name} bg={sub.brandColor} fg={colors.white} size={64} />
        <View style={{ flex: 1, marginLeft: 14 }}>
          <Text style={[type.h2, { color: colors.ink }]}>{sub.name}</Text>
          <Text style={[type.small, { color: colors.mute, marginTop: 4 }]}>
            Save {fmtUSD(offer.averageSaving)}/yr by asking the right way.
          </Text>
        </View>
      </View>

      <Card style={styles.statsCard}>
        <View style={styles.statsRow}>
          <View style={styles.stat}>
            <Text style={[type.smallBold, { color: colors.mute }]}>SUCCESS RATE</Text>
            <Text style={[type.display, { color: colors.success, marginTop: 4 }]}>{offer.successRate}%</Text>
          </View>
          <View style={styles.statDiv} />
          <View style={styles.stat}>
            <Text style={[type.smallBold, { color: colors.mute }]}>AVG SAVING</Text>
            <Text style={[type.h2, { color: colors.ink, marginTop: 4 }]}>{fmtUSD(offer.averageSaving)}</Text>
            <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>per year</Text>
          </View>
        </View>
      </Card>

      <Section title="How to reach them">
        <Card>
          <View style={styles.contactRow}>
            <View style={styles.contactIcon}>
              <Feather name={offer.channel === 'phone' ? 'phone' : 'message-square'} size={20} color={colors.ink} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={[type.smallBold, { color: colors.mute }]}>{offer.channel.toUpperCase()}</Text>
              <Text style={[type.bodyBold, { color: colors.ink, marginTop: 2 }]}>{offer.contact}</Text>
            </View>
            <Badge label={offer.expectedDiscount} tone="keep" />
          </View>
        </Card>
      </Section>

      <Section title="Your script" caption="Tap to copy. Read it almost verbatim.">
        <Pressable onPress={() => copy(offer.script)}>
          <Card style={styles.scriptCard}>
            <Text style={[type.body, { color: colors.ink, lineHeight: 24 }]}>
              "{offer.script}"
            </Text>
          </Card>
        </Pressable>
      </Section>

      <Section title="Tips for this call">
        <View style={styles.tips}>
          <Tip n="1" text="Be polite — agents have discretion. Hostility kills retention offers." />
          <Tip n="2" text="Mention a competitor by name. It triggers their retention script." />
          <Tip n="3" text="If the first offer is small, ask: 'Is that the best you can do?'" />
          <Tip n="4" text="Confirm the new rate in writing (email or chat transcript)." />
        </View>
      </Section>

      <View style={{ height: 24 }} />
      <Button
        label={copied ? 'Copied!' : 'Copy script'}
        onPress={() => copy(offer.script)}
        icon={<Feather name={copied ? 'check' : 'copy'} size={18} color={colors.white} />}
      />
      <View style={{ height: 12 }} />
      <Button
        label="It didn't work — cancel instead"
        variant="ghost"
        onPress={() => router.replace(`/subscription/${sub.id}`)}
      />

      <View style={{ height: 30 }} />
    </Screen>
  );
}

function Tip({ n, text }: { n: string; text: string }) {
  return (
    <View style={styles.tipRow}>
      <View style={styles.tipDot}>
        <Text style={[type.smallBold, { color: colors.white }]}>{n}</Text>
      </View>
      <Text style={[type.body, { color: colors.ink, flex: 1 }]}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  backBtn: {
    width: 40,
    height: 40,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hero: { flexDirection: 'row', alignItems: 'center', marginTop: 22 },
  statsCard: { marginTop: 20 },
  statsRow: { flexDirection: 'row', alignItems: 'center' },
  stat: { flex: 1 },
  statDiv: { width: 1, height: 60, backgroundColor: colors.border, marginHorizontal: 16 },
  contactRow: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  contactIcon: {
    width: 44,
    height: 44,
    borderRadius: radius.sm,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  scriptCard: { backgroundColor: colors.surface, borderColor: colors.surface },
  tips: { gap: 14 },
  tipRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 12 },
  tipDot: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: colors.ink,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 2,
  },
});
