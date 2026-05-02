import { IntervalSessionPlan, SessionPhase } from '../../common/models/IntervalSessionModels';

const ACTIVE_SESSION_STORAGE_KEY: string = 'intervalClock.activeSession.v1';

export interface ActiveSessionSnapshot {
  version: number;
  launchToken: string;
  plan: IntervalSessionPlan;
  phaseIndex: number;
  phaseType: SessionPhase;
  phaseStartRemainingMs: number;
  remainderMs: number;
  currentRoundDisplay: number;
  isPaused: boolean;
  lastPhaseBeforePause: SessionPhase;
  sessionStartedAt: number;
  savedAt: number;
}

export class ActiveSessionRecoveryRepository {
  initialize(): void {
    if (AppStorage.get<string>(ACTIVE_SESSION_STORAGE_KEY) === undefined) {
      PersistentStorage.persistProp(ACTIVE_SESSION_STORAGE_KEY, '');
    }
  }

  load(): ActiveSessionSnapshot | undefined {
    const raw = AppStorage.get<string>(ACTIVE_SESSION_STORAGE_KEY) ?? '';
    if (!raw || raw.length === 0) {
      return undefined;
    }

    try {
      const parsed = JSON.parse(raw) as Object;
      if (!this.isValidSnapshot(parsed)) {
        this.clear();
        return undefined;
      }
      return parsed as ActiveSessionSnapshot;
    } catch (_error) {
      this.clear();
      return undefined;
    }
  }

  save(snapshot: ActiveSessionSnapshot): void {
    AppStorage.set<string>(ACTIVE_SESSION_STORAGE_KEY, JSON.stringify(snapshot));
  }

  clear(): void {
    AppStorage.set<string>(ACTIVE_SESSION_STORAGE_KEY, '');
  }

  private isValidSnapshot(value: Object): boolean {
    const snapshot = value as ActiveSessionSnapshot;
    return typeof snapshot.version === 'number' && snapshot.version === 1 &&
      typeof snapshot.launchToken === 'string' && snapshot.launchToken.length > 0 &&
      snapshot.plan !== undefined &&
      typeof snapshot.phaseIndex === 'number' &&
      typeof snapshot.phaseStartRemainingMs === 'number' &&
      typeof snapshot.remainderMs === 'number' &&
      typeof snapshot.currentRoundDisplay === 'number' &&
      typeof snapshot.isPaused === 'boolean' &&
      typeof snapshot.sessionStartedAt === 'number' &&
      typeof snapshot.savedAt === 'number' &&
      (snapshot.phaseType === 'warm-up' || snapshot.phaseType === 'work' || snapshot.phaseType === 'rest' ||
        snapshot.phaseType === 'cool-down') &&
      (snapshot.lastPhaseBeforePause === 'warm-up' || snapshot.lastPhaseBeforePause === 'work' ||
        snapshot.lastPhaseBeforePause === 'rest' || snapshot.lastPhaseBeforePause === 'cool-down');
  }
}

export const activeSessionRecoveryRepository: ActiveSessionRecoveryRepository = new ActiveSessionRecoveryRepository();
