import { vibrator } from '@kit.SensorServiceKit';
import { AppSettings } from '../common/models/AppSettings';

type HapticCueType = 'phase-change' | 'pause' | 'resume' | 'countdown' | 'complete';

export class HapticCoachService {
  triggerCue(cue: HapticCueType, settings: AppSettings): void {
    if (!settings.hapticsEnabled) {
      return;
    }

    const durationMs = this.resolveDurationMs(cue, settings.hapticIntensity);
    if (durationMs <= 0) {
      return;
    }

    try {
      vibrator.startVibration({
        type: 'time',
        duration: durationMs
      }, {
        usage: 'notification'
      }).catch((_error: Error) => {
      });
    } catch (_error) {
    }
  }

  private resolveDurationMs(cue: HapticCueType, intensity: 'low' | 'medium' | 'high'): number {
    if (cue === 'complete') {
      return this.scaleDuration(260, intensity);
    }
    if (cue === 'phase-change') {
      return this.scaleDuration(120, intensity);
    }
    if (cue === 'countdown') {
      return this.scaleDuration(80, intensity);
    }
    if (cue === 'pause') {
      return this.scaleDuration(90, intensity);
    }
    return this.scaleDuration(70, intensity);
  }

  private scaleDuration(baseMs: number, intensity: 'low' | 'medium' | 'high'): number {
    if (intensity === 'low') {
      return Math.floor(baseMs * 0.75);
    }
    if (intensity === 'high') {
      return Math.floor(baseMs * 1.3);
    }
    return baseMs;
  }
}

export const hapticCoachService: HapticCoachService = new HapticCoachService();
