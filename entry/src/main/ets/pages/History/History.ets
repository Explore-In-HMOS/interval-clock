import { IntervalSessionResult } from '../../common/models/IntervalSessionModels';
import { AppRoutes } from '../../common/routing/AppRoutes';
import { sessionHistoryRepository } from '../../data/repositories/SessionHistoryRepository';
import {
  HistorySourceFilter,
  HistoryStatusFilter,
  historyInsightsService
} from '../../viewmodel/HistoryInsightsService';

@Builder
export function HistoryPageBuilder() {
  HistoryPage();
}

@Component
export struct HistoryPage {
  @Consume('NavPathStack') private pageStack: NavPathStack;
  private getString(resource: Resource): string {
    try {
      return this.getUIContext().getHostContext()?.resourceManager?.getStringSync(resource.id) ?? '';
    } catch (_error) {
      return '';
    }
  }

  @State sessions: IntervalSessionResult[] = [];
  @State filteredSessions: IntervalSessionResult[] = [];
  @State labels: string[] = [];
  @State statusFilter: HistoryStatusFilter = 'all';
  @State sourceFilter: HistorySourceFilter = 'all';
  @State labelFilter: string = '';
  @State expandedSessionId: string = '';

  aboutToAppear(): void {
    sessionHistoryRepository.initialize();
    this.reloadData();
  }

  private reloadData(): void {
    this.sessions = historyInsightsService.loadSessions();
    this.labels = historyInsightsService.getAvailableLabels(this.sessions);
    this.applyFilters();
  }

  private applyFilters(): void {
    this.filteredSessions = historyInsightsService.applyFilters(this.sessions, {
      status: this.statusFilter,
      source: this.sourceFilter,
      label: this.labelFilter
    });
    if (this.expandedSessionId.length > 0 && !this.containsSession(this.filteredSessions, this.expandedSessionId)) {
      this.expandedSessionId = '';
    }
  }

  private containsSession(values: IntervalSessionResult[], sessionId: string): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index].id === sessionId) {
        return true;
      }
    }
    return false;
  }

  private toggleExpanded(sessionId: string): void {
    this.expandedSessionId = this.expandedSessionId === sessionId ? '' : sessionId;
  }

  private formatDuration(totalSec: number): string {
    const safe = Math.max(0, Math.floor(totalSec));
    const minutes = Math.floor(safe / 60);
    const seconds = safe % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private formatTime(timeMs: number): string {
    const date = new Date(timeMs);
    const hour = date.getHours();
    const minute = date.getMinutes();
    return `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`;
  }

  private formatDate(timeMs: number): string {
    const date = new Date(timeMs);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    return `${month}/${day}`;
  }

  private getSessionLabel(session: IntervalSessionResult): string {
    if (session.plan.label !== undefined && session.plan.label.trim().length > 0) {
      return session.plan.label.trim();
    }
    return session.plan.source === 'preset' ? this.getString($r('app.string.history_preset_session'))
      : this.getString($r('app.string.history_custom_session'));
  }

  private getSourceLabel(source: 'manual' | 'preset'): string {
    return source === 'preset' ? this.getString($r('app.string.history_source_preset'))
      : this.getString($r('app.string.history_source_manual'));
  }

  @Builder
  private FilterChip(text: string, active: boolean, onClick: () => void) {
    Button(text)
      .height(26)
      .fontSize(10)
      .fontColor(active ? Color.White : '#D0D0D0')
      .backgroundColor(active ? '#2C4A86' : '#303030')
      .borderRadius(13)
      .onClick(onClick)
  }

  @Builder
  private SessionCard(session: IntervalSessionResult) {
    Column({ space: 5 }) {
      Row() {
        Text(this.getSessionLabel(session))
          .layoutWeight(1)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(session.status === 'completed' ? $r('app.string.history_status_done') : $r('app.string.history_status_stopped'))
          .fontSize(10)
          .fontColor(session.status === 'completed' ? '#79D79B' : '#FFAE84')
      }
      .width('100%')

      Row() {
        Text(`${this.formatDate(session.endedAt)} ${this.formatTime(session.endedAt)}`)
          .fontSize(10)
          .fontColor('#B7B7B7')
          .layoutWeight(1)
        Text(`${session.completedRounds}/${session.totalRounds} ${this.getString($r('app.string.history_rounds_suffix'))}`)
          .fontSize(10)
          .fontColor('#B7B7B7')
      }
      .width('100%')

      Text(`${this.getString($r('app.string.history_elapsed_prefix'))} ${this.formatDuration(session.elapsedSec)} • ${this.getString($r('app.string.history_planned_prefix'))} ${this.formatDuration(session.totalDurationSec)}`)
        .fontSize(10)
        .fontColor('#C8C8C8')

      if (this.expandedSessionId === session.id) {
        Column({ space: 3 }) {
          Text(`${this.getString($r('app.string.history_source_prefix'))} ${this.getSourceLabel(session.plan.source)}`)
            .fontSize(10)
            .fontColor('#D7D7D7')
          Text(`${this.getString($r('app.string.history_plan_prefix'))} ${this.getString($r('app.string.presets_plan_warm_up_prefix'))} ${session.plan.warmUpDurationSec ?? 0}s • ${session.plan.fastDurationSec}s / ${session.plan.slowDurationSec}s x${session.plan.repetitions} • ${this.getString($r('app.string.presets_plan_cool_down_prefix'))} ${session.plan.coolDownDurationSec ?? 0}s`)
            .fontSize(10)
            .fontColor('#D7D7D7')
          Text(`${this.getString($r('app.string.history_started_prefix'))} ${this.formatDate(session.startedAt)} ${this.formatTime(session.startedAt)}`)
            .fontSize(10)
            .fontColor('#C8C8C8')
          if (session.interruptionNote !== undefined && session.interruptionNote.length > 0) {
            Text(session.interruptionNote)
              .fontSize(10)
              .fontColor('#FFB28A')
          }
        }
        .width('100%')
        .padding({ top: 6 })
      }

      Button(this.expandedSessionId === session.id ? $r('app.string.history_hide_details') : $r('app.string.history_view_details'))
        .width('100%')
        .height(26)
        .fontSize(10)
        .fontColor(Color.White)
        .backgroundColor('#2F2F2F')
        .borderRadius(13)
        .onClick(() => this.toggleExpanded(session.id))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 8, right: 8 })
    .borderRadius(12)
    .backgroundColor('#171717')
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 10 }) {
          Text($r('app.string.history_title'))
            .width('100%')
            .fontColor(Color.White)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
            .padding({ left: 12, right: 12 })

          Row() {
            Button($r('app.string.dashboard_action_insights'))
              .width(92)
              .height(26)
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor('#2C4A86')
              .borderRadius(13)
              .onClick(() => this.pageStack.pushPathByName(AppRoutes.INSIGHTS, undefined))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Column({ space: 5 }) {
            Text($r('app.string.history_filter_status'))
              .fontSize(10)
              .fontColor('#BBBBBB')
            Row({ space: 6 }) {
              this.FilterChip(this.getString($r('app.string.history_filter_all')), this.statusFilter === 'all', () => {
                this.statusFilter = 'all';
                this.applyFilters();
              });
              this.FilterChip(this.getString($r('app.string.history_status_done')), this.statusFilter === 'completed', () => {
                this.statusFilter = 'completed';
                this.applyFilters();
              });
              this.FilterChip(this.getString($r('app.string.history_status_stopped')), this.statusFilter === 'stopped', () => {
                this.statusFilter = 'stopped';
                this.applyFilters();
              });
            }
            .width('100%')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8, left: 8, right: 8 })
          .borderRadius(10)
          .backgroundColor('#141414')

          Column({ space: 5 }) {
            Text($r('app.string.history_filter_source'))
              .fontSize(10)
              .fontColor('#BBBBBB')
            Row({ space: 6 }) {
              this.FilterChip(this.getString($r('app.string.history_filter_all')), this.sourceFilter === 'all', () => {
                this.sourceFilter = 'all';
                this.applyFilters();
              });
              this.FilterChip(this.getString($r('app.string.history_source_preset')), this.sourceFilter === 'preset', () => {
                this.sourceFilter = 'preset';
                this.applyFilters();
              });
              this.FilterChip(this.getString($r('app.string.history_source_manual')), this.sourceFilter === 'manual', () => {
                this.sourceFilter = 'manual';
                this.applyFilters();
              });
            }
            .width('100%')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8, left: 8, right: 8 })
          .borderRadius(10)
          .backgroundColor('#141414')

          Column({ space: 5 }) {
            Text($r('app.string.history_filter_label'))
              .fontSize(10)
              .fontColor('#BBBBBB')

            if (this.labels.length === 0) {
              Text($r('app.string.history_no_labels'))
                .fontSize(10)
                .fontColor('#8F8F8F')
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                this.FilterChip(this.getString($r('app.string.history_all_labels')), this.labelFilter.length === 0, () => {
                  this.labelFilter = '';
                  this.applyFilters();
                });

                ForEach(this.labels, (label: string) => {
                  this.FilterChip(label, this.labelFilter === label, () => {
                    this.labelFilter = label;
                    this.applyFilters();
                  });
                }, (label: string) => label)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 8, left: 8, right: 8 })
          .borderRadius(10)
          .backgroundColor('#141414')

          if (this.filteredSessions.length === 0) {
            Column({ space: 4 }) {
              Text($r('app.string.history_empty_title'))
                .fontSize(11)
                .fontColor('#BDBDBD')
                .textAlign(TextAlign.Center)
              Text($r('app.string.history_empty_subtitle'))
                .fontSize(10)
                .fontColor('#8E8E8E')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ top: 12, bottom: 12, left: 8, right: 8 })
            .borderRadius(10)
            .backgroundColor('#171717')
          } else {
            ForEach(this.filteredSessions, (session: IntervalSessionResult) => {
              this.SessionCard(session);
            }, (session: IntervalSessionResult) => session.id)
          }
        }
        .width('100%')
        .padding({ top: 12, left: 12, right: 12, bottom: 20 })
        .backgroundColor('#0A0A0A')
      }
      .height('100%')
    }
    .title(AppRoutes.HISTORY)
    .hideTitleBar(true)
  }
}
