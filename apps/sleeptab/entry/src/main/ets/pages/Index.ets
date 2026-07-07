import {
  SunButton,
  SunButtonRole,
  SunColor,
  SunSafeRoot,
  SunSpacing,
  SunToolShell,
  SunType
} from 'sunpebble_ui'
import { appProfile } from '../AppProfile'

interface SleepNight {
  date: string
  day: string
  hours: number
  bedtime?: string
}

PersistentStorage.persistProp('sleeptab.goalHours.v1', 8)
PersistentStorage.persistProp('sleeptab.rangeNights.v1', 7)
PersistentStorage.persistProp('sleeptab.draftHours.v1', 7.5)
PersistentStorage.persistProp('sleeptab.draftBedtime.v1', '23:30')
PersistentStorage.persistProp('sleeptab.draftDate.v1', '')
PersistentStorage.persistProp('sleeptab.nights.v1', '')
PersistentStorage.persistProp('sleeptab.proUnlocked.v1', false)

@Entry
@Component
struct Index {
  @StorageLink('sleeptab.goalHours.v1') private goalHours: number = 8
  @StorageLink('sleeptab.rangeNights.v1') private rangeNights: number = 7
  @StorageLink('sleeptab.draftHours.v1') private draftHours: number = 7.5
  @StorageLink('sleeptab.draftBedtime.v1') private draftBedtime: string = '23:30'
  @StorageLink('sleeptab.draftDate.v1') private draftDate: string = ''
  @StorageLink('sleeptab.nights.v1') private nightsJson: string = ''
  @StorageLink('sleeptab.proUnlocked.v1') private proUnlocked: boolean = false
  @State private nights: SleepNight[] = []
  @State private confirmingDeleteNightDate: string = ''
  @State private paywallOpen: boolean = false

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
      bedtime: this.validBedtime(night.bedtime)
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

  // Display mapping only — night.day stays an English storage key.
  private dayText(day: string): Resource {
    switch (day) {
      case 'MON': return $r('app.string.sleeptab_day_mon')
      case 'TUE': return $r('app.string.sleeptab_day_tue')
      case 'WED': return $r('app.string.sleeptab_day_wed')
      case 'THU': return $r('app.string.sleeptab_day_thu')
      case 'FRI': return $r('app.string.sleeptab_day_fri')
      case 'SAT': return $r('app.string.sleeptab_day_sat')
      default: return $r('app.string.sleeptab_day_sun')
    }
  }

  private adjustDraftHours(delta: number): void {
    this.draftHours = Math.max(0.5, Math.min(14, Math.round((this.draftHours + delta) * 4) / 4))
  }

  private addNight(): void {
    const date = this.draftDateKey()
    const day = this.dateFromKey(date)
    const night: SleepNight = {
      date,
      day: this.dayLabel(day),
      hours: this.draftHours,
      bedtime: this.draftBedtime
    }
    this.nights = this.sortNights([
      ...this.nights.filter((item: SleepNight) => item.date !== date),
      night
    ])
    this.confirmingDeleteNightDate = ''
    this.saveNights()
  }

  private draftDateKey(): string {
    const today = this.dateKey(new Date())
    return this.draftDate.length > 0 && this.draftDate < today ? this.draftDate : today
  }

  private hasDraftNight(): boolean {
    const date = this.draftDateKey()
    return this.nights.some((night: SleepNight) => night.date === date)
  }

  private draftNightSummary(): string {
    const date = this.draftDateKey()
    const matches = this.nights.filter((night: SleepNight) => night.date === date)
    if (matches.length === 0) {
      return ''
    }
    const bedtime = this.validBedtime(matches[0].bedtime)
    return `${this.hoursText(matches[0].hours)}${bedtime.length > 0 ? ` · ${bedtime}` : ''}`
  }

  private deleteNight(date: string): void {
    this.nights = this.nights.filter((night: SleepNight) => night.date !== date)
    this.confirmingDeleteNightDate = ''
    this.saveNights()
  }

  private applyDraftDate(date: string): void {
    this.draftDate = date
    this.confirmingDeleteNightDate = ''
    const matches = this.nights.filter((night: SleepNight) => night.date === date)
    if (matches.length > 0) {
      this.draftHours = matches[0].hours
      this.draftBedtime = this.validBedtime(matches[0].bedtime) || this.draftBedtime
    }
  }

  private pickDraftDate(): void {
    try {
      this.getUIContext().showDatePickerDialog({
        start: new Date('2000-01-01T00:00:00'),
        end: new Date(),
        selected: this.dateFromKey(this.draftDateKey()),
        onDateAccept: (value: Date) => {
          this.applyDraftDate(this.dateKey(value))
        }
      })
    } catch (_error) {
      this.showToast($r('app.string.sleeptab_toast_date_picker_unavailable'))
    }
  }

  private draftBedtimeDate(): Date {
    const bedtime = this.validBedtime(this.draftBedtime) || '23:30'
    const parts = bedtime.split(':')
    return new Date(2024, 0, 1, Number(parts[0]), Number(parts[1]), 0)
  }

  private setDraftBedtime(hour: number, minute: number): void {
    this.draftBedtime = `${this.pad(Math.max(0, Math.min(23, hour)))}:${this.pad(Math.max(0, Math.min(59, minute)))}`
  }

  @Builder
  private manualEntryCard() {
    Column() {
      Column({ space: SunSpacing.md }) {
        Row({ space: SunSpacing.md }) {
          Column({ space: SunSpacing.xs }) {
            Text($r('app.string.sleeptab_entry_night_label'))
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1.5)
              .fontColor(SunColor.darkSecondary)
            Text(`${this.hoursText(this.draftHours)} · ${this.draftBedtime}`)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.cream)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('-15m')
            .height(38)
            .padding({ left: 12, right: 12 })
            .borderRadius(999)
            .backgroundColor('#31354A') // ponytail: dark chip bg, no SunColor token
            .fontColor(SunColor.cream)
            .fontSize(12)
            .onClick(() => this.adjustDraftHours(-0.25))

          Button('+15m')
            .height(38)
            .padding({ left: 12, right: 12 })
            .borderRadius(999)
            .backgroundColor(SunColor.sun)
            .fontColor(SunColor.night)
            .fontSize(12)
            .onClick(() => this.adjustDraftHours(0.25))
        }
        .width('100%')

        Button($r('app.string.sleeptab_entry_night_date_format', this.draftDateKey()))
          .height(38)
          .padding({ left: 14, right: 14 })
          .borderRadius(999)
          .backgroundColor('#31354A') // ponytail: dark chip bg, no SunColor token
          .fontColor(SunColor.cream)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .onClick(() => this.pickDraftDate())

        TimePicker({ selected: this.draftBedtimeDate() })
          .width('100%')
          .height(120)
          .selectedTextStyle({ color: SunColor.cream, font: { size: 22, weight: FontWeight.Bold } })
          .textStyle({ color: SunColor.darkSecondary, font: { size: 18, weight: FontWeight.Medium } })
          .onChange((value: TimePickerResult) => this.setDraftBedtime(value.hour, value.minute))

        if (this.hasDraftNight()) {
          Column({ space: SunSpacing.sm }) {
            Text($r('app.string.sleeptab_entry_saved_night_format', this.draftNightSummary()))
              .fontSize(12)
              .fontColor(SunColor.darkSecondary)

            if (this.confirmingDeleteNightDate === this.draftDateKey()) {
              Row({ space: SunSpacing.sm }) {
                SunButton({
                  label: $r('app.string.sleeptab_confirm_delete'),
                  role: SunButtonRole.Danger,
                  action: () => this.deleteNight(this.draftDateKey())
                })

                SunButton({
                  label: $r('app.string.sleeptab_cancel'),
                  role: SunButtonRole.Secondary,
                  action: () => this.confirmingDeleteNightDate = ''
                })
              }
              .width('100%')
            } else {
              SunButton({
                label: $r('app.string.sleeptab_delete_night'),
                role: SunButtonRole.Danger,
                action: () => this.confirmingDeleteNightDate = this.draftDateKey()
              })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(SunSpacing.lg)
    .backgroundColor('#24283A') // ponytail: dark card bg, no SunColor token
    .borderRadius(20)
  }

  private loadNights(): void {
    if (this.nightsJson.length === 0) {
      this.nights = []
      this.saveNights()
      return
    }
    try {
      const parsed = JSON.parse(this.nightsJson) as SleepNight[]
      const dates: string[] = []
      this.nights = this.sortNights(parsed.map((night: SleepNight, index: number) => this.normalizeNight(night, index, parsed.length))
        .filter((night: SleepNight) => night.date <= this.dateKey(new Date()))
        .filter((night: SleepNight) => {
          if (dates.includes(night.date)) {
            return false
          }
          dates.push(night.date)
          return true
        }))
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

  private hasNightsForDays(days: string[]): boolean {
    return this.shownNights().some((night: SleepNight) => days.includes(night.day))
  }

  private validBedtime(time?: string): string {
    if (!time) {
      return ''
    }
    const parts = time.split(':')
    if (parts.length < 2) {
      return ''
    }
    const hour = Number(parts[0])
    const minute = Number(parts[1])
    if (Number.isNaN(hour) || Number.isNaN(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return ''
    }
    return `${this.pad(hour)}:${this.pad(minute)}`
  }

  private bedtimeMinutes(time?: string): number {
    const bedtime = this.validBedtime(time)
    if (bedtime.length === 0) {
      return -1
    }
    const parts = bedtime.split(':')
    const hour = Number(parts[0])
    const minute = Number(parts[1])
    return (hour < 12 ? hour + 24 : hour) * 60 + minute
  }

  private bedtimeValues(): number[] {
    return this.shownNights()
      .map((night: SleepNight) => this.bedtimeMinutes(night.bedtime))
      .filter((minutes: number) => minutes >= 0)
  }

  private averageBedtimeMinutes(): number {
    const list = this.bedtimeValues()
    if (list.length === 0) {
      return 0
    }
    return list.reduce((total: number, minutes: number) => total + minutes, 0) / list.length
  }

  private consistencyMinutes(): number {
    const list = this.bedtimeValues()
    if (list.length < 2) {
      return 0
    }
    const average = this.averageBedtimeMinutes()
    const variance = list.reduce((total: number, minutes: number) => {
      const delta = minutes - average
      return total + delta * delta
    }, 0) / list.length
    return Math.sqrt(variance)
  }

  private nightText(night: SleepNight): string {
    return `${this.hoursText(night.hours)} · ${this.monthDayLabel(this.dateFromKey(night.date))}`
  }

  private monthDayLabel(date: Date): string {
    const months: Resource[] = [
      $r('app.string.sleeptab_month_1'), $r('app.string.sleeptab_month_2'), $r('app.string.sleeptab_month_3'),
      $r('app.string.sleeptab_month_4'), $r('app.string.sleeptab_month_5'), $r('app.string.sleeptab_month_6'),
      $r('app.string.sleeptab_month_7'), $r('app.string.sleeptab_month_8'), $r('app.string.sleeptab_month_9'),
      $r('app.string.sleeptab_month_10'), $r('app.string.sleeptab_month_11'), $r('app.string.sleeptab_month_12')
    ]
    return this.resString($r('app.string.sleeptab_month_day_format'), this.resString(months[date.getMonth()]), date.getDate())
  }

  private resString(res: Resource, ...args: Array<string | number>): string {
    const context = this.getUIContext().getHostContext()
    return context ? context.resourceManager.getStringSync(res, ...args) : ''
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

  private sleepBarHeight(hours: number): number {
    return 34 + Math.min(118, Math.round(hours / this.goalHours * 92))
  }

  private goalRuleBottom(): number {
    return this.sleepBarHeight(this.goalHours) + 18
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private setRange(value: number): void {
    if (value > 7 && !this.proUnlocked) {
      this.showPaywall()
      return
    }
    this.rangeNights = value
  }

  private adjustGoal(delta: number): void {
    this.goalHours = Math.max(5, Math.min(10, this.goalHours + delta))
  }

  private unlockPro(): void {
    this.proUnlocked = true
    this.paywallOpen = false
    this.showToast($r('app.string.sleeptab_toast_pro_unlocked'))
  }

  private showPaywall(): void {
    this.paywallOpen = true
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 1800 })
    } catch (_error) {
      // ponytail: lock still works if toast is unavailable.
    }
  }

  @Builder
  private rangeButton(label: string, value: number) {
    Button(value > 7 && !this.proUnlocked ? `${label} 🔒` : label)
      .height(34)
      .padding({ left: 14, right: 14 })
      .borderRadius(999)
      .backgroundColor(this.rangeNights === value ? SunColor.sun : '#31354A') // ponytail: dark chip bg, no SunColor token
      .fontColor(this.rangeNights === value ? SunColor.night : SunColor.darkSecondary)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .onClick(() => this.setRange(value))
  }

  @Builder
  private emptyState() {
    Column() {
      Column({ space: SunSpacing.sm }) {
        Text('🌙')
          .fontSize(56)
        Text($r('app.string.sleeptab_empty_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.cream)
        Text($r('app.string.sleeptab_empty_message'))
          .fontSize(13)
          .fontColor(SunColor.darkSecondary)
          .textAlign(TextAlign.Center)
          .lineHeight(20)
      }
      .width('100%')
      .padding({ top: SunSpacing.lg, bottom: SunSpacing.lg })
    }
    .width('100%')
    .padding(SunSpacing.lg)
    .backgroundColor('#24283A') // ponytail: dark card bg, no SunColor token
    .borderRadius(20)
  }

  @Builder
  private debtCard() {
    Column({ space: SunSpacing.sm }) {
      if (this.debtHours() <= 0) {
        Text($r('app.string.sleeptab_debt_caught_up'))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.sun)
      } else {
        Text(this.hoursText(this.debtHours()))
          .fontSize(46)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.cream)
      }

      Text(this.debtHours() <= 0 ? $r('app.string.sleeptab_debt_none_label') : $r('app.string.sleeptab_debt_label'))
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1.5)
        .fontColor(SunColor.darkSecondary)
    }
    .width('100%')
    .padding({ top: 30, bottom: 30 })
    .backgroundColor('#24283A') // ponytail: dark card bg, no SunColor token
    .borderRadius(20)
  }

  @Builder
  private chartCard() {
    Column() {
      Column({ space: SunSpacing.lg }) {
        Row({ space: SunSpacing.sm }) {
          this.rangeButton('7N', 7)
          this.rangeButton('30N', 30)
          this.rangeButton('90N', 90)
        }

        Stack({ alignContent: Alignment.Bottom }) {
          // ponytail: 30/90 晚间距 1px 挤同屏当 sparkline 读；再细分需要按周聚合
          Row({ space: this.rangeNights > 7 ? 1 : SunSpacing.sm }) {
            ForEach(this.shownNights(), (night: SleepNight) => {
              Column({ space: SunSpacing.xs }) {
                Blank()
                  .width('100%')
                  .height(this.sleepBarHeight(night.hours))
                  .backgroundColor(night.hours >= this.goalHours ? SunColor.sun : '#8C6925') // ponytail: dim goal-miss bar, no SunColor token
                  .borderRadius(this.rangeNights > 7 ? 1 : 5)

                Text(this.rangeNights <= 7 ? this.dayText(night.day) : ' ')
                  .fontSize(9)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(SunColor.darkSecondary)
              }
              .layoutWeight(1)
              .height(168)
              .justifyContent(FlexAlign.End)
            }, (night: SleepNight) => `${night.date}-${night.hours}-${night.bedtime}`)
          }
          .height(176)

          Row({ space: SunSpacing.xs }) {
            Blank()
              .height(1)
              .layoutWeight(1)
              .backgroundColor(SunColor.darkSecondary)

            Text($r('app.string.sleeptab_chart_goal_format', this.hoursText(this.goalHours)))
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.darkSecondary)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: this.goalRuleBottom() })
        }
        .width('100%')
        .height(176)
      }
    }
    .width('100%')
    .padding(SunSpacing.lg)
    .backgroundColor('#24283A') // ponytail: dark card bg, no SunColor token
    .borderRadius(20)
  }

  @Builder
  private weekCard() {
    Column() {
      Row() {
        Column({ space: SunSpacing.xs }) {
          Text($r('app.string.sleeptab_week_avg_label'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .fontColor(SunColor.darkSecondary)
          Text(this.hoursText(this.averageHours(7)))
            .fontSize(SunType.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(SunColor.cream)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: SunSpacing.xs }) {
          Text($r('app.string.sleeptab_week_vs_goal_label'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .fontColor(SunColor.darkSecondary)
          Text((this.averageHours(7) >= this.goalHours ? '+' : '-') + this.hoursText(Math.abs(this.averageHours(7) - this.goalHours)))
            .fontSize(SunType.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.averageHours(7) >= this.goalHours ? SunColor.sun : SunColor.cream)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
    }
    .width('100%')
    .padding(SunSpacing.lg)
    .backgroundColor('#24283A') // ponytail: dark card bg, no SunColor token
    .borderRadius(20)
  }

  @Builder
  private insightsCard() {
    Column() {
      Column({ space: SunSpacing.md }) {
        Text($r('app.string.sleeptab_insights_title_format', this.shownNights().length))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
          .fontColor(SunColor.darkSecondary)

        if (this.proUnlocked) {
          if (this.hasNightsForDays(['MON', 'TUE', 'WED', 'THU', 'FRI'])) {
            this.insightRow($r('app.string.sleeptab_insight_weekday_avg'), this.hoursText(this.averageForDays(['MON', 'TUE', 'WED', 'THU', 'FRI'])))
          }
          if (this.hasNightsForDays(['SAT', 'SUN'])) {
            this.insightRow($r('app.string.sleeptab_insight_weekend_avg'), this.hoursText(this.averageForDays(['SAT', 'SUN'])))
          }
          this.insightRow($r('app.string.sleeptab_insight_best_night'), this.bestNightText())
          this.insightRow($r('app.string.sleeptab_insight_roughest'), this.roughestNightText())
          if (this.bedtimeValues().length >= 2) {
            this.insightRow($r('app.string.sleeptab_insight_avg_bedtime'), this.clockText(this.averageBedtimeMinutes()))
            this.insightRow($r('app.string.sleeptab_insight_consistency'), `± ${this.hoursText(this.consistencyMinutes() / 60)}`)
          }
        } else {
          Text($r('app.string.sleeptab_insights_locked'))
            .fontSize(12)
            .fontColor(SunColor.darkSecondary)
            .lineHeight(18)
            .onClick(() => this.showPaywall())
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(SunSpacing.lg)
    .backgroundColor('#24283A') // ponytail: dark card bg, no SunColor token
    .borderRadius(20)
  }

  @Builder
  private insightRow(label: ResourceStr, value: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)
        .fontColor(SunColor.darkSecondary)
      Blank().layoutWeight(1)
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(SunColor.cream)
    }
    .width('100%')
  }

  @Builder
  private goalCard() {
    Column() {
      Row({ space: SunSpacing.md }) {
        Text($r('app.string.sleeptab_goal_label'))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.darkSecondary)
          .layoutWeight(1)

        Button('-')
          .width(38)
          .height(38)
          .borderRadius(999)
          .backgroundColor('#31354A') // ponytail: dark chip bg, no SunColor token
          .fontColor(SunColor.cream)
          .onClick(() => this.adjustGoal(-0.25))

        Text(this.hoursText(this.goalHours))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.cream)

        Button('+')
          .width(38)
          .height(38)
          .borderRadius(999)
          .backgroundColor(SunColor.sun)
          .fontColor(SunColor.night)
          .onClick(() => this.adjustGoal(0.25))
      }
      .width('100%')
    }
    .width('100%')
    .padding(SunSpacing.lg)
    .backgroundColor('#24283A') // ponytail: dark card bg, no SunColor token
    .borderRadius(20)
  }

  @Builder
  private paywallFeature(icon: string, text: ResourceStr) {
    Row({ space: SunSpacing.md }) {
      Text(icon)
        .fontSize(18)
        .width(24)
        .textAlign(TextAlign.Center)
      Text(text)
        .fontSize(14)
        .fontColor(SunColor.cream)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private paywallPanel() {
    if (this.paywallOpen && !this.proUnlocked) {
      Column({ space: SunSpacing.lg }) {
        Text($r('app.string.sleeptab_paywall_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(4)
          .fontColor(SunColor.cream)

        Column({ space: 14 }) {
          this.paywallFeature('▥', $r('app.string.sleeptab_paywall_feature_history'))
          this.paywallFeature('◌', $r('app.string.sleeptab_paywall_feature_insights'))
          this.paywallFeature('▦', $r('app.string.sleeptab_paywall_feature_widget'))
          this.paywallFeature('♥', $r('app.string.sleeptab_paywall_feature_indie'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Text($r('app.string.sleeptab_paywall_promise'))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.darkSecondary)
          .lineHeight(17)
          .textAlign(TextAlign.Center)

        SunButton({
          label: $r('app.string.sleeptab_paywall_unlock'),
          action: () => this.unlockPro()
        })

        Button($r('app.string.sleeptab_paywall_restore'))
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(12)
          .fontColor(SunColor.darkSecondary)
          .onClick(() => this.unlockPro())

        Button($r('app.string.sleeptab_paywall_close'))
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(12)
          .fontColor(SunColor.darkSecondary)
          .onClick(() => this.paywallOpen = false)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding(SunSpacing.lg)
      .backgroundColor('#24283A') // ponytail: dark card bg, no SunColor token
      .borderRadius(20)
    }
  }

  build() {
    Column() {
      SunSafeRoot({ mode: appProfile.mode }) {
      SunToolShell({
        manifest: appProfile,
        showPro: !this.proUnlocked,
        onPro: () => this.showPaywall()
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

            this.paywallPanel()
          }
          .width('100%')
          .padding({ left: SunSpacing.xl, right: SunSpacing.xl, bottom: SunSpacing.xl })
        }
        .width('100%')
        .height('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      }
    }
    .width('100%')
    .height('100%')
  }
}
