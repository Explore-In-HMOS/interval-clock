import { IntervalSessionResult } from '../common/models/IntervalSessionModels';
import { sessionHistoryRepository } from '../data/repositories/SessionHistoryRepository';

export type HistoryStatusFilter = 'all' | 'completed' | 'stopped';
export type HistorySourceFilter = 'all' | 'manual' | 'preset';

export interface HistoryFilters {
  status: HistoryStatusFilter;
  source: HistorySourceFilter;
  label: string;
}

export interface DailyAdherencePoint {
  dayKey: number;
  dayLabel: string;
  completionRate: number;
  sessionCount: number;
  completedCount: number;
}

export interface InsightsSummary {
  totalActiveMinutes: number;
  sessionsThisWeek: number;
  completionRate: number;
  currentStreakDays: number;
  favoritePresetLabel: string;
  trend: DailyAdherencePoint[];
}

export class HistoryInsightsService {
  loadSessions(): IntervalSessionResult[] {
    return sessionHistoryRepository.listAll();
  }

  getAvailableLabels(sessions: IntervalSessionResult[]): string[] {
    const labels: string[] = [];
    for (let index = 0; index < sessions.length; index++) {
      const label = this.getSessionLabel(sessions[index]);
      if (!this.contains(labels, label)) {
        labels.push(label);
      }
    }
    return labels;
  }

  applyFilters(sessions: IntervalSessionResult[], filters: HistoryFilters): IntervalSessionResult[] {
    const result: IntervalSessionResult[] = [];
    for (let index = 0; index < sessions.length; index++) {
      const session = sessions[index];
      if (filters.status !== 'all' && session.status !== filters.status) {
        continue;
      }
      if (filters.source !== 'all' && session.plan.source !== filters.source) {
        continue;
      }
      if (filters.label.length > 0 && this.getSessionLabel(session) !== filters.label) {
        continue;
      }
      result.push(session);
    }
    return result;
  }

  buildInsights(sessions: IntervalSessionResult[]): InsightsSummary {
    const now = Date.now();
    const weekStart = this.getStartOfDay(now - 6 * 86400000);
    let totalElapsedSec = 0;
    let completedCount = 0;
    let sessionsThisWeek = 0;
    const presetLabels: string[] = [];
    const presetCounts: number[] = [];

    for (let index = 0; index < sessions.length; index++) {
      const session = sessions[index];
      totalElapsedSec += Math.max(0, Math.floor(session.elapsedSec));
      if (session.completed) {
        completedCount += 1;
      }
      if (session.endedAt >= weekStart) {
        sessionsThisWeek += 1;
      }
      if (session.plan.source === 'preset') {
        const label = this.getSessionLabel(session);
        const existingIndex = this.indexOf(presetLabels, label);
        if (existingIndex >= 0) {
          presetCounts[existingIndex] += 1;
        } else {
          presetLabels.push(label);
          presetCounts.push(1);
        }
      }
    }

    const completionRate = sessions.length === 0 ? 0 : Math.round((completedCount * 100) / sessions.length);
    const favoritePresetLabel = this.getMaxLabel(presetLabels, presetCounts);

    return {
      totalActiveMinutes: Math.floor(totalElapsedSec / 60),
      sessionsThisWeek,
      completionRate,
      currentStreakDays: this.calculateCurrentStreakDays(sessions, now),
      favoritePresetLabel,
      trend: this.buildTrend(sessions, now)
    };
  }

  private buildTrend(sessions: IntervalSessionResult[], now: number): DailyAdherencePoint[] {
    const dayNames: string[] = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    const points: DailyAdherencePoint[] = [];
    const todayStart = this.getStartOfDay(now);
    const totals: number[] = [0, 0, 0, 0, 0, 0, 0];
    const completed: number[] = [0, 0, 0, 0, 0, 0, 0];

    for (let index = 0; index < sessions.length; index++) {
      const endedAt = sessions[index].endedAt;
      const dayOffset = Math.floor((todayStart - this.getStartOfDay(endedAt)) / 86400000);
      if (dayOffset < 0 || dayOffset > 6) {
        continue;
      }
      const bucket = 6 - dayOffset;
      totals[bucket] += 1;
      if (sessions[index].completed) {
        completed[bucket] += 1;
      }
    }

    for (let index = 0; index < 7; index++) {
      const dayTime = todayStart - (6 - index) * 86400000;
      const sessionCount = totals[index];
      const completedCount = completed[index];
      points.push({
        dayKey: dayTime,
        dayLabel: dayNames[new Date(dayTime).getDay()],
        completionRate: sessionCount === 0 ? 0 : Math.round((completedCount * 100) / sessionCount),
        sessionCount,
        completedCount
      });
    }
    return points;
  }

  private calculateCurrentStreakDays(sessions: IntervalSessionResult[], now: number): number {
    const completedDays: number[] = [];
    for (let index = 0; index < sessions.length; index++) {
      const session = sessions[index];
      if (!session.completed) {
        continue;
      }
      const dayStart = this.getStartOfDay(session.endedAt);
      if (!this.containsNumber(completedDays, dayStart)) {
        completedDays.push(dayStart);
      }
    }

    let streak = 0;
    let cursor = this.getStartOfDay(now);
    while (this.containsNumber(completedDays, cursor)) {
      streak += 1;
      cursor -= 86400000;
    }
    return streak;
  }

  private getStartOfDay(timeMs: number): number {
    const date = new Date(timeMs);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  private getSessionLabel(session: IntervalSessionResult): string {
    if (session.plan.label !== undefined && session.plan.label.trim().length > 0) {
      return session.plan.label.trim();
    }
    return session.plan.source === 'preset' ? 'Preset Session' : 'Custom Session';
  }

  private getMaxLabel(labels: string[], counts: number[]): string {
    if (labels.length === 0) {
      return 'None yet';
    }
    let maxLabel = labels[0];
    let maxCount = counts[0];
    for (let index = 1; index < labels.length; index++) {
      if (counts[index] > maxCount) {
        maxCount = counts[index];
        maxLabel = labels[index];
      }
    }
    return maxLabel;
  }

  private contains(values: string[], target: string): boolean {
    return this.indexOf(values, target) >= 0;
  }

  private indexOf(values: string[], target: string): number {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === target) {
        return index;
      }
    }
    return -1;
  }

  private containsNumber(values: number[], target: number): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === target) {
        return true;
      }
    }
    return false;
  }
}

export const historyInsightsService: HistoryInsightsService = new HistoryInsightsService();
