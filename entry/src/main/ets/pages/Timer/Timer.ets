import TimerConstants from '../../common/constants/TimerConstants';
import {
  createSessionPlan,
  IntervalSessionResult,
  SessionLifecycleState,
  SessionPhase
} from '../../common/models/IntervalSessionModels';
import {
  AppRoutes,
  createSessionSummaryRouteParam,
  createTimerRouteParam,
  TimerRouteParam
} from '../../common/routing/AppRoutes';
import { sessionHistoryRepository } from '../../data/repositories/SessionHistoryRepository';
import {
  activeSessionRecoveryRepository,
  ActiveSessionSnapshot
} from '../../data/repositories/ActiveSessionRecoveryRepository';
import { AppSettings, createDefaultSettings } from '../../common/models/AppSettings';
import { settingsRepository } from '../../data/repositories/SettingsRepository';
import { TimerService } from '../../viewmodel/TimerService';
import { hapticCoachService } from '../../viewmodel/HapticCoachService';
import { window } from '@kit.ArkUI';

interface RuntimePhase {
  type: SessionPhase;
  durationSec: number;
  roundNumber: number;
}

@Builder
export function TimerPageBuilder() {
  Timer();
}

@Component
export struct Timer {
  private static readonly MIN_DURATION_SEC: number = 1;
  private static readonly MIN_REPETITIONS: number = 1;
  @Consume('NavPathStack') private pageStack: NavPathStack;
  private timerService: TimerService = new TimerService();
  params: TimerRouteParam = createTimerRouteParam(createSessionPlan(10, 5, 2));
  private fastDuration: number = 10;
  private slowDuration: number = 5;
  private warmUpDuration: number = 5;
  private coolDownDuration: number = 5;
  private repetitions: number = 2;
  private runtimePhases: RuntimePhase[] = [];
  private phaseIndex: number = 0;
  private phaseStartRemainingMs: number = 0;
  private sessionStartedAt: number = 0;
  private hasFinalized: boolean = false;
  private lastPhaseBeforePause: SessionPhase = 'warm-up';
  private lastPersistedAt: number = 0;
  private settings: AppSettings = createDefaultSettings();
  private lastCountdownCueSec: number = -1;
  private keepScreenAwakeApplied: boolean = false;

  @State currentState: SessionLifecycleState = 'warm-up';
  @State timerSec: number = 1;
  @State remainderMs: number = TimerConstants.SEC_TO_MS;
  @State currentGradient: LinearGradient = TimerConstants.INIT_COUNTDOWN_GD;
  @State currentActivity: string = 'Warm-Up';
  @State currentPhaseType: SessionPhase = 'warm-up';
  @State currentRoundDisplay: number = 0;
  @State isPaused: boolean = false;
  @State showRoundLabels: boolean = true;

  aboutToAppear(): void {
    sessionHistoryRepository.initialize();
    activeSessionRecoveryRepository.initialize();
    settingsRepository.initialize();
    this.settings = settingsRepository.loadSettings();
    this.showRoundLabels = this.settings.showRoundLabels;
    this.loadParameters();
    this.buildRuntimePhases();
    if (!this.tryRestoreSession()) {
      this.beginSession();
    }
  }

  aboutToDisappear(): void {
    this.updateKeepScreenAwake(false);
    if (this.hasFinalized || this.currentState === 'completed') {
      this.timerService.clear();
      return;
    }
    this.remainderMs = this.timerService.pause();
    this.isPaused = true;
    this.currentState = 'paused';
    this.persistSession();
  }

  private loadParameters(): void {
    if (!this.params || !this.params.plan) {
      return;
    }

    this.fastDuration = this.normalizeDuration(this.params.plan.fastDurationSec);
    this.slowDuration = this.normalizeDuration(this.params.plan.slowDurationSec);
    this.repetitions = this.normalizeRepetitions(this.params.plan.repetitions);
    this.warmUpDuration = this.normalizeOptionalDuration(this.params.plan.warmUpDurationSec, 5);
    this.coolDownDuration = this.normalizeOptionalDuration(this.params.plan.coolDownDurationSec, 5);
  }

  private buildRuntimePhases(): void {
    this.runtimePhases = [];
    if (this.warmUpDuration > 0) {
      this.runtimePhases.push({ type: 'warm-up', durationSec: this.warmUpDuration, roundNumber: 0 });
    }

    for (let index = 0; index < this.repetitions; index++) {
      this.runtimePhases.push({ type: 'work', durationSec: this.fastDuration, roundNumber: index + 1 });
      this.runtimePhases.push({ type: 'rest', durationSec: this.slowDuration, roundNumber: index + 1 });
    }

    if (this.coolDownDuration > 0) {
      this.runtimePhases.push({ type: 'cool-down', durationSec: this.coolDownDuration, roundNumber: this.repetitions });
    }
  }

  private beginSession(): void {
    this.phaseIndex = 0;
    this.hasFinalized = false;
    this.sessionStartedAt = Date.now();
    this.lastPersistedAt = 0;
    this.runCurrentPhase();
    this.applyKeepScreenAwakePolicy();
  }

  private runCurrentPhase(): void {
    if (this.phaseIndex >= this.runtimePhases.length) {
      this.finalizeSession('completed');
      return;
    }

    const phase = this.runtimePhases[this.phaseIndex];
    this.currentState = phase.type;
    this.isPaused = false;
    this.timerSec = phase.durationSec;
    this.remainderMs = phase.durationSec * TimerConstants.SEC_TO_MS;
    this.phaseStartRemainingMs = this.remainderMs;
    this.lastPhaseBeforePause = phase.type;
    this.updatePhaseUI(phase.type, phase.roundNumber);
    this.lastCountdownCueSec = -1;
    this.triggerHapticCue('phase-change');
    this.applyKeepScreenAwakePolicy();

    this.timerService.start(phase.durationSec,
      (remainingMs: number) => {
        this.remainderMs = remainingMs;
        this.emitCountdownCueIfNeeded();
        this.persistSessionIfDue();
      },
      () => {
        this.phaseIndex += 1;
        this.runCurrentPhase();
      });
    this.persistSession();
  }

  private updatePhaseUI(phase: SessionPhase, roundNumber: number): void {
    this.currentPhaseType = phase;
    this.currentRoundDisplay = roundNumber;
    if (phase === 'warm-up') {
      this.currentActivity = 'Warm-Up';
      this.currentGradient = TimerConstants.INIT_COUNTDOWN_GD;
      return;
    }
    if (phase === 'work') {
      this.currentActivity = 'Work';
      this.currentGradient = TimerConstants.FAST_DURATION_GD;
      return;
    }
    if (phase === 'rest') {
      this.currentActivity = 'Rest';
      this.currentGradient = TimerConstants.SLOW_DURATION_GD;
      return;
    }
    this.currentActivity = 'Cool-Down';
    this.currentGradient = new LinearGradient([{ color: '#5A7BFF', offset: 0 }, { color: '#8FE8FF', offset: 1 }]);
  }

  private pauseTimer(): void {
    if (this.isPaused || this.hasFinalized || this.currentState === 'completed') {
      return;
    }
    this.lastPhaseBeforePause = this.currentState as SessionPhase;
    this.remainderMs = this.timerService.pause();
    this.currentState = 'paused';
    this.isPaused = true;
    this.triggerHapticCue('pause');
    this.applyKeepScreenAwakePolicy();
    this.persistSession();
  }

  private resumeTimer(): void {
    if (!this.isPaused || this.hasFinalized) {
      return;
    }
    this.isPaused = false;
    this.currentState = this.lastPhaseBeforePause;
    this.updatePhaseUI(this.lastPhaseBeforePause, this.currentRoundDisplay);
    this.timerService.resume();
    this.triggerHapticCue('resume');
    this.applyKeepScreenAwakePolicy();
    this.persistSession();
  }

  private extendCurrentPhase(extraSec: number): void {
    if (this.hasFinalized || this.currentState === 'completed') {
      return;
    }
    const remaining = this.timerService.addSeconds(extraSec);
    this.remainderMs = remaining;
    this.timerSec = Math.max(this.timerSec, Math.ceil(remaining / TimerConstants.SEC_TO_MS));
    this.phaseStartRemainingMs += extraSec * TimerConstants.SEC_TO_MS;
    this.persistSession();
  }

  private skipPhase(): void {
    if (this.hasFinalized || this.currentState === 'completed') {
      return;
    }
    this.timerService.clear();
    this.phaseIndex += 1;
    this.runCurrentPhase();
  }

  private restartSession(): void {
    if (this.hasFinalized) {
      return;
    }
    this.timerService.clear();
    this.buildRuntimePhases();
    this.beginSession();
  }

  private stopSession(): void {
    this.finalizeSession('stopped');
  }

  private finalizeSession(status: 'completed' | 'stopped'): void {
    if (this.hasFinalized) {
      return;
    }
    this.hasFinalized = true;
    this.timerService.clear();
    this.updateKeepScreenAwake(false);
    activeSessionRecoveryRepository.clear();
    this.currentState = 'completed';
    if (status === 'completed') {
      this.triggerHapticCue('complete');
    }

    const sourcePresetId = this.params && this.params.plan ? this.params.plan.sourcePresetId : undefined;
    const label = this.params && this.params.plan ? this.params.plan.label : 'Custom';
    const endedAt = Date.now();
    const completedRounds = this.getCompletedRounds();
    const result: IntervalSessionResult = {
      id: `session-${endedAt}`,
      plan: createSessionPlan(this.fastDuration, this.slowDuration, this.repetitions, this.getSafePlanSource(),
        sourcePresetId, label, this.warmUpDuration, this.coolDownDuration),
      startedAt: this.sessionStartedAt,
      endedAt,
      completedRounds,
      totalRounds: this.repetitions,
      completed: status === 'completed',
      status,
      totalDurationSec: this.getPlannedTotalDurationSec(),
      elapsedSec: Math.max(0, Math.floor((endedAt - this.sessionStartedAt) / TimerConstants.SEC_TO_MS)),
      interruptionNote: undefined
    };

    sessionHistoryRepository.add(result);
    this.pageStack.pushPathByName(AppRoutes.SESSION_SUMMARY, createSessionSummaryRouteParam(result));
  }

  private tryRestoreSession(): boolean {
    const snapshot = activeSessionRecoveryRepository.load();
    if (snapshot === undefined) {
      return false;
    }

    if (!this.isSnapshotForCurrentPlan(snapshot)) {
      activeSessionRecoveryRepository.clear();
      return false;
    }

    if (!this.restoreFromSnapshot(snapshot)) {
      this.failRecovery(snapshot);
      return true;
    }

    return true;
  }

  private restoreFromSnapshot(snapshot: ActiveSessionSnapshot): boolean {
    if (snapshot.phaseIndex < 0 || snapshot.phaseIndex >= this.runtimePhases.length) {
      return false;
    }

    let restoredIndex = Math.floor(snapshot.phaseIndex);
    let restoredRemainderMs = Math.floor(snapshot.remainderMs);
    if (restoredRemainderMs <= 0) {
      return false;
    }

    if (!snapshot.isPaused) {
      const elapsedSinceSave = Math.max(0, Date.now() - snapshot.savedAt);
      restoredRemainderMs -= elapsedSinceSave;
      while (restoredIndex < this.runtimePhases.length && restoredRemainderMs <= 0) {
        restoredIndex += 1;
        if (restoredIndex >= this.runtimePhases.length) {
          this.phaseIndex = this.runtimePhases.length;
          this.sessionStartedAt = snapshot.sessionStartedAt;
          this.finalizeSession('completed');
          return true;
        }
        restoredRemainderMs += this.runtimePhases[restoredIndex].durationSec * TimerConstants.SEC_TO_MS;
      }
    }

    if (restoredIndex < 0 || restoredIndex >= this.runtimePhases.length || restoredRemainderMs <= 0) {
      return false;
    }

    const phase = this.runtimePhases[restoredIndex];
    this.phaseIndex = restoredIndex;
    this.hasFinalized = false;
    this.sessionStartedAt = snapshot.sessionStartedAt;
    this.lastPhaseBeforePause = snapshot.lastPhaseBeforePause;
    this.currentRoundDisplay = phase.roundNumber;
    this.phaseStartRemainingMs = restoredIndex === snapshot.phaseIndex ? Math.max(restoredRemainderMs,
      Math.floor(snapshot.phaseStartRemainingMs)) : phase.durationSec * TimerConstants.SEC_TO_MS;
    this.remainderMs = restoredRemainderMs;
    this.timerSec = Math.max(1, Math.ceil(this.remainderMs / TimerConstants.SEC_TO_MS));
    this.updatePhaseUI(phase.type, phase.roundNumber);

    if (snapshot.isPaused) {
      this.isPaused = true;
      this.currentState = 'paused';
      this.timerService.preparePaused(this.remainderMs,
        (remainingMs: number) => {
          this.remainderMs = remainingMs;
          this.emitCountdownCueIfNeeded();
          this.persistSessionIfDue();
        },
        () => {
          this.phaseIndex += 1;
          this.runCurrentPhase();
        });
      this.applyKeepScreenAwakePolicy();
      this.persistSession();
      return true;
    }

    this.currentState = phase.type;
    this.isPaused = false;
    this.applyKeepScreenAwakePolicy();
    this.timerService.startWithRemainingMs(this.remainderMs,
      (remainingMs: number) => {
        this.remainderMs = remainingMs;
        this.emitCountdownCueIfNeeded();
        this.persistSessionIfDue();
      },
      () => {
        this.phaseIndex += 1;
        this.runCurrentPhase();
      });
    this.persistSession();
    return true;
  }

  private failRecovery(snapshot: ActiveSessionSnapshot): void {
    this.hasFinalized = true;
    this.timerService.clear();
    activeSessionRecoveryRepository.clear();
    this.currentState = 'completed';

    const endedAt = Date.now();
    const result: IntervalSessionResult = {
      id: `session-${endedAt}`,
      plan: createSessionPlan(this.fastDuration, this.slowDuration, this.repetitions, this.getSafePlanSource(),
        this.params.plan.sourcePresetId, this.params.plan.label, this.warmUpDuration, this.coolDownDuration),
      startedAt: snapshot.sessionStartedAt,
      endedAt,
      completedRounds: Math.max(0, Math.min(this.repetitions, this.estimateCompletedRounds(snapshot.phaseIndex))),
      totalRounds: this.repetitions,
      completed: false,
      status: 'stopped',
      totalDurationSec: this.getPlannedTotalDurationSec(),
      elapsedSec: Math.max(0, Math.floor((endedAt - snapshot.sessionStartedAt) / TimerConstants.SEC_TO_MS)),
      interruptionNote: 'Session was restored after an interruption and auto-stopped for safety.'
    };
    sessionHistoryRepository.add(result);
    this.pageStack.pushPathByName(AppRoutes.SESSION_SUMMARY, createSessionSummaryRouteParam(result));
  }

  private estimateCompletedRounds(currentPhaseIndex: number): number {
    let completed = 0;
    for (let index = 0; index < currentPhaseIndex && index < this.runtimePhases.length; index++) {
      if (this.runtimePhases[index].type === 'rest') {
        completed += 1;
      }
    }
    return completed;
  }

  private persistSessionIfDue(): void {
    const now = Date.now();
    if (now - this.lastPersistedAt < TimerConstants.SEC_TO_MS) {
      return;
    }
    this.persistSession();
  }

  private persistSession(): void {
    if (this.hasFinalized || this.phaseIndex < 0 || this.phaseIndex >= this.runtimePhases.length) {
      return;
    }

    const activePhase = this.runtimePhases[this.phaseIndex];
    const snapshot: ActiveSessionSnapshot = {
      version: 1,
      launchToken: this.params.launchToken,
      plan: this.params.plan,
      phaseIndex: this.phaseIndex,
      phaseType: activePhase.type,
      phaseStartRemainingMs: Math.max(1, Math.floor(this.phaseStartRemainingMs)),
      remainderMs: Math.max(1, Math.floor(this.remainderMs)),
      currentRoundDisplay: this.currentRoundDisplay,
      isPaused: this.isPaused,
      lastPhaseBeforePause: this.lastPhaseBeforePause,
      sessionStartedAt: this.sessionStartedAt,
      savedAt: Date.now()
    };
    activeSessionRecoveryRepository.save(snapshot);
    this.lastPersistedAt = snapshot.savedAt;
  }

  private isSnapshotForCurrentPlan(snapshot: ActiveSessionSnapshot): boolean {
    if (this.params.launchToken !== snapshot.launchToken) {
      return false;
    }

    const currentPlan = this.params.plan;
    const snapshotPlan = snapshot.plan;
    return currentPlan.fastDurationSec === snapshotPlan.fastDurationSec &&
      currentPlan.slowDurationSec === snapshotPlan.slowDurationSec &&
      currentPlan.repetitions === snapshotPlan.repetitions &&
      this.normalizeOptionalDuration(currentPlan.warmUpDurationSec, 5) ===
      this.normalizeOptionalDuration(snapshotPlan.warmUpDurationSec, 5) &&
      this.normalizeOptionalDuration(currentPlan.coolDownDurationSec, 5) ===
      this.normalizeOptionalDuration(snapshotPlan.coolDownDurationSec, 5) &&
      currentPlan.source === snapshotPlan.source &&
      (currentPlan.sourcePresetId ?? '') === (snapshotPlan.sourcePresetId ?? '') &&
      (currentPlan.label ?? '') === (snapshotPlan.label ?? '');
  }

  private getCompletedRounds(): number {
    let completed = 0;
    for (let index = 0; index < this.phaseIndex && index < this.runtimePhases.length; index++) {
      if (this.runtimePhases[index].type === 'rest') {
        completed += 1;
      }
    }
    return Math.min(completed, this.repetitions);
  }

  private getPlannedTotalDurationSec(): number {
    const roundsDuration = (this.fastDuration + this.slowDuration) * this.repetitions;
    return roundsDuration + this.warmUpDuration + this.coolDownDuration;
  }

  private getRoundLabel(): string {
    if (this.currentPhaseType === 'warm-up' || this.currentPhaseType === 'cool-down') {
      return '';
    }
    return `Round ${this.currentRoundDisplay}/${this.repetitions}`;
  }

  private emitCountdownCueIfNeeded(): void {
    if (this.currentState === 'paused' || this.currentState === 'completed') {
      return;
    }

    const remainingSec = Math.ceil(this.remainderMs / TimerConstants.SEC_TO_MS);
    if (remainingSec <= 0 || remainingSec > 3 || remainingSec === this.lastCountdownCueSec) {
      return;
    }
    this.lastCountdownCueSec = remainingSec;
    this.triggerHapticCue('countdown');
  }

  private triggerHapticCue(cue: 'phase-change' | 'pause' | 'resume' | 'countdown' | 'complete'): void {
    hapticCoachService.triggerCue(cue, this.settings);
  }

  private applyKeepScreenAwakePolicy(): void {
    const shouldKeepAwake = this.settings.keepScreenAwake && !this.hasFinalized && !this.isPaused &&
      this.currentState !== 'completed';
    this.updateKeepScreenAwake(shouldKeepAwake);
  }

  private updateKeepScreenAwake(shouldKeepAwake: boolean): void {
    if (this.keepScreenAwakeApplied === shouldKeepAwake) {
      return;
    }

    const hostContext = this.getUIContext().getHostContext();
    window.getLastWindow(hostContext)
      .then((hostWindow: window.Window) => {
        hostWindow.setWindowKeepScreenOn(shouldKeepAwake)
          .then(() => {
            this.keepScreenAwakeApplied = shouldKeepAwake;
          })
          .catch(() => {
          });
      })
      .catch(() => {
      });
  }

  private formatRemaining(): string {
    const totalSec = Math.max(0, Math.ceil(this.remainderMs / TimerConstants.SEC_TO_MS));
    const minutes = Math.floor(totalSec / 60);
    const seconds = totalSec % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private normalizeDuration(value: number): number {
    if (!Number.isFinite(value)) {
      return Timer.MIN_DURATION_SEC;
    }
    const normalized = Math.floor(value);
    if (normalized < Timer.MIN_DURATION_SEC) {
      return Timer.MIN_DURATION_SEC;
    }
    return normalized;
  }

  private normalizeOptionalDuration(value: number | undefined, fallback: number): number {
    if (value === undefined) {
      return fallback;
    }
    if (!Number.isFinite(value)) {
      return fallback;
    }
    const normalized = Math.floor(value);
    if (normalized < 0) {
      return 0;
    }
    return normalized;
  }

  private normalizeRepetitions(value: number): number {
    if (!Number.isFinite(value)) {
      return Timer.MIN_REPETITIONS;
    }
    const normalized = Math.floor(value);
    if (normalized < Timer.MIN_REPETITIONS) {
      return Timer.MIN_REPETITIONS;
    }
    return normalized;
  }

  private getSafePlanSource(): 'manual' | 'preset' {
    if (this.params && this.params.plan && this.params.plan.source === 'preset') {
      return 'preset';
    }
    return 'manual';
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Stack({ alignContent: Alignment.Center }) {
          Progress({
            value: this.remainderMs,
            total: this.phaseStartRemainingMs,
            type: ProgressType.Ring
          })
            .width(233)
            .height(233)
            .color(this.currentGradient)
            .style({ strokeWidth: 14, enableScanEffect: true })

          Column({ space: 3 }) {
            Text(this.formatRemaining())
              .fontColor('#FFFFFF')
              .fontSize(38)
              .fontWeight(700)

            Text(this.currentActivity)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isPaused ? '#9CC9FF' : '#A5EAC6')
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.showRoundLabels && this.getRoundLabel().length > 0) {
              Text(this.getRoundLabel())
                .fontSize(9)
                .fontColor('#8D97B1')
                .textAlign(TextAlign.Center)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width(132)
          .alignItems(HorizontalAlign.Center)
        }

        Button() {
          SymbolGlyph($r('sys.symbol.redo'))
            .fontSize(14)
            .fontColor(['#E7F1FF'])
        }
          .width(24)
          .height(24)
          .backgroundColor('#355C7D')
          .borderRadius(12)
          .position({ x: 41, y: 152 })
          .onClick(() => {
            this.restartSession();
          })

        Button() {
          SymbolGlyph($r('sys.symbol.square'))
            .fontSize(13)
            .fontColor(['#FFE8E8'])
        }
          .width(24)
          .height(24)
          .backgroundColor('#7A3131')
          .borderRadius(12)
          .position({ x: 168, y: 152 })
          .onClick(() => {
            this.stopSession();
          })

        Button() {
          SymbolGlyph($r('sys.symbol.goforward_10'))
            .fontSize(14)
            .fontColor(['#FDF2E0'])
        }
          .width(26)
          .height(26)
          .backgroundColor('#6C4A28')
          .borderRadius(13)
          .position({ x: 64, y: 173 })
          .onClick(() => {
            this.extendCurrentPhase(10);
          })

        Button() {
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(14)
            .fontColor(['#F4F4F5'])
        }
          .width(24)
          .height(24)
          .backgroundColor('#4A4A4A')
          .borderRadius(12)
          .position({ x: 145, y: 173 })
          .onClick(() => {
            this.skipPhase();
          })

        Button() {
          SymbolGlyph(this.isPaused ? $r('sys.symbol.play') : $r('sys.symbol.pause'))
            .fontSize(15)
            .fontColor(['#FFFFFF'])
        }
          .width(28)
          .height(28)
          .backgroundColor(this.isPaused ? '#2A6D51' : '#2D4F80')
          .borderRadius(14)
          .position({ x: 102, y: 183 })
          .onClick(() => {
            if (this.isPaused) {
              this.resumeTimer();
            } else {
              this.pauseTimer();
            }
          })
      }
      .height('100%')
      .width('100%')
      .padding({ top: 0, bottom: 0, left: 0, right: 0 })
      .backgroundColor('#0A0A0A')
    }
    .hideTitleBar(true)
    .title(AppRoutes.TIMER)
    .mode(NavDestinationMode.STANDARD)
  }
}
