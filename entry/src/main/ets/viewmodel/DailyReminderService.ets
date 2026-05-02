import { AppSettings } from '../common/models/AppSettings';

export interface ReminderSyncResult {
  supported: boolean;
  state: 'off' | 'scheduled-fallback';
  timeLabel: string;
}

export class DailyReminderService {
  syncDailyReminder(settings: AppSettings): ReminderSyncResult {
    const formattedTime = this.formatTime(settings.dailyReminderHour, settings.dailyReminderMinute);
    if (!settings.dailyReminderEnabled) {
      return {
        supported: false,
        state: 'off',
        timeLabel: formattedTime
      };
    }

    // Daily scheduling integration can be swapped to a platform API once available in this target.
    return {
      supported: false,
      state: 'scheduled-fallback',
      timeLabel: formattedTime
    };
  }

  private formatTime(hour: number, minute: number): string {
    const hourText = hour < 10 ? `0${hour}` : `${hour}`;
    const minuteText = minute < 10 ? `0${minute}` : `${minute}`;
    return `${hourText}:${minuteText}`;
  }
}

export const dailyReminderService: DailyReminderService = new DailyReminderService();
