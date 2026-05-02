export interface IntervalPreset {
  id: string;
  name: string;
  fastDurationSec: number;
  slowDurationSec: number;
  repetitions: number;
  warmUpDurationSec: number;
  coolDownDurationSec: number;
  kind: 'built-in' | 'user';
  isFavorite: boolean;
  createdAt: number;
  updatedAt: number;
  lastUsedAt: number;
}

export function createBuiltInPresets(now: number = Date.now()): IntervalPreset[] {
  return [
    {
      id: 'builtin-tabata',
      name: 'Tabata 20/10 x8',
      fastDurationSec: 20,
      slowDurationSec: 10,
      repetitions: 8,
      warmUpDurationSec: 5,
      coolDownDurationSec: 5,
      kind: 'built-in',
      isFavorite: true,
      createdAt: now,
      updatedAt: now,
      lastUsedAt: 0
    },
    {
      id: 'builtin-cardio',
      name: 'Cardio 30/30 x10',
      fastDurationSec: 30,
      slowDurationSec: 30,
      repetitions: 10,
      warmUpDurationSec: 10,
      coolDownDurationSec: 10,
      kind: 'built-in',
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
      lastUsedAt: 0
    },
    {
      id: 'builtin-endurance',
      name: 'Endurance 45/15 x6',
      fastDurationSec: 45,
      slowDurationSec: 15,
      repetitions: 6,
      warmUpDurationSec: 10,
      coolDownDurationSec: 10,
      kind: 'built-in',
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
      lastUsedAt: 0
    }
  ];
}
