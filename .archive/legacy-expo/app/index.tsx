import { Redirect } from 'expo-router';
import { useStore } from '../lib/store';

export default function Index() {
  const isOnboarded = useStore((s) => s.isOnboarded);
  return <Redirect href={isOnboarded ? '/(tabs)' : '/onboarding'} />;
}
