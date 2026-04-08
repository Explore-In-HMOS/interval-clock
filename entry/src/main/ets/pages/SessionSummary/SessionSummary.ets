import { AppRoutes, SessionSummaryRouteParam, createSessionSummaryRouteParam } from '../../common/routing/AppRoutes';

@Builder
export function SessionSummaryPageBuilder() {
  SessionSummaryPage();
}

@Component
export struct SessionSummaryPage {
  @Consume('NavPathStack') private pageStack: NavPathStack;
  params: SessionSummaryRouteParam = createSessionSummaryRouteParam({
    id: '',
    plan: {
      fastDurationSec: 10,
      slowDurationSec: 5,
      repetitions: 2,
      warmUpDurationSec: 5,
      coolDownDurationSec: 5,
      source: 'manual',
      label: 'Custom'
    },
    startedAt: 0,
    endedAt: 0,
    completedRounds: 0,
    totalRounds: 2,
    completed: false,
    status: 'stopped',
    totalDurationSec: 0,
    elapsedSec: 0,
    interruptionNote: undefined
  });

  private formatDuration(totalSec: number): string {
    const safe = Math.max(0, Math.floor(totalSec));
    const minutes = Math.floor(safe / 60);
    const seconds = safe % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private closeSummary(): void {
    this.pageStack.pop();
    this.pageStack.pop();
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 10 }) {
          Text(this.params.result.completed ? $r('app.string.session_summary_complete_title')
            : $r('app.string.session_summary_stopped_title'))
            .fontColor(this.params.result.completed ? '#53D487' : '#FF9A69')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)

          Column({ space: 6 }) {
            Text(this.params.result.plan.label ?? 'Custom Session')
              .fontColor(Color.White)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)

            Text(`Source ${this.params.result.plan.source === 'preset' ? 'Preset' : 'Manual'}`)
              .fontColor('#BBBBBB')
              .fontSize(11)
          }
          .width('100%')
          .padding(10)
          .borderRadius(12)
          .backgroundColor('#171717')

          Column({ space: 5 }) {
            Text(`Total Time ${this.formatDuration(this.params.result.elapsedSec)}`)
              .fontColor(Color.White)
              .fontSize(12)
            Text(`Planned Time ${this.formatDuration(this.params.result.totalDurationSec)}`)
              .fontColor('#D2D2D2')
              .fontSize(12)
            Text(`Rounds ${this.params.result.completedRounds}/${this.params.result.totalRounds}`)
              .fontColor('#D2D2D2')
              .fontSize(12)
            Text(`Status ${this.params.result.status === 'completed' ? 'Done' : 'Stopped'}`)
              .fontColor('#D2D2D2')
              .fontSize(12)

            if (this.params.result.interruptionNote !== undefined && this.params.result.interruptionNote.length > 0) {
              Text(this.params.result.interruptionNote)
                .fontColor('#FFBE96')
                .fontSize(11)
            }
          }
          .width('100%')
          .padding(10)
          .borderRadius(12)
          .backgroundColor('#171717')

          Button($r('app.string.common_done_button'))
            .width('100%')
            .height(34)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#2C4A86')
            .borderRadius(17)
            .onClick(() => this.closeSummary())
        }
        .width('100%')
        .padding({ top: 14, bottom: 18, left: 12, right: 12 })
        .backgroundColor('#0A0A0A')
      }
      .height('100%')
    }
    .hideTitleBar(true)
    .title(AppRoutes.SESSION_SUMMARY)
  }
}
