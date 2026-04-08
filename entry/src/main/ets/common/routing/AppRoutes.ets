import { IntervalSessionPlan, IntervalSessionResult } from '../models/IntervalSessionModels';

export class AppRoutes {
  static readonly TIMER: string = 'TimerPage';
  static readonly PRESETS: string = 'PresetsPage';
  static readonly HISTORY: string = 'HistoryPage';
  static readonly INSIGHTS: string = 'InsightsPage';
  static readonly SETTINGS: string = 'SettingsPage';
  static readonly SESSION_SUMMARY: string = 'SessionSummaryPage';
}

export interface TimerRouteParam {
  plan: IntervalSessionPlan;
  launchToken: string;
}

export function createTimerRouteParam(plan: IntervalSessionPlan): TimerRouteParam {
  return {
    plan,
    launchToken: `launch-${Date.now()}-${Math.floor(Math.random() * 1000000)}`
  };
}

export interface SessionSummaryRouteParam {
  result: IntervalSessionResult;
}

export function createSessionSummaryRouteParam(result: IntervalSessionResult): SessionSummaryRouteParam {
  return { result };
}
