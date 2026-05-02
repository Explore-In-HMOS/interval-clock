export interface IntervalSessionPlan {
  fastDurationSec: number;
  slowDurationSec: number;
  repetitions: number;
  warmUpDurationSec?: number;
  coolDownDurationSec?: number;
  source: 'manual' | 'preset';
  sourcePresetId?: string;
  label?: string;
}

export type SessionPhase = 'warm-up' | 'work' | 'rest' | 'cool-down';

export type SessionLifecycleState = SessionPhase | 'paused' | 'completed';

export interface IntervalSessionResult {
  id: string;
  plan: IntervalSessionPlan;
  startedAt: number;
  endedAt: number;
  completedRounds: number;
  totalRounds: number;
  completed: boolean;
  status: 'completed' | 'stopped';
  totalDurationSec: number;
  elapsedSec: number;
  interruptionNote?: string;
}

export function createSessionPlan(fastDurationSec: number, slowDurationSec: number, repetitions: number,
  source: 'manual' | 'preset' = 'manual', sourcePresetId?: string, label?: string,
  warmUpDurationSec: number = 5, coolDownDurationSec: number = 5): IntervalSessionPlan {
  return {
    fastDurationSec,
    slowDurationSec,
    repetitions,
    warmUpDurationSec,
    coolDownDurationSec,
    source,
    sourcePresetId,
    label
  };
}
