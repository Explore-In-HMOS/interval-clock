import { AppRoutes } from '../../common/routing/AppRoutes';
import { AppSettings, createDefaultSettings } from '../../common/models/AppSettings';
import { settingsRepository } from '../../data/repositories/SettingsRepository';
import { dailyReminderService, ReminderSyncResult } from '../../viewmodel/DailyReminderService';

@Builder
export function SettingsPageBuilder() {
  SettingsPage();
}

@Component
export struct SettingsPage {
  private static readonly MAX_DURATION_SEC: number = 600;
  private static readonly MAX_REPETITIONS: number = 60;

  private schemaVersion: number = 1;
  private onboardingCompleted: boolean = false;

  private getString(resource: Resource): string {
    try {
      return this.getUIContext().getHostContext()?.resourceManager?.getStringSync(resource.id) ?? '';
    } catch (_error) {
      return '';
    }
  }

  @State defaultFastDurationSec: number = createDefaultSettings().defaultFastDurationSec;
  @State defaultSlowDurationSec: number = createDefaultSettings().defaultSlowDurationSec;
  @State defaultWarmUpDurationSec: number = createDefaultSettings().defaultWarmUpDurationSec;
  @State defaultCoolDownDurationSec: number = createDefaultSettings().defaultCoolDownDurationSec;
  @State defaultRepetitions: number = createDefaultSettings().defaultRepetitions;
  @State hapticsEnabled: boolean = createDefaultSettings().hapticsEnabled;
  @State hapticIntensity: 'low' | 'medium' | 'high' = createDefaultSettings().hapticIntensity;
  @State showRoundLabels: boolean = createDefaultSettings().showRoundLabels;
  @State keepScreenAwake: boolean = createDefaultSettings().keepScreenAwake;
  @State dailyReminderEnabled: boolean = createDefaultSettings().dailyReminderEnabled;
  @State dailyReminderHour: number = createDefaultSettings().dailyReminderHour;
  @State dailyReminderMinute: number = createDefaultSettings().dailyReminderMinute;
  @State reminderSync: ReminderSyncResult = dailyReminderService.syncDailyReminder(createDefaultSettings());

  aboutToAppear(): void {
    settingsRepository.initialize();
    const loaded = settingsRepository.loadSettings();
    this.schemaVersion = loaded.schemaVersion;
    this.onboardingCompleted = loaded.onboardingCompleted;
    this.defaultFastDurationSec = loaded.defaultFastDurationSec;
    this.defaultSlowDurationSec = loaded.defaultSlowDurationSec;
    this.defaultWarmUpDurationSec = loaded.defaultWarmUpDurationSec;
    this.defaultCoolDownDurationSec = loaded.defaultCoolDownDurationSec;
    this.defaultRepetitions = loaded.defaultRepetitions;
    this.hapticsEnabled = loaded.hapticsEnabled;
    this.hapticIntensity = loaded.hapticIntensity;
    this.showRoundLabels = loaded.showRoundLabels;
    this.keepScreenAwake = loaded.keepScreenAwake;
    this.dailyReminderEnabled = loaded.dailyReminderEnabled;
    this.dailyReminderHour = loaded.dailyReminderHour;
    this.dailyReminderMinute = loaded.dailyReminderMinute;
    this.reminderSync = dailyReminderService.syncDailyReminder(this.currentSettingsSnapshot());
  }

  private adjustDuration(field: 'fast' | 'slow' | 'warm' | 'cool', delta: number): void {
    if (field === 'fast') {
      this.defaultFastDurationSec = this.clamp(this.defaultFastDurationSec + delta, 5, SettingsPage.MAX_DURATION_SEC);
    } else if (field === 'slow') {
      this.defaultSlowDurationSec = this.clamp(this.defaultSlowDurationSec + delta, 5, SettingsPage.MAX_DURATION_SEC);
    } else if (field === 'warm') {
      this.defaultWarmUpDurationSec = this.clamp(this.defaultWarmUpDurationSec + delta, 0, SettingsPage.MAX_DURATION_SEC);
    } else {
      this.defaultCoolDownDurationSec = this.clamp(this.defaultCoolDownDurationSec + delta, 0, SettingsPage.MAX_DURATION_SEC);
    }
    this.persistSettings(false);
  }

  private adjustRepetitions(delta: number): void {
    this.defaultRepetitions = this.clamp(this.defaultRepetitions + delta, 1, SettingsPage.MAX_REPETITIONS);
    this.persistSettings(false);
  }

  private setToggle(field: 'haptics' | 'keepAwake' | 'labels', value: boolean): void {
    if (field === 'haptics') {
      this.hapticsEnabled = value;
    } else if (field === 'keepAwake') {
      this.keepScreenAwake = value;
    } else {
      this.showRoundLabels = value;
    }
    this.persistSettings(false);
  }

  private setHapticIntensity(intensity: 'low' | 'medium' | 'high'): void {
    this.hapticIntensity = intensity;
    this.persistSettings(false);
  }

  private currentSettingsSnapshot(): AppSettings {
    return {
      schemaVersion: this.schemaVersion,
      onboardingCompleted: this.onboardingCompleted,
      defaultFastDurationSec: this.defaultFastDurationSec,
      defaultSlowDurationSec: this.defaultSlowDurationSec,
      defaultWarmUpDurationSec: this.defaultWarmUpDurationSec,
      defaultCoolDownDurationSec: this.defaultCoolDownDurationSec,
      defaultRepetitions: this.defaultRepetitions,
      hapticsEnabled: this.hapticsEnabled,
      hapticIntensity: this.hapticIntensity,
      showRoundLabels: this.showRoundLabels,
      keepScreenAwake: this.keepScreenAwake,
      dailyReminderEnabled: this.dailyReminderEnabled,
      dailyReminderHour: this.dailyReminderHour,
      dailyReminderMinute: this.dailyReminderMinute
    };
  }

  private persistSettings(syncReminder: boolean): void {
    const snapshot = this.currentSettingsSnapshot();
    settingsRepository.updateSettings(snapshot);
    if (syncReminder) {
      this.reminderSync = dailyReminderService.syncDailyReminder(snapshot);
    }
  }

  private setDailyReminderEnabled(enabled: boolean): void {
    this.dailyReminderEnabled = enabled;
    this.persistSettings(true);
  }

  private adjustReminderTime(field: 'hour' | 'minute', delta: number): void {
    if (field === 'hour') {
      this.dailyReminderHour = this.wrapHour(this.dailyReminderHour + delta);
    } else {
      this.dailyReminderMinute = this.wrapMinute(this.dailyReminderMinute + delta);
    }
    this.persistSettings(true);
  }

  private wrapHour(value: number): number {
    return ((value % 24) + 24) % 24;
  }

  private wrapMinute(value: number): number {
    return ((value % 60) + 60) % 60;
  }

  private formatTimePart(value: number): string {
    if (value < 10) {
      return `0${value}`;
    }
    return `${value}`;
  }

  private reminderStatusText(): string {
    if (this.reminderSync.state === 'off') {
      return this.getString($r('app.string.reminder_status_off'));
    }
    return `${this.getString($r('app.string.reminder_status_fallback'))} ${this.reminderSync.timeLabel}`;
  }

  private clamp(value: number, min: number, max: number): number {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  @Builder
  private ToggleRow(title: string, subtitle: string, value: boolean, onChange: (value: boolean) => void) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(13)
          .fontColor(Color.White)
        Text(subtitle)
          .fontSize(10)
          .fontColor('#AFAFAF')
      }
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((isOn: boolean) => onChange(isOn))
    }
    .width('100%')
    .padding({ top: 2, bottom: 2 })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 10 }) {
          Text($r('app.string.settings_title'))
            .fontColor(Color.White)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ left: 14, right: 14 })

          Column({ space: 8 }) {
            Text($r('app.string.settings_default_session'))
              .fontSize(13)
              .fontColor('#D8D8D8')

            Column({ space: 4 }) {
              Text(this.getString($r('app.string.settings_work_duration')))
                .fontSize(12)
                .fontColor('#D0D0D0')
              Row({ space: 6 }) {
                Button() {
                  SymbolGlyph($r('sys.symbol.minus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustDuration('fast', -5))
                Text(`${this.defaultFastDurationSec}s`)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .width(70)
                  .textAlign(TextAlign.Center)
                Button() {
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustDuration('fast', 5))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(14)
              .backgroundColor('transparent')
            }
            .width('100%')

            Column({ space: 4 }) {
              Text(this.getString($r('app.string.settings_rest_duration')))
                .fontSize(12)
                .fontColor('#D0D0D0')
              Row({ space: 6 }) {
                Button() {
                  SymbolGlyph($r('sys.symbol.minus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustDuration('slow', -5))
                Text(`${this.defaultSlowDurationSec}s`)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .width(70)
                  .textAlign(TextAlign.Center)
                Button() {
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustDuration('slow', 5))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(14)
              .backgroundColor('transparent')
            }
            .width('100%')

            Column({ space: 4 }) {
              Text(this.getString($r('app.string.settings_warm_up')))
                .fontSize(12)
                .fontColor('#D0D0D0')
              Row({ space: 6 }) {
                Button() {
                  SymbolGlyph($r('sys.symbol.minus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustDuration('warm', -5))
                Text(`${this.defaultWarmUpDurationSec}s`)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .width(70)
                  .textAlign(TextAlign.Center)
                Button() {
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustDuration('warm', 5))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(14)
              .backgroundColor('transparent')
            }
            .width('100%')

            Column({ space: 4 }) {
              Text(this.getString($r('app.string.settings_cool_down')))
                .fontSize(12)
                .fontColor('#D0D0D0')
              Row({ space: 6 }) {
                Button() {
                  SymbolGlyph($r('sys.symbol.minus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustDuration('cool', -5))
                Text(`${this.defaultCoolDownDurationSec}s`)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .width(70)
                  .textAlign(TextAlign.Center)
                Button() {
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustDuration('cool', 5))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(14)
              .backgroundColor('transparent')
            }
            .width('100%')

            Column({ space: 4 }) {
              Text(this.getString($r('app.string.settings_repetitions')))
                .fontSize(12)
                .fontColor('#D0D0D0')
              Row({ space: 6 }) {
                Button() {
                  SymbolGlyph($r('sys.symbol.minus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustRepetitions(-1))
                Text(`${this.defaultRepetitions}x`)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .width(70)
                  .textAlign(TextAlign.Center)
                Button() {
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
                  .width(30)
                  .height(28)
                  .backgroundColor('#2A2A2A')
                  .borderRadius(14)
                  .onClick(() => this.adjustRepetitions(1))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(14)
              .backgroundColor('transparent')
            }
            .width('100%')
          }
          .width('100%')
          .padding(10)
          .borderRadius(14)
          .backgroundColor('#171717')

          Column({ space: 8 }) {
            Text($r('app.string.settings_coaching_cues'))
              .fontSize(13)
              .fontColor('#D8D8D8')

            this.ToggleRow(this.getString($r('app.string.settings_haptic_cues')),
              this.getString($r('app.string.settings_haptic_subtitle')), this.hapticsEnabled,
              (isOn: boolean) => this.setToggle('haptics', isOn))

            if (this.hapticsEnabled) {
              Row({ space: 6 }) {
                Button($r('app.string.settings_haptic_low'))
                  .layoutWeight(1)
                  .height(30)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .backgroundColor(this.hapticIntensity === 'low' ? '#2C4A86' : '#2D2D2D')
                  .borderRadius(15)
                  .onClick(() => this.setHapticIntensity('low'))
                Button($r('app.string.settings_haptic_medium'))
                  .layoutWeight(1)
                  .height(30)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .backgroundColor(this.hapticIntensity === 'medium' ? '#2C4A86' : '#2D2D2D')
                  .borderRadius(15)
                  .onClick(() => this.setHapticIntensity('medium'))
                Button($r('app.string.settings_haptic_high'))
                  .layoutWeight(1)
                  .height(30)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .backgroundColor(this.hapticIntensity === 'high' ? '#2C4A86' : '#2D2D2D')
                  .borderRadius(15)
                  .onClick(() => this.setHapticIntensity('high'))
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(10)
          .borderRadius(14)
          .backgroundColor('#171717')

          Column({ space: 8 }) {
            Text($r('app.string.settings_reminder_title'))
              .fontSize(13)
              .fontColor('#D8D8D8')

            this.ToggleRow(this.getString($r('app.string.settings_reminder_toggle')),
              this.getString($r('app.string.settings_reminder_subtitle')),
              this.dailyReminderEnabled,
              (isOn: boolean) => this.setDailyReminderEnabled(isOn))

            if (this.dailyReminderEnabled) {
              Column({ space: 4 }) {
                Text(this.getString($r('app.string.settings_reminder_hour')))
                  .fontSize(12)
                  .fontColor('#D0D0D0')
                Row({ space: 6 }) {
                  Button() {
                    SymbolGlyph($r('sys.symbol.minus'))
                      .fontSize(16)
                      .fontColor([Color.White])
                  }
                    .width(30)
                    .height(28)
                    .backgroundColor('#2A2A2A')
                    .borderRadius(14)
                    .onClick(() => this.adjustReminderTime('hour', -1))
                  Text(this.formatTimePart(this.dailyReminderHour))
                    .fontSize(13)
                    .fontColor(Color.White)
                    .width(70)
                    .textAlign(TextAlign.Center)
                  Button() {
                    SymbolGlyph($r('sys.symbol.plus'))
                      .fontSize(16)
                      .fontColor([Color.White])
                  }
                    .width(30)
                    .height(28)
                    .backgroundColor('#2A2A2A')
                    .borderRadius(14)
                    .onClick(() => this.adjustReminderTime('hour', 1))
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .borderRadius(14)
                .backgroundColor('transparent')
              }
              .width('100%')

              Column({ space: 4 }) {
                Text(this.getString($r('app.string.settings_reminder_minute')))
                  .fontSize(12)
                  .fontColor('#D0D0D0')
                Row({ space: 6 }) {
                  Button() {
                    SymbolGlyph($r('sys.symbol.minus'))
                      .fontSize(16)
                      .fontColor([Color.White])
                  }
                    .width(30)
                    .height(28)
                    .backgroundColor('#2A2A2A')
                    .borderRadius(14)
                    .onClick(() => this.adjustReminderTime('minute', -5))
                  Text(this.formatTimePart(this.dailyReminderMinute))
                    .fontSize(13)
                    .fontColor(Color.White)
                    .width(70)
                    .textAlign(TextAlign.Center)
                  Button() {
                    SymbolGlyph($r('sys.symbol.plus'))
                      .fontSize(16)
                      .fontColor([Color.White])
                  }
                    .width(30)
                    .height(28)
                    .backgroundColor('#2A2A2A')
                    .borderRadius(14)
                    .onClick(() => this.adjustReminderTime('minute', 5))
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .borderRadius(14)
                .backgroundColor('transparent')
              }
              .width('100%')
            }

            Text(this.reminderStatusText())
              .fontSize(10)
              .fontColor('#B2B2B2')
          }
          .width('100%')
          .padding(10)
          .borderRadius(14)
          .backgroundColor('#171717')

          Column({ space: 8 }) {
            Text($r('app.string.settings_display_behavior'))
              .fontSize(13)
              .fontColor('#D8D8D8')

            this.ToggleRow(this.getString($r('app.string.settings_keep_awake')),
              this.getString($r('app.string.settings_keep_awake_subtitle')), this.keepScreenAwake,
              (isOn: boolean) => this.setToggle('keepAwake', isOn))

            this.ToggleRow(this.getString($r('app.string.settings_show_round_labels')),
              this.getString($r('app.string.settings_show_round_labels_subtitle')), this.showRoundLabels,
              (isOn: boolean) => this.setToggle('labels', isOn))
          }
          .width('100%')
          .padding(10)
          .borderRadius(14)
          .backgroundColor('#171717')
        }
        .width('100%')
        .padding({ top: 12, bottom: 18, left: 12, right: 12 })
        .backgroundColor('#0A0A0A')
      }
      .height('100%')
    }
    .title(AppRoutes.SETTINGS)
    .hideTitleBar(true)
  }
}
