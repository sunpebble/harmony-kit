import {
  SunButton,
  SunButtonRole,
  SunCard,
  SunColor,
  SunSpacing,
  SunToolShell,
  SunType
} from 'sunpebble_ui'
import { appProfile } from '../AppProfile'

interface SleepNight {
  day: string
  hours: number
  bedtime: string
}

PersistentStorage.persistProp('sleeptab.goalHours.v1', 8)
PersistentStorage.persistProp('sleeptab.rangeNights.v1', 7)
PersistentStorage.persistProp('sleeptab.nights.v1', '')

@Entry
@Component
struct Index {
  @StorageLink('sleeptab.goalHours.v1') private goalHours: number = 8
  @StorageLink('sleeptab.rangeNights.v1') private rangeNights: number = 7
  @StorageLink('sleeptab.nights.v1') private nightsJson: string = ''
  @State private nights: SleepNight[] = []

  aboutToAppear(): void {
    this.loadNights()
  }

  private defaultNights(): SleepNight[] {
    return [
    { day: 'MON', hours: 6.7, bedtime: '23:40' },
    { day: 'TUE', hours: 7.2, bedtime: '23:20' },
    { day: 'WED', hours: 6.3, bedtime: '00:10' },
    { day: 'THU', hours: 8.1, bedtime: '22:55' },
    { day: 'FRI', hours: 7.4, bedtime: '23:35' },
    { day: 'SAT', hours: 8.8, bedtime: '00:30' },
    { day: 'SUN', hours: 7.1, bedtime: '23:50' }
    ]
  }

  private loadNights(): void {
    if (this.nightsJson.length === 0) {
      this.nights = this.defaultNights()
      this.saveNights()
      return
    }
    try {
      const parsed = JSON.parse(this.nightsJson) as SleepNight[]
      if (parsed.length > 0) {
        this.nights = parsed
      }
    } catch (_error) {
      this.nights = this.defaultNights()
      this.saveNights()
    }
  }

  private saveNights(): void {
    this.nightsJson = JSON.stringify(this.nights)
  }

  private addNight(): void {
    const labels: string[] = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
    const index = this.nights.length % labels.length
    const hours = [7.6, 6.9, 8.2, 7.3][this.nights.length % 4]
    this.nights = [...this.nights, { day: labels[index], hours, bedtime: '23:30' }]
    this.saveNights()
  }

  private shownNights(): SleepNight[] {
    return this.nights.slice(Math.max(0, this.nights.length - this.rangeNights))
  }

  private recentNights(count: number): SleepNight[] {
    return this.nights.slice(Math.max(0, this.nights.length - count))
  }

  private debtHours(): number {
    return this.recentNights(14).reduce((total: number, night: SleepNight) => {
      return total + Math.max(0, this.goalHours - night.hours)
    }, 0)
  }

  private averageHours(count: number): number {
    const list = this.recentNights(count)
    if (list.length === 0) {
      return 0
    }
    return list.reduce((total: number, night: SleepNight) => total + night.hours, 0) / list.length
  }

  private bestHours(): number {
    return this.shownNights().reduce((best: number, night: SleepNight) => Math.max(best, night.hours), 0)
  }

  private roughestHours(): number {
    return this.shownNights().reduce((worst: number, night: SleepNight) => Math.min(worst, night.hours), 24)
  }

  private hoursText(hours: number): string {
    const total = Math.max(0, Math.round(hours * 60))
    return `${Math.floor(total / 60)}h ${this.pad(total % 60)}m`
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private setRange(value: number): void {
    this.rangeNights = value
  }

  private adjustGoal(delta: number): void {
    this.goalHours = Math.max(5, Math.min(10, this.goalHours + delta))
  }

  @Builder
  private rangeButton(label: string, value: number) {
    Button(label)
      .height(34)
      .padding({ left: 14, right: 14 })
      .borderRadius(999)
      .backgroundColor(this.rangeNights === value ? '#9B8CFF' : '#24283A')
      .fontColor(this.rangeNights === value ? SunColor.night : '#BFB8AA')
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .onClick(() => this.setRange(value))
  }

  @Builder
  private debtCard() {
    Column({ space: SunSpacing.sm }) {
      if (this.debtHours() <= 0) {
        Text('ALL CAUGHT UP')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#9B8CFF')
      } else {
        Text(this.hoursText(this.debtHours()))
          .fontSize(46)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.cream)
      }

      Text(this.debtHours() <= 0 ? 'NO SLEEP DEBT · LAST 14 NIGHTS' : 'SLEEP DEBT · LAST 14 NIGHTS')
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1.5)
        .fontColor('#BFB8AA')
    }
    .width('100%')
    .padding({ top: 30, bottom: 30 })
    .backgroundColor('#24283A')
    .borderRadius(20)
  }

  @Builder
  private chartCard() {
    SunCard() {
      Column({ space: SunSpacing.lg }) {
        Row({ space: SunSpacing.sm }) {
          this.rangeButton('7N', 7)
          this.rangeButton('30N', 30)
          this.rangeButton('90N', 90)
        }

        Row({ space: SunSpacing.sm }) {
          ForEach(this.shownNights(), (night: SleepNight) => {
            Column({ space: SunSpacing.xs }) {
              Blank()
                .width('100%')
                .height(34 + Math.min(118, Math.round(night.hours / this.goalHours * 92)))
                .backgroundColor(night.hours >= this.goalHours ? '#9B8CFF' : '#655CA8')
                .borderRadius(5)

              Text(night.day)
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BFB8AA')
            }
            .layoutWeight(1)
            .height(168)
            .justifyContent(FlexAlign.End)
          }, (night: SleepNight) => `${night.day}-${night.hours}-${night.bedtime}`)
        }
        .height(176)
      }
    }
  }

  @Builder
  private weekCard() {
    SunCard() {
      Row() {
        Column({ space: SunSpacing.xs }) {
          Text('AVG · LAST 7 NIGHTS')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .fontColor(SunColor.pebble)
          Text(this.hoursText(this.averageHours(7)))
            .fontSize(SunType.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(SunColor.ink)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: SunSpacing.xs }) {
          Text('VS GOAL')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .fontColor(SunColor.pebble)
          Text((this.averageHours(7) >= this.goalHours ? '+' : '-') + this.hoursText(Math.abs(this.averageHours(7) - this.goalHours)))
            .fontSize(SunType.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.averageHours(7) >= this.goalHours ? '#9B8CFF' : SunColor.ink)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
    }
  }

  @Builder
  private insightsCard() {
    SunCard() {
      Column({ space: SunSpacing.md }) {
        Text(`INSIGHTS · LAST ${this.shownNights().length} NIGHTS`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
          .fontColor(SunColor.pebble)

        this.insightRow('BEST NIGHT', this.hoursText(this.bestHours()))
        this.insightRow('ROUGHEST', this.hoursText(this.roughestHours()))
        this.insightRow('AVG BEDTIME', this.shownNights()[this.shownNights().length - 1].bedtime)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private insightRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)
        .fontColor(SunColor.pebble)
      Blank().layoutWeight(1)
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(SunColor.ink)
    }
    .width('100%')
  }

  @Builder
  private goalCard() {
    SunCard() {
      Row({ space: SunSpacing.md }) {
        Text('SLEEP NEED')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.pebble)
          .layoutWeight(1)

        Button('-')
          .width(38)
          .height(38)
          .borderRadius(999)
          .backgroundColor('#24283A')
          .fontColor(SunColor.cream)
          .onClick(() => this.adjustGoal(-0.25))

        Text(this.hoursText(this.goalHours))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.ink)

        Button('+')
          .width(38)
          .height(38)
          .borderRadius(999)
          .backgroundColor('#9B8CFF')
          .fontColor(SunColor.night)
          .onClick(() => this.adjustGoal(0.25))
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      SunToolShell({
        manifest: appProfile,
        onPrimaryAction: () => this.addNight()
      }) {
        Scroll() {
          Column({ space: SunSpacing.lg }) {
            this.debtCard()
            this.chartCard()
            this.weekCard()
            this.insightsCard()
            this.goalCard()

            SunButton({
              label: 'Add tonight',
              role: SunButtonRole.Secondary,
              action: () => this.addNight()
            })
          }
          .width('100%')
          .padding({ bottom: SunSpacing.xl })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
