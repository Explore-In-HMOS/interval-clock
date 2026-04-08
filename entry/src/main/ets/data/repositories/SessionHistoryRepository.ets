import { IntervalSessionResult } from '../../common/models/IntervalSessionModels';

const SESSION_HISTORY_STORAGE_KEY: string = 'intervalClock.sessionHistory.v1';

interface SessionHistoryEnvelope {
  version: number;
  sessions: IntervalSessionResult[];
}

export class SessionHistoryRepository {
  initialize(): void {
    if (AppStorage.get<string>(SESSION_HISTORY_STORAGE_KEY) === undefined) {
      PersistentStorage.persistProp(SESSION_HISTORY_STORAGE_KEY, '');
    }
  }

  list(limit: number = 20): IntervalSessionResult[] {
    return this.readAll().slice(0, limit);
  }

  listAll(): IntervalSessionResult[] {
    return this.readAll();
  }

  add(result: IntervalSessionResult): void {
    const current = this.readAll();
    current.unshift(result);
    const trimmed = current.slice(0, 50);
    this.writeAll(trimmed);
  }

  private readAll(): IntervalSessionResult[] {
    const raw = AppStorage.get<string>(SESSION_HISTORY_STORAGE_KEY) ?? '';
    if (!raw || raw.length === 0) {
      return [];
    }

    try {
      const parsed = JSON.parse(raw) as Object;
      if (this.isEnvelope(parsed)) {
        const envelope = parsed as SessionHistoryEnvelope;
        if (envelope.version <= 1 && Array.isArray(envelope.sessions)) {
          return this.sanitizeSessions(envelope.sessions);
        }
        return [];
      }

      if (Array.isArray(parsed)) {
        return this.sanitizeSessions(parsed);
      }
      return [];
    } catch (_error) {
      return [];
    }
  }

  private sanitizeSessions(value: Object[]): IntervalSessionResult[] {
    const sessions: IntervalSessionResult[] = [];
    for (let index = 0; index < value.length; index++) {
      if (this.isSessionResultRecord(value[index])) {
        sessions.push(value[index] as IntervalSessionResult);
      }
    }
    return sessions;
  }

  private writeAll(sessions: IntervalSessionResult[]): void {
    const envelope: SessionHistoryEnvelope = {
      version: 1,
      sessions
    };
    AppStorage.set<string>(SESSION_HISTORY_STORAGE_KEY, JSON.stringify(envelope));
  }

  private isEnvelope(value: Object): boolean {
    return !!((value as SessionHistoryEnvelope).sessions);
  }

  private isSessionResultRecord(value: Object): boolean {
    if (value === null || typeof value !== 'object') {
      return false;
    }

    const session = value as IntervalSessionResult;
    const plan = session.plan;
    return plan !== undefined
      && plan !== null
      && typeof plan === 'object'
      && typeof session.id === 'string'
      && typeof session.startedAt === 'number'
      && Number.isFinite(session.startedAt)
      && typeof session.endedAt === 'number'
      && Number.isFinite(session.endedAt)
      && typeof session.completedRounds === 'number'
      && Number.isFinite(session.completedRounds)
      && typeof session.totalRounds === 'number'
      && Number.isFinite(session.totalRounds)
      && typeof session.completed === 'boolean'
      && (session.status === 'completed' || session.status === 'stopped')
      && typeof session.totalDurationSec === 'number'
      && Number.isFinite(session.totalDurationSec)
      && typeof session.elapsedSec === 'number'
      && Number.isFinite(session.elapsedSec)
      && typeof plan.fastDurationSec === 'number'
      && Number.isFinite(plan.fastDurationSec)
      && typeof plan.slowDurationSec === 'number'
      && Number.isFinite(plan.slowDurationSec)
      && typeof plan.repetitions === 'number'
      && Number.isFinite(plan.repetitions)
      && (plan.label === undefined || typeof plan.label === 'string')
      && (plan.sourcePresetId === undefined || typeof plan.sourcePresetId === 'string')
      && (session.interruptionNote === undefined || typeof session.interruptionNote === 'string')
      && (plan.source === 'manual' || plan.source === 'preset');
  }
}

export const sessionHistoryRepository: SessionHistoryRepository = new SessionHistoryRepository();
