import { Feather } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import * as Sharing from 'expo-sharing';
import { router, useLocalSearchParams } from 'expo-router';
import { useMemo, useState } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Avatar } from '../../components/ui/Avatar';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Screen } from '../../components/ui/Screen';
import { DISPUTE_REASONS, DisputeReason, generateDisputeLetter } from '../../lib/dispute';
import { useStore } from '../../lib/store';
import { colors, fmtUSD, radius, type } from '../../lib/theme';

export default function DisputeLetter() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const sub = useStore((s) => s.subscriptions.find((x) => x.id === id));

  const today = new Intl.DateTimeFormat('en-US', { year: 'numeric', month: 'short', day: 'numeric' }).format(
    new Date(Date.now() - 6 * 86_400_000),
  );

  const [fullName, setFullName] = useState('Jordan Lee');
  const [email, setEmail] = useState('jordan@phantom.com');
  const [chargeDate, setChargeDate] = useState(today);
  const [amount, setAmount] = useState(sub ? String(sub.amount) : '0');
  const [referenceNumber, setReferenceNumber] = useState('');
  const [reason, setReason] = useState<DisputeReason>('forgotten-trial');
  const [step, setStep] = useState<'form' | 'preview' | 'sent'>('form');
  const [copied, setCopied] = useState(false);

  const letter = useMemo(() => {
    if (!sub) return '';
    return generateDisputeLetter(sub, {
      fullName,
      email,
      chargeDate,
      amount: parseFloat(amount) || 0,
      reason,
      referenceNumber: referenceNumber || undefined,
    });
  }, [sub, fullName, email, chargeDate, amount, reason, referenceNumber]);

  if (!sub) {
    return (
      <Screen>
        <Text style={[type.h2, { color: colors.ink }]}>Not found</Text>
      </Screen>
    );
  }

  const handleCopy = async () => {
    if (Platform.OS !== 'web') Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
    await Clipboard.setStringAsync(letter);
    setCopied(true);
    setTimeout(() => setCopied(false), 1800);
  };

  const handleShare = async () => {
    if (Platform.OS === 'web') {
      await handleCopy();
      return;
    }
    const available = await Sharing.isAvailableAsync();
    if (available) {
      await Clipboard.setStringAsync(letter);
      setCopied(true);
    }
  };

  return (
    <Screen>
      <View style={styles.topBar}>
        <Pressable onPress={() => router.back()} style={styles.closeBtn}>
          <Feather name="x" size={22} color={colors.ink} />
        </Pressable>
        <Text style={[type.smallBold, { color: colors.mute }]}>DISPUTE LETTER</Text>
        <View style={{ width: 40 }} />
      </View>

      <View style={styles.hero}>
        <Avatar label={sub.name} bg={sub.brandColor} fg={colors.white} size={56} />
        <View style={{ flex: 1, marginLeft: 14 }}>
          <Text style={[type.h2, { color: colors.ink }]}>Refund from {sub.name}</Text>
          <Text style={[type.small, { color: colors.mute, marginTop: 4 }]}>
            We generate the letter — you send it. EFTA-compliant language.
          </Text>
        </View>
      </View>

      {step === 'form' && (
        <>
          <View style={styles.stepperHead}>
            <View style={styles.stepDot} />
            <View style={[styles.stepDot, styles.stepDotMute]} />
            <View style={[styles.stepDot, styles.stepDotMute]} />
            <Text style={[type.smallBold, { color: colors.mute, marginLeft: 8 }]}>Step 1 of 3</Text>
          </View>

          <Text style={[type.h3, { color: colors.ink, marginTop: 20 }]}>Why are you disputing?</Text>
          <View style={{ marginTop: 12, gap: 10 }}>
            {DISPUTE_REASONS.map((r) => {
              const active = reason === r.value;
              return (
                <Pressable
                  key={r.value}
                  onPress={() => setReason(r.value)}
                  style={[styles.reasonRow, active && styles.reasonRowActive]}
                >
                  <View style={[styles.radio, active && styles.radioActive]}>
                    {active && <View style={styles.radioInner} />}
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={[type.bodyBold, { color: colors.ink }]}>{r.label}</Text>
                    <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>{r.subtext}</Text>
                  </View>
                </Pressable>
              );
            })}
          </View>

          <Text style={[type.h3, { color: colors.ink, marginTop: 28 }]}>Charge details</Text>

          <Field label="Date of charge" value={chargeDate} onChangeText={setChargeDate} placeholder="e.g. May 8, 2026" />
          <Field
            label="Amount disputed"
            value={amount}
            onChangeText={setAmount}
            placeholder="0.00"
            keyboardType="decimal-pad"
            prefix="$"
          />
          <Field
            label="Reference / Transaction ID (optional)"
            value={referenceNumber}
            onChangeText={setReferenceNumber}
            placeholder="e.g. PMT-X92K-LL3"
          />

          <Text style={[type.h3, { color: colors.ink, marginTop: 28 }]}>Your contact info</Text>
          <Field label="Full name" value={fullName} onChangeText={setFullName} placeholder="As on your card" />
          <Field label="Email" value={email} onChangeText={setEmail} placeholder="you@example.com" keyboardType="email-address" />

          <View style={{ height: 24 }} />
          <Button
            label="Preview letter"
            onPress={() => setStep('preview')}
            trailingIcon={<Feather name="arrow-right" size={18} color={colors.white} />}
          />
        </>
      )}

      {step === 'preview' && (
        <>
          <View style={styles.stepperHead}>
            <View style={styles.stepDot} />
            <View style={styles.stepDot} />
            <View style={[styles.stepDot, styles.stepDotMute]} />
            <Text style={[type.smallBold, { color: colors.mute, marginLeft: 8 }]}>Step 2 of 3</Text>
          </View>

          <View style={styles.summary}>
            <Badge label={DISPUTE_REASONS.find((r) => r.value === reason)!.label} tone="info" />
            <Text style={[type.h2, { color: colors.ink, marginTop: 10 }]}>{fmtUSD(parseFloat(amount) || 0)}</Text>
            <Text style={[type.small, { color: colors.mute, marginTop: 2 }]}>
              Dated {chargeDate} · For {sub.name}
            </Text>
          </View>

          <Card style={styles.letterCard}>
            <ScrollView
              style={{ maxHeight: 360 }}
              showsVerticalScrollIndicator
              contentContainerStyle={{ padding: 18 }}
            >
              <Text style={[type.body, { color: colors.ink, fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace', fontSize: 13, lineHeight: 20 }]}>
                {letter}
              </Text>
            </ScrollView>
          </Card>

          <View style={{ marginTop: 16, gap: 10 }}>
            <Button
              label={copied ? 'Copied!' : 'Copy to clipboard'}
              onPress={handleCopy}
              icon={<Feather name={copied ? 'check' : 'copy'} size={18} color={colors.white} />}
            />
            <Button
              label="Share / Email"
              variant="secondary"
              onPress={handleShare}
              icon={<Feather name="share-2" size={18} color={colors.ink} />}
            />
            <Button label="Edit details" variant="ghost" onPress={() => setStep('form')} />
          </View>

          <View style={{ height: 16 }} />
          <Pressable onPress={() => setStep('sent')} style={styles.sentLink}>
            <Feather name="check-circle" size={18} color={colors.success} />
            <Text style={[type.bodyBold, { color: colors.ink }]}>I've sent it</Text>
          </Pressable>
        </>
      )}

      {step === 'sent' && (
        <View style={styles.sentWrap}>
          <View style={styles.sentCheck}>
            <Feather name="check" size={42} color={colors.white} />
          </View>
          <Text style={[type.h1, { color: colors.ink, marginTop: 24, textAlign: 'center' }]}>
            Letter sent.
          </Text>
          <Text style={[type.body, { color: colors.mute, marginTop: 8, textAlign: 'center', maxWidth: 320 }]}>
            Most companies respond within 10 business days. We'll remind you in 7 days if you haven't heard back.
          </Text>

          <Card style={{ marginTop: 28, width: '100%' }}>
            <Text style={[type.smallBold, { color: colors.mute }]}>SUCCESS RATE FOR THIS REASON</Text>
            <Text style={[type.display, { color: colors.success, marginTop: 6 }]}>
              {successRateFor(reason)}%
            </Text>
            <Text style={[type.small, { color: colors.mute, marginTop: 4 }]}>
              Based on 12,400+ Phantom disputes filed in 2025–2026.
            </Text>
          </Card>

          <View style={{ height: 24 }} />
          <Button label="Done" onPress={() => router.back()} />
          <View style={{ height: 12 }} />
          <Button label="Track this dispute" variant="secondary" onPress={() => router.back()} />
        </View>
      )}

      <View style={{ height: 30 }} />
    </Screen>
  );
}

function successRateFor(reason: DisputeReason): number {
  return {
    'forgotten-trial': 73,
    'auto-renewal-no-notice': 64,
    'cancelled-still-charged': 86,
    'unauthorized-charge': 91,
    'price-hike-no-notice': 52,
  }[reason];
}

function Field({
  label,
  value,
  onChangeText,
  placeholder,
  keyboardType,
  prefix,
}: {
  label: string;
  value: string;
  onChangeText: (s: string) => void;
  placeholder?: string;
  keyboardType?: 'default' | 'email-address' | 'decimal-pad';
  prefix?: string;
}) {
  return (
    <View style={{ marginTop: 14 }}>
      <Text style={[type.smallBold, { color: colors.mute, marginBottom: 6 }]}>{label}</Text>
      <View style={fieldStyles.box}>
        {prefix && <Text style={[type.body, { color: colors.mute, marginRight: 6 }]}>{prefix}</Text>}
        <TextInput
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={colors.mute2}
          keyboardType={keyboardType}
          style={[type.body, { color: colors.ink, flex: 1, paddingVertical: Platform.OS === 'ios' ? 10 : 6, outlineStyle: 'none' as any }]}
        />
      </View>
    </View>
  );
}

const fieldStyles = StyleSheet.create({
  box: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.white,
    borderRadius: radius.sm,
    paddingHorizontal: 14,
  },
});

const styles = StyleSheet.create({
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  closeBtn: {
    width: 40,
    height: 40,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hero: { flexDirection: 'row', alignItems: 'center', marginTop: 20 },
  stepperHead: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 22 },
  stepDot: { width: 24, height: 4, borderRadius: 2, backgroundColor: colors.ink },
  stepDotMute: { backgroundColor: colors.border },
  reasonRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    padding: 16,
    gap: 14,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.sm,
    backgroundColor: colors.white,
  },
  reasonRowActive: {
    borderColor: colors.ink,
    borderWidth: 2,
    backgroundColor: colors.white,
  },
  radio: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    borderColor: colors.mute2,
    marginTop: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioActive: { borderColor: colors.ink },
  radioInner: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.ink },
  summary: {
    marginTop: 20,
    padding: 18,
    backgroundColor: colors.surface,
    borderRadius: radius.md,
  },
  letterCard: {
    marginTop: 14,
    padding: 0,
    overflow: 'hidden',
  },
  sentLink: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    alignSelf: 'center',
    paddingVertical: 12,
  },
  sentWrap: { alignItems: 'center', marginTop: 32 },
  sentCheck: {
    width: 92,
    height: 92,
    borderRadius: 46,
    backgroundColor: colors.success,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
