import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Avatar } from '../../components/ui/Avatar';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Screen } from '../../components/ui/Screen';
import type { PriceAlert } from '../../lib/data/types';
import { useStore } from '../../lib/store';
import { colors, radius, type } from '../../lib/theme';

const TONE: Record<PriceAlert['type'], { icon: keyof typeof Feather.glyphMap; bg: string; fg: string; chip: string }> = {
  hike: { icon: 'trending-up', bg: colors.dangerSoft, fg: '#991B1B', chip: 'Price hike' },
  'trial-ending': { icon: 'clock', bg: colors.warnSoft, fg: '#92400E', chip: 'Trial ending' },
  'new-charge': { icon: 'credit-card', bg: colors.infoSoft, fg: '#1E40AF', chip: 'New charge' },
  unused: { icon: 'moon', bg: colors.surface, fg: colors.ink, chip: 'Unused' },
};

export default function Alerts() {
  const alerts = useStore((s) => s.alerts);
  const subs = useStore((s) => s.subscriptions);
  const markRead = useStore((s) => s.markAlertRead);

  return (
    <Screen>
      <View style={styles.header}>
        <Text style={[type.smallBold, { color: colors.mute }]}>ALERTS</Text>
        <Text style={[type.h1, { color: colors.ink, marginTop: 2 }]}>
          {alerts.filter((a) => !a.read).length} need your attention
        </Text>
        <Text style={[type.small, { color: colors.mute, marginTop: 8 }]}>
          We monitor 2,000+ services and ping you 7 days before any price hike.
        </Text>
      </View>

      <View style={{ marginTop: 24, gap: 12 }}>
        {alerts.map((alert) => {
          const sub = subs.find((s) => s.id === alert.subscriptionId)!;
          const tone = TONE[alert.type];
          return (
            <Card
              key={alert.id}
              onPress={() => {
                markRead(alert.id);
                router.push(`/subscription/${sub.id}`);
              }}
              style={[styles.card, alert.read && { opacity: 0.7 }]}
            >
              <View style={styles.cardHead}>
                <View style={[styles.tag, { backgroundColor: tone.bg }]}>
                  <Feather name={tone.icon} size={12} color={tone.fg} />
                  <Text style={[type.micro, { color: tone.fg }]}>{tone.chip}</Text>
                </View>
                {!alert.read && <View style={styles.unread} />}
              </View>
              <View style={styles.cardBody}>
                <Avatar label={sub.name} bg={sub.brandColor} fg={colors.white} size={40} />
                <View style={{ flex: 1 }}>
                  <Text style={[type.bodyBold, { color: colors.ink }]}>{alert.title}</Text>
                  <Text style={[type.small, { color: colors.mute, marginTop: 4 }]}>
                    {alert.message}
                  </Text>
                </View>
              </View>
              <View style={styles.cardActions}>
                <Button
                  label={alert.type === 'unused' || alert.type === 'new-charge' ? 'Get refund' : 'Take action'}
                  size="sm"
                  fullWidth={false}
                  onPress={() => {
                    markRead(alert.id);
                    if (alert.type === 'unused' || alert.type === 'new-charge') {
                      router.push(`/dispute/${sub.id}`);
                    } else {
                      router.push(`/subscription/${sub.id}`);
                    }
                  }}
                />
                <Pressable onPress={() => markRead(alert.id)} style={styles.dismiss}>
                  <Text style={[type.smallBold, { color: colors.mute }]}>Dismiss</Text>
                </Pressable>
              </View>
            </Card>
          );
        })}
      </View>

      <View style={{ height: 32 }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: { marginTop: 4 },
  card: {},
  cardHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 },
  tag: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 10, paddingVertical: 5, borderRadius: radius.pill },
  unread: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.danger },
  cardBody: { flexDirection: 'row', gap: 12, alignItems: 'flex-start' },
  cardActions: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: 16, gap: 12 },
  dismiss: { paddingVertical: 8, paddingHorizontal: 12 },
});
