import { AppRoutes } from '../../common/routing/AppRoutes';
import { DailyAdherencePoint, InsightsSummary, historyInsightsService } from '../../viewmodel/HistoryInsightsService';

@Builder
export function InsightsPageBuilder() {
  InsightsPage();
}

@Component
export struct InsightsPage {
  @Consume('NavPathStack') private pageStack: NavPathStack;
  private getString(resource: Resource): string {
    try {
      return this.getUIContext().getHostContext()?.resourceManager?.getStringSync(resource.id) ?? '';
    } catch (_error) {
      return '';
    }
  }

  @State summary: InsightsSummary = {
    totalActiveMinutes: 0,
    sessionsThisWeek: 0,
    completionRate: 0,
    currentStreakDays: 0,
    favoritePresetLabel: 'None yet',
    trend: []
  };

  aboutToAppear(): void {
    this.summary = historyInsightsService.buildInsights(historyInsightsService.loadSessions());
  }

  @Builder
  private MetricCard(label: string, value: string, accent: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(10)
        .fontColor('#B8B8B8')
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(accent)
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8, left: 8, right: 8 })
    .borderRadius(10)
    .backgroundColor('#171717')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private TrendBar(point: DailyAdherencePoint) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width(16)
          .height(38)
          .borderRadius(8)
          .backgroundColor('#242424')

        Column()
          .width(16)
          .height(Math.max(3, Math.floor((point.completionRate * 38) / 100)))
          .borderRadius(8)
          .backgroundColor(point.sessionCount === 0 ? '#4D4D4D' : '#3E7BFA')
      }
      Text(point.dayLabel)
        .fontSize(9)
        .fontColor('#BCBCBC')
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 10 }) {
          Text($r('app.string.insights_title'))
            .width('100%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .padding({ left: 12, right: 12 })

          Row({ space: 6 }) {
            this.MetricCard(this.getString($r('app.string.insights_active_minutes')), `${this.summary.totalActiveMinutes}`, '#7EC8FF');
            this.MetricCard(this.getString($r('app.string.insights_this_week')), `${this.summary.sessionsThisWeek}`, '#B1F5A5');
          }
          .width('100%')

          Row({ space: 6 }) {
            this.MetricCard(this.getString($r('app.string.insights_completion')), `${this.summary.completionRate}%`, '#FFD27D');
            this.MetricCard(this.getString($r('app.string.insights_streak')), `${this.summary.currentStreakDays}d`, '#FFA98C');
          }
          .width('100%')

          Column({ space: 4 }) {
            Text($r('app.string.insights_favorite_preset'))
              .fontSize(10)
              .fontColor('#B8B8B8')
            Text(this.summary.favoritePresetLabel)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8, left: 9, right: 9 })
          .borderRadius(10)
          .backgroundColor('#171717')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 6 }) {
            Row() {
              Text($r('app.string.insights_seven_day_adherence'))
                .fontSize(12)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Medium)
              Text($r('app.string.insights_complete_total_hint'))
                .fontSize(9)
                .fontColor('#9D9D9D')
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Row({ space: 6 }) {
              ForEach(this.summary.trend, (point: DailyAdherencePoint) => {
                this.TrendBar(point);
              }, (point: DailyAdherencePoint) => point.dayKey.toString())
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            if (this.summary.trend.length > 0) {
              Row({ space: 6 }) {
                ForEach(this.summary.trend, (point: DailyAdherencePoint) => {
                  Text(`${point.completedCount}/${point.sessionCount}`)
                    .width(16)
                    .fontSize(8)
                    .fontColor('#8E8E8E')
                    .textAlign(TextAlign.Center)
                }, (point: DailyAdherencePoint) => `${point.dayKey}-txt`)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 9, left: 9, right: 9 })
          .borderRadius(10)
          .backgroundColor('#171717')
        }
        .width('100%')
        .padding({ top: 12, bottom: 20, left: 12, right: 12 })
        .backgroundColor('#0A0A0A')
      }
      .height('100%')
    }
    .title(AppRoutes.INSIGHTS)
    .hideTitleBar(true)
  }
}
