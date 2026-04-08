import { AppSettings, createDefaultSettings } from '../../common/models/AppSettings';

const SETTINGS_STORAGE_KEY: string = 'intervalClock.settings.v1';
const SETTINGS_SCHEMA_VERSION: number = 1;
const MIN_DURATION_SEC: number = 5;
const MIN_OPTIONAL_DURATION_SEC: number = 0;
const MIN_REPETITIONS: number = 1;

interface SettingsEnvelope {
  version: number;
  settings: AppSettings;
}

export class SettingsRepository {
  initialize(): void {
    if (AppStorage.get<string>(SETTINGS_STORAGE_KEY) === undefined) {
      PersistentStorage.persistProp(SETTINGS_STORAGE_KEY, '');
    }
    this.saveSettings(this.loadSettings());
  }

  loadSettings(): AppSettings {
    const raw = AppStorage.get<string>(SETTINGS_STORAGE_KEY) ?? '';
    const defaults = createDefaultSettings();
    if (!raw || raw.length === 0) {
      return defaults;
    }

    try {
      const parsed = JSON.parse(raw) as Object;
      if (parsed === null || typeof parsed !== 'object') {
        return defaults;
      }

      if (this.isEnvelope(parsed)) {
        const envelope = parsed as SettingsEnvelope;
        return this.normalize(envelope.settings as Object);
      }

      return this.normalize(parsed);
    } catch (_error) {
      return defaults;
    }
  }

  saveSettings(settings: AppSettings): void {
    const normalized = this.normalize(settings as Object);
    const envelope: SettingsEnvelope = {
      version: SETTINGS_SCHEMA_VERSION,
      settings: normalized
    };
    AppStorage.set<string>(SETTINGS_STORAGE_KEY, JSON.stringify(envelope));
  }

  setOnboardingCompleted(completed: boolean): void {
    const current = this.loadSettings();
    this.saveSettings({
      schemaVersion: current.schemaVersion,
      onboardingCompleted: completed,
      defaultFastDurationSec: current.defaultFastDurationSec,
      defaultSlowDurationSec: current.defaultSlowDurationSec,
      defaultWarmUpDurationSec: current.defaultWarmUpDurationSec,
      defaultCoolDownDurationSec: current.defaultCoolDownDurationSec,
      defaultRepetitions: current.defaultRepetitions,
      hapticsEnabled: current.hapticsEnabled,
      hapticIntensity: current.hapticIntensity,
      showRoundLabels: current.showRoundLabels,
      keepScreenAwake: current.keepScreenAwake,
      dailyReminderEnabled: current.dailyReminderEnabled,
      dailyReminderHour: current.dailyReminderHour,
      dailyReminderMinute: current.dailyReminderMinute
    });
  }

  updateSettings(settings: AppSettings): void {
    this.saveSettings(settings);
  }

  private normalize(settings: Object): AppSettings {
    const defaults = createDefaultSettings();
    const input = settings as AppSettings;

    const onboardingCompleted = typeof input.onboardingCompleted === 'boolean' ?
      input.onboardingCompleted : defaults.onboardingCompleted;
    const keepScreenAwake = typeof input.keepScreenAwake === 'boolean' ? input.keepScreenAwake : defaults.keepScreenAwake;
    const hapticsEnabled = typeof input.hapticsEnabled === 'boolean' ? input.hapticsEnabled : defaults.hapticsEnabled;
    const showRoundLabels = typeof input.showRoundLabels === 'boolean' ? input.showRoundLabels : defaults.showRoundLabels;
    const hapticIntensity = input.hapticIntensity === 'low' || input.hapticIntensity === 'high' ||
      input.hapticIntensity === 'medium' ? input.hapticIntensity : defaults.hapticIntensity;
    const dailyReminderEnabled = typeof input.dailyReminderEnabled === 'boolean' ?
      input.dailyReminderEnabled : defaults.dailyReminderEnabled;

    return {
      schemaVersion: SETTINGS_SCHEMA_VERSION,
      onboardingCompleted,
      defaultFastDurationSec: this.sanitizeWholeNumber(input.defaultFastDurationSec, defaults.defaultFastDurationSec,
        MIN_DURATION_SEC),
      defaultSlowDurationSec: this.sanitizeWholeNumber(input.defaultSlowDurationSec, defaults.defaultSlowDurationSec,
        MIN_DURATION_SEC),
      defaultWarmUpDurationSec: this.sanitizeWholeNumber(input.defaultWarmUpDurationSec, defaults.defaultWarmUpDurationSec,
        MIN_OPTIONAL_DURATION_SEC),
      defaultCoolDownDurationSec: this.sanitizeWholeNumber(input.defaultCoolDownDurationSec,
        defaults.defaultCoolDownDurationSec, MIN_OPTIONAL_DURATION_SEC),
      defaultRepetitions: this.sanitizeWholeNumber(input.defaultRepetitions, defaults.defaultRepetitions,
        MIN_REPETITIONS),
      hapticsEnabled,
      hapticIntensity,
      showRoundLabels,
      keepScreenAwake,
      dailyReminderEnabled,
      dailyReminderHour: this.sanitizeRangedWholeNumber(input.dailyReminderHour, defaults.dailyReminderHour, 0, 23),
      dailyReminderMinute: this.sanitizeRangedWholeNumber(input.dailyReminderMinute, defaults.dailyReminderMinute, 0, 59)
    };
  }

  private sanitizeRangedWholeNumber(value: Object, fallback: number, minimum: number, maximum: number): number {
    const normalized = this.sanitizeWholeNumber(value, fallback, minimum);
    if (normalized > maximum) {
      return maximum;
    }
    return normalized;
  }

  private sanitizeWholeNumber(value: Object, fallback: number, minimum: number): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      return fallback;
    }

    const normalized = Math.floor(value);
    if (normalized < minimum) {
      return minimum;
    }
    return normalized;
  }

  private isEnvelope(value: Object): boolean {
    return !!((value as SettingsEnvelope).settings);
  }
}

export const settingsRepository: SettingsRepository = new SettingsRepository();
