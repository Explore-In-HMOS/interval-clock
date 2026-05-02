import TimerConstants from '../common/constants/TimerConstants';

export class TimerService {
  private intervalID: number = 0;
  private startedAtMs: number = 0;
  private remainingMs: number = 0;
  private onTick: ((remainingMs: number) => void) | undefined = undefined;
  private onEnd: (() => void) | undefined = undefined;

  start(durationSec: number, onTick: (remainingMs: number) => void, onEnd: () => void): void {
    this.startWithRemainingMs(Math.max(0, Math.floor(durationSec * TimerConstants.SEC_TO_MS)), onTick, onEnd);
  }

  startWithRemainingMs(remainingMs: number, onTick: (remainingMs: number) => void, onEnd: () => void): void {
    this.clear();
    this.remainingMs = Math.max(0, Math.floor(remainingMs));
    this.onTick = onTick;
    this.onEnd = onEnd;
    this.resume();
  }

  preparePaused(remainingMs: number, onTick: (remainingMs: number) => void, onEnd: () => void): void {
    this.clear();
    this.remainingMs = Math.max(0, Math.floor(remainingMs));
    this.onTick = onTick;
    this.onEnd = onEnd;
    this.startedAtMs = 0;
    this.onTick(this.remainingMs);
  }

  pause(): number {
    this.refreshRemainingMs();
    if (this.intervalID !== 0) {
      clearInterval(this.intervalID);
      this.intervalID = 0;
    }
    this.startedAtMs = 0;
    return this.remainingMs;
  }

  resume(): void {
    if (this.remainingMs <= 0 || this.onTick === undefined || this.onEnd === undefined) {
      return;
    }
    if (this.intervalID !== 0) {
      return;
    }

    this.startedAtMs = Date.now();
    this.onTick(this.remainingMs);

    this.intervalID = setInterval(() => {
      this.refreshRemainingMs();
      if (this.onTick !== undefined) {
        this.onTick(this.remainingMs);
      }

      if (this.remainingMs <= 0) {
        const endHandler = this.onEnd;
        this.clear();
        if (endHandler !== undefined) {
          endHandler();
        }
      }
    }, TimerConstants.FPS_60);
  }

  addSeconds(seconds: number): number {
    const safeMs = Math.floor(seconds * TimerConstants.SEC_TO_MS);
    if (safeMs <= 0) {
      return this.remainingMs;
    }
    this.refreshRemainingMs();
    this.remainingMs += safeMs;
    this.startedAtMs = Date.now();
    if (this.onTick !== undefined) {
      this.onTick(this.remainingMs);
    }
    return this.remainingMs;
  }

  getRemainingMs(): number {
    this.refreshRemainingMs();
    return this.remainingMs;
  }

  clear(): void {
    if (this.intervalID !== 0) {
      clearInterval(this.intervalID);
      this.intervalID = 0;
    }
    this.remainingMs = 0;
    this.startedAtMs = 0;
    this.onTick = undefined;
    this.onEnd = undefined;
  }

  private refreshRemainingMs(): void {
    if (this.intervalID === 0 || this.startedAtMs <= 0) {
      return;
    }
    const elapsedMs = Date.now() - this.startedAtMs;
    this.remainingMs = Math.max(0, this.remainingMs - elapsedMs);
    this.startedAtMs = Date.now();
  }
}
