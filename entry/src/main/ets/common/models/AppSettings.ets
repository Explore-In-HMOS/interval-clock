export interface AppSettings {
  schemaVersion: number;
  onboardingCompleted: boolean;
  defaultFastDurationSec: number;
  defaultSlowDurationSec: number;
  defaultWarmUpDurationSec: number;
  defaultCoolDownDurationSec: number;
  defaultRepetitions: number;
  hapticsEnabled: boolean;
  hapticIntensity: 'low' | 'medium' | 'high';
  showRoundLabels: boolean;
  keepScreenAwake: boolean;
  dailyReminderEnabled: boolean;
  dailyReminderHour: number;
  dailyReminderMinute: number;
}

export function createDefaultSettings(): AppSettings {
  return {
    schemaVersion: 1,
    onboardingCompleted: false,
    defaultFastDurationSec: 30,
    defaultSlowDurationSec: 90,
    defaultWarmUpDurationSec: 5,
    defaultCoolDownDurationSec: 5,
    defaultRepetitions: 6,
    hapticsEnabled: true,
    hapticIntensity: 'medium',
    showRoundLabels: true,
    keepScreenAwake: true,
    dailyReminderEnabled: false,
    dailyReminderHour: 19,
    dailyReminderMinute: 0
  };
}
