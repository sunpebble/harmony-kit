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
  date: string
  day: string
  hours: number
  bedtime: string
}

PersistentStorage.persistProp('sleeptab.goalHours.v1', 8)
PersistentStorage.persistProp('sleeptab.rangeNights.v1', 7)
PersistentStorage.persistProp('sleeptab.draftHours.v1', 7.5)
PersistentStorage.persistProp('sleeptab.draftBedtime.v1', '23:30')
PersistentStorage.persistProp('sleeptab.nights.v1', '')
PersistentStorage.persistProp('sleeptab.proUnlocked.v1', false)

@Entry
@Component
struct Index {
  @StorageLink('sleeptab.goalHours.v1') private goalHours: number = 8
  @StorageLink('sleeptab.rangeNights.v1') private rangeNights: number = 7
  @StorageLink('sleeptab.draftHours.v1') private draftHours: number = 7.5
  @StorageLink('sleeptab.draftBedtime.v1') private draftBedtime: string = '23:30'
  @StorageLink('sleeptab.nights.v1') private nightsJson: string = ''
  @StorageLink('sleeptab.proUnlocked.v1') private proUnlocked: boolean = false
  @State private nights: SleepNight[] = []

  aboutToAppear(): void {
    this.loadNights()
  }

  private normalizeNight(night: SleepNight, index: number, total: number): SleepNight {
    const fallback = new Date()
    fallback.setDate(fallback.getDate() - (total - index))
    const date = night.date ? night.date : this.dateKey(fallback)
    return {
      date,
      day: this.dayLabel(this.dateFromKey(date)),
      hours: night.hours,
      bedtime: night.bedtime
    }
  }

  private sortNights(nights: SleepNight[]): SleepNight[] {
    return [...nights].sort((a: SleepNight, b: SleepNight) => a.date.localeCompare(b.date))
  }

  private dateKey(date: Date): string {
    return `${date.getFullYear()}-${this.pad(date.getMonth() + 1)}-${this.pad(date.getDate())}`
  }

  private dateFromKey(key: string): Date {
    const parts = key.split('-')
    if (parts.length !== 3) {
      return new Date()
    }
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
  }

  private dayLabel(date: Date): string {
    const days: string[] = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
    return days[date.getDay()]
  }

  private adjustDraftHours(delta: number): void {
    this.draftHours = Math.max(0.5, Math.min(14, Math.round((this.draftHours + delta) * 4) / 4))
  }

  private addNight(): void {
    const today = new Date()
    const date = this.dateKey(today)
    const night: SleepNight = {
      date,
      day: this.dayLabel(today),
      hours: this.draftHours,
      bedtime: this.draftBedtime
    }
    this.nights = this.sortNights([
      ...this.nights.filter((item: SleepNight) => item.date !== date),
      night
    ])
    this.saveNights()
  }

  @Builder
  private bedtimeButton(time: string) {
    Button(time)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.draftBedtime === time ? '#9B8CFF' : '#24283A')
      .fontColor(this.draftBedtime === time ? SunColor.night : '#BFB8AA')
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .onClick(() => this.draftBedtime = time)
  }

  @Builder
  private manualEntryCard() {
    SunCard() {
      Column({ space: SunSpacing.md }) {
        Row({ space: SunSpacing.md }) {
          Column({ space: SunSpacing.xs }) {
            Text('TONIGHT')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1.5)
              .fontColor(SunColor.pebble)
            Text(`${this.hoursText(this.draftHours)} · ${this.draftBedtime}`)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.ink)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('-15m')
            .height(38)
            .padding({ left: 12, right: 12 })
            .borderRadius(999)
            .backgroundColor('#24283A')
            .fontColor(SunColor.cream)
            .fontSize(12)
            .onClick(() => this.adjustDraftHours(-0.25))

          Button('+15m')
            .height(38)
            .padding({ left: 12, right: 12 })
            .borderRadius(999)
            .backgroundColor('#9B8CFF')
            .fontColor(SunColor.night)
            .fontSize(12)
            .onClick(() => this.adjustDraftHours(0.25))
        }
        .width('100%')

        Row({ space: SunSpacing.sm }) {
          this.bedtimeButton('22:30')
          this.bedtimeButton('23:00')
          this.bedtimeButton('23:30')
          this.bedtimeButton('00:00')
          this.bedtimeButton('00:30')
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  private loadNights(): void {
    if (this.nightsJson.length === 0) {
      this.nights = []
      this.saveNights()
      return
    }
    try {
      const parsed = JSON.parse(this.nightsJson) as SleepNight[]
      this.nights = this.sortNights(parsed.map((night: SleepNight, index: number) => this.normalizeNight(night, index, parsed.length)))
      this.saveNights()
    } catch (_error) {
      this.nights = []
      this.saveNights()
    }
  }

  private saveNights(): void {
    this.nightsJson = JSON.stringify(this.nights)
  }

  private shownNights(): SleepNight[] {
    return this.nights.slice(Math.max(0, this.nights.length - this.rangeNights))
  }

  private recentNights(count: number): SleepNight[] {
    return this.nights.slice(Math.max(0, this.nights.length - count))
  }

  private debtHours(): number {
    const cutoff = new Date()
    cutoff.setHours(0, 0, 0, 0)
    cutoff.setDate(cutoff.getDate() - 14)
    const recent = this.nights.filter((night: SleepNight) => this.dateFromKey(night.date).getTime() > cutoff.getTime())
    return Math.max(0, recent.reduce((total: number, night: SleepNight) => {
      return total + (this.goalHours - night.hours)
    }, 0))
  }

  private averageHours(count: number): number {
    const list = this.recentNights(count)
    if (list.length === 0) {
      return 0
    }
    return list.reduce((total: number, night: SleepNight) => total + night.hours, 0) / list.length
  }

  private bestNightText(): string {
    const list = this.shownNights()
    if (list.length === 0) {
      return this.hoursText(0)
    }
    const best = list.reduce((selected: SleepNight, night: SleepNight) => night.hours > selected.hours ? night : selected, list[0])
    return this.nightText(best)
  }

  private roughestNightText(): string {
    const list = this.shownNights()
    if (list.length === 0) {
      return this.hoursText(0)
    }
    const roughest = list.reduce((selected: SleepNight, night: SleepNight) => night.hours < selected.hours ? night : selected, list[0])
    return this.nightText(roughest)
  }

  private averageForDays(days: string[]): number {
    const list = this.shownNights().filter((night: SleepNight) => days.includes(night.day))
    if (list.length === 0) {
      return 0
    }
    return list.reduce((total: number, night: SleepNight) => total + night.hours, 0) / list.length
  }

  private bedtimeMinutes(time: string): number {
    const parts = time.split(':')
    if (parts.length < 2) {
      return 0
    }
    const hour = Number(parts[0])
    const minute = Number(parts[1])
    return (hour < 12 ? hour + 24 : hour) * 60 + minute
  }

  private averageBedtimeMinutes(): number {
    const list = this.shownNights()
    if (list.length === 0) {
      return 0
    }
    return list.reduce((total: number, night: SleepNight) => total + this.bedtimeMinutes(night.bedtime), 0) / list.length
  }

  private consistencyMinutes(): number {
    const list = this.shownNights()
    if (list.length < 2) {
      return 0
    }
    const average = this.averageBedtimeMinutes()
    const variance = list.reduce((total: number, night: SleepNight) => {
      const delta = this.bedtimeMinutes(night.bedtime) - average
      return total + delta * delta
    }, 0) / list.length
    return Math.sqrt(variance)
  }

  private nightText(night: SleepNight): string {
    return `${this.hoursText(night.hours)} · ${this.monthDayLabel(this.dateFromKey(night.date))}`
  }

  private monthDayLabel(date: Date): string {
    const months: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    return `${months[date.getMonth()]} ${date.getDate()}`
  }

  private clockText(totalMinutes: number): string {
    const rounded = Math.round(totalMinutes)
    const normalized = ((rounded % 1440) + 1440) % 1440
    return `${this.pad(Math.floor(normalized / 60))}:${this.pad(normalized % 60)}`
  }

  private hoursText(hours: number): string {
    const total = Math.max(0, Math.round(hours * 60))
    return `${Math.floor(total / 60)}h ${this.pad(total % 60)}m`
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private setRange(value: number): void {
    if (value > 7 && !this.proUnlocked) {
      this.showToast('Sleeptab Pro unlocks 30 and 90 night trends.')
      return
    }
    this.rangeNights = value
  }

  private adjustGoal(delta: number): void {
    this.goalHours = Math.max(5, Math.min(10, this.goalHours + delta))
  }

  private unlockPro(): void {
    this.proUnlocked = true
    this.showToast('Sleeptab Pro unlocked on this device.')
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 1800 })
    } catch (_error) {
      // ponytail: lock still works if toast is unavailable.
    }
  }

  @Builder
  private rangeButton(label: string, value: number) {
    Button(value > 7 && !this.proUnlocked ? `${label} Pro` : label)
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
  private emptyState() {
    SunCard() {
      Column({ space: SunSpacing.sm }) {
        Text('No sleep data yet')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.ink)
        Text('Add tonight below to start tracking manually.')
          .fontSize(13)
          .fontColor(SunColor.pebble)
          .textAlign(TextAlign.Center)
          .lineHeight(20)
      }
      .width('100%')
      .padding({ top: SunSpacing.lg, bottom: SunSpacing.lg })
    }
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
          }, (night: SleepNight) => `${night.date}-${night.hours}-${night.bedtime}`)
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

        if (this.proUnlocked) {
          this.insightRow('BEST NIGHT', this.bestNightText())
          this.insightRow('ROUGHEST', this.roughestNightText())
          this.insightRow('WEEKDAY AVG', this.hoursText(this.averageForDays(['MON', 'TUE', 'WED', 'THU', 'FRI'])))
          this.insightRow('WEEKEND AVG', this.hoursText(this.averageForDays(['SAT', 'SUN'])))
          this.insightRow('AVG BEDTIME', this.clockText(this.averageBedtimeMinutes()))
          this.insightRow('CONSISTENCY', `± ${this.hoursText(this.consistencyMinutes() / 60)}`)
        } else {
          Text('Weekday vs weekend, best & roughest nights - unlock with Pro')
            .fontSize(12)
            .fontColor(SunColor.pebble)
            .lineHeight(18)

          SunButton({
            label: 'Unlock Pro',
            role: SunButtonRole.Secondary,
            action: () => this.unlockPro()
          })
        }
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
            if (this.nights.length === 0) {
              this.emptyState()
              this.goalCard()
              this.manualEntryCard()
            } else {
              this.debtCard()
              this.chartCard()
              this.weekCard()
              this.insightsCard()
              this.goalCard()
              this.manualEntryCard()
            }

            SunButton({
              label: 'Save tonight',
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
