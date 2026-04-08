import { createBuiltInPresets, IntervalPreset } from '../../common/models/IntervalPreset';

const PRESET_STORAGE_KEY: string = 'intervalClock.presets.v1';
const PRESET_SCHEMA_VERSION: number = 1;

interface PresetEnvelope {
  version: number;
  presets: IntervalPreset[];
}

export interface PresetDraft {
  name: string;
  fastDurationSec: number;
  slowDurationSec: number;
  repetitions: number;
  warmUpDurationSec: number;
  coolDownDurationSec: number;
}

export class PresetRepository {
  initialize(): void {
    const rawValue = AppStorage.get<string>(PRESET_STORAGE_KEY);
    if (rawValue === undefined) {
      PersistentStorage.persistProp(PRESET_STORAGE_KEY, '');
    }

    const raw = AppStorage.get<string>(PRESET_STORAGE_KEY) ?? '';
    if (raw.length === 0) {
      this.savePresets(createBuiltInPresets());
    }
  }

  loadPresets(): IntervalPreset[] {
    const raw = AppStorage.get<string>(PRESET_STORAGE_KEY) ?? '';
    if (!raw || raw.length === 0) {
      return createBuiltInPresets();
    }

    try {
      const parsed = JSON.parse(raw) as Object;
      if (this.isEnvelope(parsed)) {
        const envelope = parsed as PresetEnvelope;
        if (!this.isPresetList(envelope.presets)) {
          return createBuiltInPresets();
        }
        if (envelope.version === PRESET_SCHEMA_VERSION) {
          return envelope.presets;
        }
        return this.migrate(envelope);
      }

      if (this.isPresetList(parsed)) {
        return parsed as IntervalPreset[];
      }
      if (this.isLegacyPresetList(parsed)) {
        return this.upgradeLegacyPresets(parsed as Object[]);
      }
      return createBuiltInPresets();
    } catch (_error) {
      return createBuiltInPresets();
    }
  }

  savePresets(presets: IntervalPreset[]): void {
    const envelope: PresetEnvelope = {
      version: PRESET_SCHEMA_VERSION,
      presets
    };
    AppStorage.set<string>(PRESET_STORAGE_KEY, JSON.stringify(envelope));
  }

  getFavoritePresets(limit: number = 3): IntervalPreset[] {
    return this.loadPresets().filter((preset) => preset.isFavorite).slice(0, limit);
  }

  getBuiltInPresets(): IntervalPreset[] {
    return this.loadPresets().filter((preset) => preset.kind === 'built-in');
  }

  getUserPresets(): IntervalPreset[] {
    return this.loadPresets()
      .filter((preset) => preset.kind === 'user')
      .sort((a, b) => b.updatedAt - a.updatedAt);
  }

  getPresetById(presetId: string): IntervalPreset | undefined {
    return this.loadPresets().find((preset) => preset.id === presetId);
  }

  getRecentPresets(limit: number = 3): IntervalPreset[] {
    return this.loadPresets()
      .filter((preset) => preset.lastUsedAt > 0)
      .sort((a, b) => b.lastUsedAt - a.lastUsedAt)
      .slice(0, limit);
  }

  markPresetUsed(presetId: string): IntervalPreset | undefined {
    const presets = this.loadPresets();
    const now = Date.now();
    let selected: IntervalPreset | undefined = undefined;

    const updated = presets.map((preset) => {
      if (preset.id === presetId) {
        selected = {
          id: preset.id,
          name: preset.name,
          fastDurationSec: preset.fastDurationSec,
          slowDurationSec: preset.slowDurationSec,
          repetitions: preset.repetitions,
          warmUpDurationSec: preset.warmUpDurationSec,
          coolDownDurationSec: preset.coolDownDurationSec,
          kind: preset.kind,
          isFavorite: preset.isFavorite,
          createdAt: preset.createdAt,
          updatedAt: now,
          lastUsedAt: now
        };
        return selected;
      }
      return preset;
    });

    this.savePresets(updated);
    return selected;
  }

  toggleFavorite(presetId: string): IntervalPreset | undefined {
    const presets = this.loadPresets();
    let changed: IntervalPreset | undefined = undefined;

    const updated = presets.map((preset) => {
      if (preset.id !== presetId) {
        return preset;
      }
      const now = Date.now();
      changed = {
        id: preset.id,
        name: preset.name,
        fastDurationSec: preset.fastDurationSec,
        slowDurationSec: preset.slowDurationSec,
        repetitions: preset.repetitions,
        warmUpDurationSec: preset.warmUpDurationSec,
        coolDownDurationSec: preset.coolDownDurationSec,
        kind: preset.kind,
        isFavorite: !preset.isFavorite,
        createdAt: preset.createdAt,
        updatedAt: now,
        lastUsedAt: preset.lastUsedAt
      };
      return changed;
    });

    if (changed) {
      this.savePresets(updated);
    }
    return changed;
  }

  createUserPreset(draft: PresetDraft): IntervalPreset {
    const presets = this.loadPresets();
    const now = Date.now();
    const preset: IntervalPreset = {
      id: `user-${now}-${Math.floor(Math.random() * 100000)}`,
      name: draft.name,
      fastDurationSec: draft.fastDurationSec,
      slowDurationSec: draft.slowDurationSec,
      repetitions: draft.repetitions,
      warmUpDurationSec: draft.warmUpDurationSec,
      coolDownDurationSec: draft.coolDownDurationSec,
      kind: 'user',
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
      lastUsedAt: 0
    };

    this.savePresets([...presets, preset]);
    return preset;
  }

  updatePreset(presetId: string, draft: PresetDraft): IntervalPreset | undefined {
    const presets = this.loadPresets();
    let changed: IntervalPreset | undefined = undefined;
    const now = Date.now();

    const updated = presets.map((preset) => {
      if (preset.id !== presetId) {
        return preset;
      }
      if (preset.kind !== 'user') {
        return preset;
      }
      changed = {
        id: preset.id,
        name: draft.name,
        fastDurationSec: draft.fastDurationSec,
        slowDurationSec: draft.slowDurationSec,
        repetitions: draft.repetitions,
        warmUpDurationSec: draft.warmUpDurationSec,
        coolDownDurationSec: draft.coolDownDurationSec,
        kind: preset.kind,
        isFavorite: preset.isFavorite,
        createdAt: preset.createdAt,
        updatedAt: now,
        lastUsedAt: preset.lastUsedAt
      };
      return changed;
    });

    if (changed) {
      this.savePresets(updated);
    }
    return changed;
  }

  deleteUserPreset(presetId: string): boolean {
    const presets = this.loadPresets();
    const kept = presets.filter((preset) => !(preset.id === presetId && preset.kind === 'user'));
    if (kept.length === presets.length) {
      return false;
    }
    this.savePresets(kept);
    return true;
  }

  private migrate(envelope: PresetEnvelope): IntervalPreset[] {
    if (this.isPresetList(envelope.presets)) {
      return envelope.presets;
    }
    if (this.isLegacyPresetList(envelope.presets)) {
      return this.upgradeLegacyPresets(envelope.presets as Object[]);
    }
    return createBuiltInPresets();
  }

  private isPresetList(value: Object): boolean {
    if (!Array.isArray(value)) {
      return false;
    }
    return value.every((preset: Object) => this.isPresetRecord(preset));
  }

  private isLegacyPresetList(value: Object): boolean {
    if (!Array.isArray(value)) {
      return false;
    }
    return value.every((preset: Object) => this.isLegacyPresetRecord(preset));
  }

  private isEnvelope(value: Object): boolean {
    return !!((value as PresetEnvelope).presets);
  }

  private isPresetRecord(value: Object): boolean {
    if (value === null || typeof value !== 'object') {
      return false;
    }

    const preset = value as IntervalPreset;
    return typeof preset.id === 'string'
      && typeof preset.name === 'string'
      && typeof preset.fastDurationSec === 'number'
      && Number.isFinite(preset.fastDurationSec)
      && typeof preset.slowDurationSec === 'number'
      && Number.isFinite(preset.slowDurationSec)
      && typeof preset.repetitions === 'number'
      && Number.isFinite(preset.repetitions)
      && typeof preset.warmUpDurationSec === 'number'
      && Number.isFinite(preset.warmUpDurationSec)
      && typeof preset.coolDownDurationSec === 'number'
      && Number.isFinite(preset.coolDownDurationSec)
      && (preset.kind === 'built-in' || preset.kind === 'user')
      && typeof preset.isFavorite === 'boolean'
      && typeof preset.createdAt === 'number'
      && Number.isFinite(preset.createdAt)
      && typeof preset.updatedAt === 'number'
      && Number.isFinite(preset.updatedAt)
      && typeof preset.lastUsedAt === 'number'
      && Number.isFinite(preset.lastUsedAt);
  }

  private isLegacyPresetRecord(value: Object): boolean {
    if (value === null || typeof value !== 'object') {
      return false;
    }
    const preset = value as IntervalPreset;
    return typeof preset.id === 'string'
      && typeof preset.name === 'string'
      && typeof preset.fastDurationSec === 'number'
      && Number.isFinite(preset.fastDurationSec)
      && typeof preset.slowDurationSec === 'number'
      && Number.isFinite(preset.slowDurationSec)
      && typeof preset.repetitions === 'number'
      && Number.isFinite(preset.repetitions)
      && typeof preset.isFavorite === 'boolean'
      && typeof preset.createdAt === 'number'
      && Number.isFinite(preset.createdAt)
      && typeof preset.updatedAt === 'number'
      && Number.isFinite(preset.updatedAt)
      && typeof preset.lastUsedAt === 'number'
      && Number.isFinite(preset.lastUsedAt);
  }

  private upgradeLegacyPresets(value: Object[]): IntervalPreset[] {
    return value.map((item: Object): IntervalPreset => {
      const legacyPreset = item as IntervalPreset;
      const inferredKind: 'built-in' | 'user' = legacyPreset.id.startsWith('builtin-') ? 'built-in' : 'user';
      const upgraded: IntervalPreset = {
        id: legacyPreset.id,
        name: legacyPreset.name,
        fastDurationSec: legacyPreset.fastDurationSec,
        slowDurationSec: legacyPreset.slowDurationSec,
        repetitions: legacyPreset.repetitions,
        warmUpDurationSec: 5,
        coolDownDurationSec: 5,
        kind: inferredKind,
        isFavorite: legacyPreset.isFavorite,
        createdAt: legacyPreset.createdAt,
        updatedAt: legacyPreset.updatedAt,
        lastUsedAt: legacyPreset.lastUsedAt
      };
      return upgraded;
    });
  }
}

export const presetRepository: PresetRepository = new PresetRepository();
