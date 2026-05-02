import { createSessionPlan } from '../common/models/IntervalSessionModels';
import { IntervalPreset } from '../common/models/IntervalPreset';
import { AppRoutes, createTimerRouteParam } from '../common/routing/AppRoutes';
import { presetRepository } from '../data/repositories/PresetRepository';
import { settingsRepository } from '../data/repositories/SettingsRepository';
import { HistoryPageBuilder } from './History/History';
import { InsightsPageBuilder } from './Insights/Insights';
import { PresetsPageBuilder } from './Presets/Presets';
import { SettingsPageBuilder } from './Settings/Settings';
import { SessionSummaryPageBuilder } from './SessionSummary/SessionSummary';
import { TimerPageBuilder } from './Timer/Timer';

@Entry
@Component
struct Index {
  @Provide('NavPathStack') pageStack: NavPathStack = new NavPathStack()
  @State showOnboarding: boolean = false;
  @State fastDuration: number = 30;
  @State slowDuration: number = 90;
  @State warmUpDuration: number = 5;
  @State coolDownDuration: number = 5;
  @State repetitions: number = 6;
  @State favoritePresets: IntervalPreset[] = [];
  @State recentPresets: IntervalPreset[] = [];
  @State latestQuickStartPreset: IntervalPreset | undefined = undefined;

  aboutToAppear(): void {
    settingsRepository.initialize();
    presetRepository.initialize();

    const settings = settingsRepository.loadSettings();
    this.showOnboarding = !settings.onboardingCompleted;
    this.fastDuration = settings.defaultFastDurationSec;
    this.slowDuration = settings.defaultSlowDurationSec;
    this.warmUpDuration = settings.defaultWarmUpDurationSec;
    this.coolDownDuration = settings.defaultCoolDownDurationSec;
    this.repetitions = settings.defaultRepetitions;
    this.refreshPresetSections();
  }

  private refreshPresetSections(): void {
    this.favoritePresets = presetRepository.getFavoritePresets(3);
    this.recentPresets = presetRepository.getRecentPresets(3);
    this.latestQuickStartPreset = this.recentPresets.length > 0 ? this.recentPresets[0] :
      (this.favoritePresets.length > 0 ? this.favoritePresets[0] : undefined);
  }

  private buildPresetSummary(preset: IntervalPreset): string {
    return `${preset.fastDurationSec}/${preset.slowDurationSec}s · ${preset.repetitions}x`;
  }

  private buildQuickStartLabel(name: string): string {
    return `Start ${name}`;
  }

  private buildPresetLaunchLabel(name: string): string {
    return `• ${name}`;
  }

  private launchCustomSession(): void {
    this.pageStack.pushPathByName(
      AppRoutes.TIMER,
      createTimerRouteParam(createSessionPlan(this.fastDuration, this.slowDuration, this.repetitions, 'manual', undefined,
        'Custom', this.warmUpDuration, this.coolDownDuration))
    );
  }

  private launchPresetSession(preset: IntervalPreset): void {
    const selected = presetRepository.markPresetUsed(preset.id);
    const finalPreset = selected ?? preset;
    this.refreshPresetSections();
    this.pageStack.pushPathByName(
      AppRoutes.TIMER,
      createTimerRouteParam(createSessionPlan(finalPreset.fastDurationSec, finalPreset.slowDurationSec,
        finalPreset.repetitions, 'preset', finalPreset.id, finalPreset.name,
        finalPreset.warmUpDurationSec, finalPreset.coolDownDurationSec))
    );
  }

  private completeOnboarding(): void {
    settingsRepository.setOnboardingCompleted(true);
    this.showOnboarding = false;
  }

  @Builder
  PagesMap(name: string) {
    if (name === AppRoutes.TIMER) {
      TimerPageBuilder();
    } else if (name === AppRoutes.PRESETS) {
      PresetsPageBuilder();
    } else if (name === AppRoutes.HISTORY) {
      HistoryPageBuilder();
    } else if (name === AppRoutes.INSIGHTS) {
      InsightsPageBuilder();
    } else if (name === AppRoutes.SETTINGS) {
      SettingsPageBuilder();
    } else if (name === AppRoutes.SESSION_SUMMARY) {
      SessionSummaryPageBuilder();
    }
  }

  build() {
    Navigation(this.pageStack) {
      if (this.showOnboarding) {
        Scroll() {
          Column({ space: 10 }) {
            Text($r('app.string.onboarding_welcome_title'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width('100%')

            Text($r('app.string.onboarding_welcome_subtitle'))
              .fontSize(12)
              .fontColor('#D1D1D1')
              .textAlign(TextAlign.Center)
              .padding({ left: 6, right: 6 })

            Column({ space: 6 }) {
              Text($r('app.string.onboarding_how_it_works_title'))
                .fontSize(14)
                .fontColor(Color.White)

              Text($r('app.string.onboarding_how_it_works_item_1'))
                .fontSize(11)
                .fontColor('#D5D5D5')

              Text($r('app.string.onboarding_how_it_works_item_2'))
                .fontSize(11)
                .fontColor('#D5D5D5')

              Text($r('app.string.onboarding_how_it_works_item_3'))
                .fontSize(11)
                .fontColor('#D5D5D5')
            }
            .width('100%')
            .padding(10)
            .borderRadius(12)
            .backgroundColor('#171717')

            Column({ space: 6 }) {
              Text($r('app.string.onboarding_routine_types_title'))
                .fontSize(14)
                .fontColor(Color.White)

              Text($r('app.string.onboarding_routine_types_examples'))
                .fontSize(11)
                .fontColor('#C8C8C8')
            }
            .width('100%')
            .padding(10)
            .borderRadius(12)
            .backgroundColor('#171717')

            Button($r('app.string.onboarding_open_dashboard'))
              .width('100%')
              .height(36)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#2C4A86')
              .borderRadius(20)
              .onClick(() => this.completeOnboarding())
          }
          .width('100%')
          .padding({ top: 14, left: 12, right: 12, bottom: 20 })
          .backgroundColor(Color.Black)
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Center)
        }
        .height('100%')
      } else {
        Scroll() {
          Column({ space: 10 }) {
            Text('Interval')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ left: 8, right: 8, top: 2 })
              .margin({ bottom: 2 })

          Column({ space: 6 }) {
            Text($r('app.string.dashboard_quick_start_title'))
              .fontSize(14)
              .fontColor('#D9D9D9')

            if (this.latestQuickStartPreset !== undefined) {
               Button(this.buildQuickStartLabel(this.latestQuickStartPreset.name))
                .width('100%')
                .height(32)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor('#2C4A86')
                .borderRadius(17)
                .onClick(() => {
                  if (this.latestQuickStartPreset) {
                    this.launchPresetSession(this.latestQuickStartPreset);
                  }
                })

              Text(this.buildPresetSummary(this.latestQuickStartPreset))
                .fontSize(10)
                .fontColor('#B8B8B8')
            } else {
              Text($r('app.string.dashboard_quick_start_empty'))
                .fontColor('#999999')
                .fontSize(11)
            }
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .borderRadius(14)
          .backgroundColor('#171717')

          Column({ space: 8 }) {
            Text($r('app.string.dashboard_quick_start_section_title'))
              .fontSize(14)
              .fontColor('#D9D9D9')

            Row() {
              Text($r('app.string.dashboard_fast_label'))
                .fontSize(16)
                .fontColor(Color.White)
                .width('30%')
                .textAlign(TextAlign.Start)
                .padding({ left: '9vp' })

              Row() {
                Button('-')
                  .fontSize(16)
                  .fontColor(Color.White)
                  .backgroundColor('transparent')
                  .onClick(() => {
                    if (this.fastDuration > 5) {
                      this.fastDuration -= 5;
                    }
                  })

                Text(`${this.fastDuration}s`)
                  .fontSize(16)
                  .fontColor(Color.White)
                  .width(50)
                  .textAlign(TextAlign.Center)

                Button('+')
                  .fontSize(16)
                  .fontColor(Color.White)
                  .backgroundColor('transparent')
                  .onClick(() => {
                    this.fastDuration += 5;
                  })
              }
              .width('64%')
              .height(32)
              .borderRadius(20)
              .backgroundColor('#2A2A2A')
              .justifyContent(FlexAlign.SpaceEvenly)
            }
            .width('100%')
            .height(36)

            Row() {
              Text($r('app.string.dashboard_slow_label'))
                .fontSize(16)
                .fontColor(Color.White)
                .width('30%')
                .textAlign(TextAlign.Start)
                .padding({ left: '9vp' })

              Row() {
                Button('-')
                  .fontSize(16)
                  .fontColor(Color.White)
                  .backgroundColor('transparent')
                  .onClick(() => {
                    if (this.slowDuration > 5) {
                      this.slowDuration -= 5;
                    }
                  })

                Text(`${this.slowDuration}s`)
                  .fontSize(16)
                  .fontColor(Color.White)
                  .width(50)
                  .textAlign(TextAlign.Center)

                Button('+')
                  .fontSize(16)
                  .fontColor(Color.White)
                  .backgroundColor('transparent')
                  .onClick(() => {
                    this.slowDuration += 5;
                  })
              }
              .width('64%')
              .height(32)
              .borderRadius(20)
              .backgroundColor('#2A2A2A')
              .justifyContent(FlexAlign.SpaceEvenly)
            }
            .width('100%')
            .height(36)

            Row() {
              Text($r('app.string.dashboard_reps_label'))
                .fontSize(16)
                .fontColor(Color.White)
                .width('30%')
                .textAlign(TextAlign.Start)
                .padding({ left: '9vp' })

              Row() {
                Button('-')
                  .fontSize(16)
                  .fontColor(Color.White)
                  .backgroundColor('transparent')
                  .onClick(() => {
                    if (this.repetitions > 1) {
                      this.repetitions -= 1;
                    }
                  })

                Text(this.repetitions.toString())
                  .fontSize(16)
                  .fontColor(Color.White)
                  .width(50)
                  .textAlign(TextAlign.Center)

                Button('+')
                  .fontSize(16)
                  .fontColor(Color.White)
                  .backgroundColor('transparent')
                  .onClick(() => {
                    this.repetitions += 1;
                  })
              }
              .width('64%')
              .height(32)
              .borderRadius(20)
              .backgroundColor('#2A2A2A')
              .justifyContent(FlexAlign.SpaceEvenly)
            }
            .width('100%')
            .height(36)

            Button($r('app.string.dashboard_start_custom_session'))
              .width('100%')
              .height(36)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#2C4A86')
              .borderRadius(20)
              .onClick(() => this.launchCustomSession())
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 10, bottom: 10 })
          .borderRadius(14)
          .backgroundColor('#171717')

          Column({ space: 6 }) {
            Text($r('app.string.dashboard_favorite_presets_title'))
              .fontSize(14)
              .fontColor('#D9D9D9')

            if (this.favoritePresets.length === 0) {
               Text($r('app.string.dashboard_favorite_presets_empty'))
                .fontColor('#999999')
                .fontSize(11)
            } else {
              ForEach(this.favoritePresets, (preset: IntervalPreset) => {
                Button(this.buildPresetLaunchLabel(preset.name))
                  .width('100%')
                  .height(32)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .backgroundColor('#1F355E')
                  .borderRadius(16)
                  .onClick(() => this.launchPresetSession(preset))
              }, (preset: IntervalPreset) => preset.id)
            }
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 10, bottom: 10 })
          .borderRadius(14)
          .backgroundColor('#171717')

          Column({ space: 6 }) {
            Text($r('app.string.dashboard_recent_presets_title'))
              .fontSize(14)
              .fontColor(Color.White)

            if (this.recentPresets.length === 0) {
               Text($r('app.string.dashboard_recent_presets_empty'))
                .fontColor('#999999')
                .fontSize(11)
            } else {
              ForEach(this.recentPresets, (preset: IntervalPreset) => {
                Button(this.buildPresetLaunchLabel(preset.name))
                  .width('100%')
                  .height(32)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .backgroundColor('#2D2D2D')
                  .borderRadius(16)
                  .onClick(() => this.launchPresetSession(preset))
              }, (preset: IntervalPreset) => preset.id)
            }
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 10, bottom: 10 })
          .borderRadius(14)
          .backgroundColor('#171717')

          Column({ space: 6 }) {
            Text($r('app.string.dashboard_quick_actions_title'))
              .fontSize(14)
              .fontColor('#D9D9D9')

            Row({ space: 6 }) {
              Button($r('app.string.dashboard_action_presets'))
                .layoutWeight(1)
                .height(32)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor('#303030')
                .borderRadius(16)
                .onClick(() => this.pageStack.pushPathByName(AppRoutes.PRESETS, undefined))

              Button($r('app.string.dashboard_action_history'))
                .layoutWeight(1)
                .height(32)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor('#303030')
                .borderRadius(16)
                .onClick(() => this.pageStack.pushPathByName(AppRoutes.HISTORY, undefined))
            }
            .width('100%')

            Row({ space: 6 }) {
              Button($r('app.string.dashboard_action_insights'))
                .layoutWeight(1)
                .height(32)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor('#303030')
                .borderRadius(16)
                .onClick(() => this.pageStack.pushPathByName(AppRoutes.INSIGHTS, undefined))

              Button($r('app.string.dashboard_action_settings'))
                .layoutWeight(1)
                .height(32)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor('#303030')
                .borderRadius(16)
                .onClick(() => this.pageStack.pushPathByName(AppRoutes.SETTINGS, undefined))
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 10, bottom: 10 })
          .borderRadius(14)
          .backgroundColor('#171717')
          }
          .width('100%')
          .padding({ top: 18, left: 12, right: 12, bottom: 20 })
          .backgroundColor(Color.Black)
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Center)
        }
        .height('100%')
      }
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.PagesMap)
    .hideBackButton(true)
  }
}
