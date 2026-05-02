import { AppRoutes } from '../../common/routing/AppRoutes';
import { createSessionPlan } from '../../common/models/IntervalSessionModels';
import { IntervalPreset } from '../../common/models/IntervalPreset';
import { createTimerRouteParam } from '../../common/routing/AppRoutes';
import { PresetDraft, presetRepository } from '../../data/repositories/PresetRepository';

@Builder
export function PresetsPageBuilder() {
  PresetsPage();
}

@Component
export struct PresetsPage {
  @Consume('NavPathStack') private pageStack: NavPathStack;
  private static readonly MIN_DURATION_SEC: number = 0;
  private static readonly MAX_DURATION_SEC: number = 600;
  private static readonly MIN_REPETITIONS: number = 1;
  private static readonly MAX_REPETITIONS: number = 50;

  private getString(resource: Resource): string {
    try {
      return this.getUIContext().getHostContext()?.resourceManager?.getStringSync(resource.id) ?? '';
    } catch (_error) {
      return '';
    }
  }

  @State builtInPresets: IntervalPreset[] = [];
  @State userPresets: IntervalPreset[] = [];
  @State showEditor: boolean = false;
  @State editingPresetId: string = '';
  @State editorName: string = '';
  @State editorWarmUpSec: number = 5;
  @State editorFastSec: number = 20;
  @State editorSlowSec: number = 10;
  @State editorRepetitions: number = 8;
  @State editorCoolDownSec: number = 5;
  @State editorError: string = '';

  aboutToAppear(): void {
    presetRepository.initialize();
    this.reloadData();
  }

  private reloadData(): void {
    this.builtInPresets = presetRepository.getBuiltInPresets();
    this.userPresets = presetRepository.getUserPresets();
  }

  private launchPreset(preset: IntervalPreset): void {
    const selected = presetRepository.markPresetUsed(preset.id);
    const finalPreset = selected ?? preset;
    this.reloadData();
    this.pageStack.pushPathByName(
      AppRoutes.TIMER,
      createTimerRouteParam(createSessionPlan(
        finalPreset.fastDurationSec,
        finalPreset.slowDurationSec,
        finalPreset.repetitions,
        'preset',
        finalPreset.id,
        finalPreset.name,
        finalPreset.warmUpDurationSec,
        finalPreset.coolDownDurationSec
      ))
    );
  }

  private toggleFavorite(presetId: string): void {
    presetRepository.toggleFavorite(presetId);
    this.reloadData();
  }

  private deleteUserPreset(presetId: string): void {
    presetRepository.deleteUserPreset(presetId);
    this.reloadData();
  }

  private beginCreate(): void {
    this.editingPresetId = '';
    this.editorName = `${this.getString($r('app.string.presets_default_routine_name_prefix'))} ${this.userPresets.length + 1}`;
    this.editorWarmUpSec = 5;
    this.editorFastSec = 20;
    this.editorSlowSec = 10;
    this.editorRepetitions = 8;
    this.editorCoolDownSec = 5;
    this.editorError = '';
    this.showEditor = true;
  }

  private beginEdit(preset: IntervalPreset): void {
    this.editingPresetId = preset.id;
    this.editorName = preset.name;
    this.editorWarmUpSec = preset.warmUpDurationSec;
    this.editorFastSec = preset.fastDurationSec;
    this.editorSlowSec = preset.slowDurationSec;
    this.editorRepetitions = preset.repetitions;
    this.editorCoolDownSec = preset.coolDownDurationSec;
    this.editorError = '';
    this.showEditor = true;
  }

  private closeEditor(): void {
    this.showEditor = false;
    this.editorError = '';
  }

  private updateField(field: 'warm-up' | 'work' | 'rest' | 'repetitions' | 'cool-down', delta: number): void {
    if (field === 'warm-up') {
      this.editorWarmUpSec = this.clamp(this.editorWarmUpSec + delta,
        PresetsPage.MIN_DURATION_SEC, PresetsPage.MAX_DURATION_SEC);
    } else if (field === 'work') {
      this.editorFastSec = this.clamp(this.editorFastSec + delta,
        PresetsPage.MIN_DURATION_SEC, PresetsPage.MAX_DURATION_SEC);
    } else if (field === 'rest') {
      this.editorSlowSec = this.clamp(this.editorSlowSec + delta,
        PresetsPage.MIN_DURATION_SEC, PresetsPage.MAX_DURATION_SEC);
    } else if (field === 'repetitions') {
      this.editorRepetitions = this.clamp(this.editorRepetitions + delta,
        PresetsPage.MIN_REPETITIONS, PresetsPage.MAX_REPETITIONS);
    } else {
      this.editorCoolDownSec = this.clamp(this.editorCoolDownSec + delta,
        PresetsPage.MIN_DURATION_SEC, PresetsPage.MAX_DURATION_SEC);
    }
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

  private validateDraft(): PresetDraft | undefined {
    const trimmedName = this.editorName.trim();
    if (trimmedName.length < 3) {
      this.editorError = this.getString($r('app.string.presets_error_name_min_length'));
      return undefined;
    }
    if (this.editorFastSec <= 0) {
      this.editorError = this.getString($r('app.string.presets_error_work_duration'));
      return undefined;
    }
    if (this.editorSlowSec <= 0) {
      this.editorError = this.getString($r('app.string.presets_error_rest_duration'));
      return undefined;
    }
    if (this.editorRepetitions < 1) {
      this.editorError = this.getString($r('app.string.presets_error_repetitions'));
      return undefined;
    }
    this.editorError = '';
    return {
      name: trimmedName,
      warmUpDurationSec: this.editorWarmUpSec,
      fastDurationSec: this.editorFastSec,
      slowDurationSec: this.editorSlowSec,
      repetitions: this.editorRepetitions,
      coolDownDurationSec: this.editorCoolDownSec
    };
  }

  private saveEditor(): void {
    const draft = this.validateDraft();
    if (!draft) {
      return;
    }

    if (this.editingPresetId.length > 0) {
      presetRepository.updatePreset(this.editingPresetId, draft);
    } else {
      presetRepository.createUserPreset(draft);
    }
    this.reloadData();
    this.closeEditor();
  }

  @Builder
  private AdjustmentRow(label: string, value: number, suffix: string, onMinus: () => void, onPlus: () => void) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(12)
        .fontColor('#D6D6D6')
      Row({ space: 8 }) {
        Button('-')
          .width(30)
          .height(28)
          .fontColor(Color.White)
          .fontSize(14)
          .backgroundColor('#2F2F2F')
          .borderRadius(14)
          .onClick(onMinus)
        Text(`${value}${suffix}`)
          .fontColor(Color.White)
          .fontSize(13)
          .width(70)
          .textAlign(TextAlign.Center)
        Button('+')
          .width(30)
          .height(28)
          .fontColor(Color.White)
          .fontSize(14)
          .backgroundColor('#2F2F2F')
          .borderRadius(14)
          .onClick(onPlus)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 2, bottom: 2 })
      .borderRadius(12)
      .backgroundColor('#171717')
    }
    .width('100%')
  }

  @Builder
  private PresetCard(preset: IntervalPreset, allowDelete: boolean) {
    Column({ space: 6 }) {
      Row() {
        Text(preset.name)
          .fontSize(14)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Text(preset.kind === 'built-in' ? $r('app.string.presets_kind_built_in') : $r('app.string.presets_kind_custom'))
          .fontSize(10)
          .fontColor(preset.kind === 'built-in' ? '#8BB5FF' : '#8ED4A8')
      }
      .width('100%')

      Text(`${this.getString($r('app.string.presets_plan_warm_up_prefix'))} ${preset.warmUpDurationSec}s  •  ${preset.fastDurationSec}s / ${preset.slowDurationSec}s x${preset.repetitions}  •  ${this.getString($r('app.string.presets_plan_cool_down_prefix'))} ${preset.coolDownDurationSec}s`)
        .fontSize(11)
        .fontColor('#C6C6C6')

      Row({ space: 6 }) {
        Button($r('app.string.presets_start_button'))
          .layoutWeight(1)
          .height(30)
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor('#2C4A86')
          .borderRadius(15)
          .onClick(() => this.launchPreset(preset))

        Button(preset.isFavorite ? '★' : '☆')
          .width(36)
          .height(30)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#313131')
          .borderRadius(15)
          .onClick(() => this.toggleFavorite(preset.id))

        if (preset.kind === 'user') {
          Button($r('app.string.presets_edit_button'))
            .width(46)
            .height(30)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#313131')
            .borderRadius(15)
            .onClick(() => this.beginEdit(preset))
        }

        if (allowDelete) {
          Button($r('app.string.presets_delete_button'))
            .width(42)
            .height(30)
            .fontSize(11)
            .fontColor('#FFC4C4')
            .backgroundColor('#402020')
            .borderRadius(15)
            .onClick(() => this.deleteUserPreset(preset.id))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .borderRadius(14)
    .backgroundColor('#121212')
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 10 }) {
          Text($r('app.string.presets_title'))
            .width('100%')
            .fontColor(Color.White)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
            .padding({ left: 12, right: 12 })

          Text($r('app.string.presets_editor_helper'))
            .fontSize(10)
            .fontColor('#9C9C9C')

          if (!this.showEditor) {
            Column({ space: 8 }) {
              Row() {
                Text($r('app.string.presets_my_routines_title'))
                  .fontSize(14)
                  .fontColor(Color.White)
                  .layoutWeight(1)
                Button($r('app.string.presets_new_button'))
                  .height(28)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .backgroundColor('#23553A')
                  .borderRadius(14)
                  .onClick(() => this.beginCreate())
              }
              .width('100%')

              if (this.userPresets.length === 0) {
                Text($r('app.string.presets_empty_custom'))
                  .fontSize(11)
                  .fontColor('#A3A3A3')
              } else {
                ForEach(this.userPresets, (preset: IntervalPreset) => {
                  this.PresetCard(preset, true)
                }, (preset: IntervalPreset) => preset.id)
              }
            }
            .width('100%')
            .padding(10)
            .borderRadius(14)
            .backgroundColor('#1A1A1A')

            Column({ space: 8 }) {
              Text($r('app.string.presets_built_in_title'))
                .fontSize(14)
                .fontColor('#D7D7D7')
              ForEach(this.builtInPresets, (preset: IntervalPreset) => {
                this.PresetCard(preset, false)
              }, (preset: IntervalPreset) => preset.id)
            }
            .width('100%')
            .padding(10)
            .borderRadius(14)
            .backgroundColor('#1A1A1A')
          } else {
            Column({ space: 8 }) {
              Text(this.editingPresetId ? $r('app.string.presets_edit_routine_title') : $r('app.string.presets_create_routine_title'))
                .fontColor(Color.White)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)

              TextInput({ text: this.editorName, placeholder: this.getString($r('app.string.presets_routine_name_placeholder')) })
                .width('100%')
                .height(34)
                .fontSize(12)
                .fontColor(Color.White)
                .placeholderColor('#888888')
                .backgroundColor('#131313')
                .borderRadius(12)
                .onChange((value: string) => {
                  this.editorName = value;
                })

              this.AdjustmentRow(this.getString($r('app.string.timer_phase_warm_up')), this.editorWarmUpSec, 's',
                () => this.updateField('warm-up', -5), () => this.updateField('warm-up', 5))
              this.AdjustmentRow(this.getString($r('app.string.timer_phase_work')), this.editorFastSec, 's',
                () => this.updateField('work', -5), () => this.updateField('work', 5))
              this.AdjustmentRow(this.getString($r('app.string.timer_phase_rest')), this.editorSlowSec, 's',
                () => this.updateField('rest', -5), () => this.updateField('rest', 5))
              this.AdjustmentRow(this.getString($r('app.string.settings_repetitions')), this.editorRepetitions, '',
                () => this.updateField('repetitions', -1), () => this.updateField('repetitions', 1))
              this.AdjustmentRow(this.getString($r('app.string.timer_phase_cool_down')), this.editorCoolDownSec, 's',
                () => this.updateField('cool-down', -5), () => this.updateField('cool-down', 5))

              if (this.editorError.length > 0) {
                Text(this.editorError)
                  .fontSize(10)
                  .fontColor('#FF9D9D')
              }

              Row({ space: 8 }) {
                Button($r('app.string.common_cancel_button'))
                  .layoutWeight(1)
                  .height(30)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .backgroundColor('#343434')
                  .borderRadius(15)
                  .onClick(() => this.closeEditor())
                Button($r('app.string.common_save_button'))
                  .layoutWeight(1)
                  .height(30)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .backgroundColor('#2C4A86')
                  .borderRadius(15)
                  .onClick(() => this.saveEditor())
              }
              .width('100%')
            }
            .width('100%')
            .padding(10)
            .borderRadius(14)
            .backgroundColor('#1A1A1A')
          }
        }
        .width('100%')
        .padding({ top: 10, left: 10, right: 10, bottom: 20 })
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#0A0A0A')
      }
      .height('100%')
    }
    .title(AppRoutes.PRESETS)
    .hideTitleBar(true)
  }
}
