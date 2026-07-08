import { intl } from '@kit.LocalizationKit'
import { SunColor, SunSpacing } from 'sunpebble_ui'

// 与 Index 同构，局部复制避免新建共享类型文件
interface RollEntry {
  date: string
  mood: string
  line: string
}

@ComponentV2
export struct CalendarView {
  @Param entries: RollEntry[] = []
  @Param calMonth: string = ''
  @Event onMonthChange: (month: string) => void = () => {}
  @Event onPickDay: (dateKey: string) => void = () => {}

  private moods: string[] = ['😄', '🙂', '😐', '😞', '😣']

  private pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`
  }

  private year(): number {
    return Number(this.calMonth.split('-')[0])
  }

  private month0(): number {
    return Number(this.calMonth.split('-')[1]) - 1
  }

  private todayKey(): string {
    const d = new Date()
    return `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}`
  }

  private mondayStart(): boolean {
    return new intl.Locale().toString().toLowerCase().startsWith('zh')
  }

  private daysInMonth(): number {
    return new Date(this.year(), this.month0() + 1, 0).getDate()
  }

  private leadBlanks(): number {
    const firstDow = new Date(this.year(), this.month0(), 1).getDay() // 0=Sun..6=Sat
    return this.mondayStart() ? (firstDow + 6) % 7 : firstDow
  }

  // 42 格（6 周）：前导空 + 1..daysInMonth + 末尾空，空用 '' 占位
  private cells(): string[] {
    const out: string[] = []
    const lead = this.leadBlanks()
    for (let i = 0; i < lead; i++) {
      out.push('')
    }
    const total = this.daysInMonth()
    for (let d = 1; d <= total; d++) {
      out.push(`${this.year()}-${this.pad(this.month0() + 1)}-${this.pad(d)}`)
    }
    while (out.length % 7 !== 0) {
      out.push('')
    }
    return out
  }

  private weekdayLabels(): string[] {
    const fmt = new intl.DateTimeFormat(new intl.Locale().toString(),
      { weekday: 'narrow' } as intl.DateTimeOptions)
    // 2024-01-07 是周日、2024-01-08 是周一
    const base = this.mondayStart() ? 8 : 7
    const labels: string[] = []
    for (let i = 0; i < 7; i++) {
      labels.push(fmt.format(new Date(2024, 0, base + i)))
    }
    return labels
  }

  private moodFor(dayKey: string): string {
    const e = this.entries.find((x: RollEntry) => x.date === dayKey)
    return e && this.moods.includes(e.mood) ? e.mood : ''
  }

  private hasEntry(dayKey: string): boolean {
    return this.entries.some((x: RollEntry) => x.date === dayKey)
  }

  private isFuture(dayKey: string): boolean {
    return dayKey.localeCompare(this.todayKey()) > 0
  }

  private moodScore(mood: string): number {
    const i = this.moods.indexOf(mood)
    return i < 0 ? 0 : this.moods.length - i   // 😄=5 .. 😣=1
  }

  // 近 12 个月键（旧→新），形如 'YYYY-MM'
  private heatMonths(): string[] {
    const base = new Date()
    base.setDate(1)
    const out: string[] = []
    for (let offset = 11; offset >= 0; offset--) {
      const d = new Date(base.getFullYear(), base.getMonth() - offset, 1)
      out.push(`${d.getFullYear()}-${this.pad(d.getMonth() + 1)}`)
    }
    return out
  }

  private daysOf(monthKey: string): number {
    const y = Number(monthKey.split('-')[0])
    const m = Number(monthKey.split('-')[1])
    return new Date(y, m, 0).getDate()
  }

  // 0=无记录, 1..5 按心情；有记录但无心情记 1
  private dayHeat(monthKey: string, day: number): number {
    const key = `${monthKey}-${this.pad(day)}`
    const mood = this.moodFor(key)
    if (mood.length > 0) {
      return Math.max(1, this.moodScore(mood))
    }
    return this.hasEntry(key) ? 1 : 0
  }

  private heatShade(level: number): string {
    if (level <= 0) {
      return '#EFE7D6'
    }
    const ramp: string[] = ['#D8CCBA', '#B9A98C', '#8C7A5E', '#5E5039', '#232733']
    return ramp[Math.max(0, Math.min(4, level - 1))]
  }

  private shiftMonth(delta: number): void {
    const d = new Date(this.year(), this.month0() + delta, 1)
    this.onMonthChange(`${d.getFullYear()}-${this.pad(d.getMonth() + 1)}`)
  }

  private monthTitle(): string {
    const fmt = new intl.DateTimeFormat(new intl.Locale().toString(),
      { year: 'numeric', month: 'long' } as intl.DateTimeOptions)
    return fmt.format(new Date(this.year(), this.month0(), 1))
  }

  @Builder
  private navButton(glyph: string, delta: number) {
    Button(glyph)
      .width(36).height(36).borderRadius(999)
      .backgroundColor('#F5EBD9').fontColor(SunColor.ink)
      .fontSize(18).fontWeight(FontWeight.Bold)
      .onClick(() => this.shiftMonth(delta))
  }

  @Builder
  private heatmap() {
    Column({ space: 4 }) {
      Text($r('app.string.dayroll_calendar_heatmap_title'))
        .fontSize(10).fontWeight(FontWeight.Bold).letterSpacing(1.5)
        .fontColor(SunColor.pebble).width('100%')

      ForEach(this.heatMonths(), (mk: string) => {
        Row({ space: 3 }) {
          Text(mk.split('-')[1])
            .fontSize(9).fontWeight(FontWeight.Bold).fontColor(SunColor.pebble)
            .width(16)
          ForEach([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31],
            (day: number) => {
              Blank()
                .height(9).layoutWeight(1)
                .borderRadius(2)
                .backgroundColor(day <= this.daysOf(mk) ? this.heatShade(this.dayHeat(mk, day)) : Color.Transparent)
            }, (day: number) => `${mk}-${day}`)
        }
        .width('100%').alignItems(VerticalAlign.Center)
      }, (mk: string) => mk)
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private dayCell(key: string) {
    Column() {
      if (key.length === 0) {
        Text('')
      } else if (this.moodFor(key).length > 0) {
        Text(this.moodFor(key)).fontSize(18).lineHeight(22)
      } else {
        Text(key.slice(8))
          .fontSize(12)
          .fontColor(this.isFuture(key) ? '#D8CCBA' : SunColor.pebble)
      }
    }
    .width('100%').aspectRatio(1)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .borderRadius(8)
    .borderWidth(key === this.todayKey() ? 2 : 0)
    .borderColor(SunColor.ink)
    .backgroundColor(this.hasEntry(key) ? '#F5EBD9' : Color.Transparent)
    .onClick(() => {
      if (key.length > 0 && !this.isFuture(key)) {
        this.onPickDay(key)
      }
    })
  }

  build() {
    Column({ space: SunSpacing.md }) {
      Row() {
        this.navButton('‹', -1)
        Text(this.monthTitle())
          .fontSize(15).fontWeight(FontWeight.Bold).letterSpacing(1)
          .fontColor(SunColor.ink).layoutWeight(1).textAlign(TextAlign.Center)
        this.navButton('›', 1)
      }
      .width('100%').alignItems(VerticalAlign.Center)

      Row() {
        ForEach(this.weekdayLabels(), (w: string, i: number) => {
          Text(w)
            .fontSize(10).fontWeight(FontWeight.Bold).fontColor(SunColor.pebble)
            .layoutWeight(1).textAlign(TextAlign.Center)
        }, (w: string, i: number) => `${i}`)
      }
      .width('100%')

      Grid() {
        ForEach(this.cells(), (key: string, i: number) => {
          GridItem() { this.dayCell(key) }
        }, (key: string, i: number) => `${this.calMonth}-${i}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .columnsGap(4).rowsGap(4)
      .width('100%')

      this.heatmap()
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: SunSpacing.md, bottom: 40 })
    .backgroundColor('#FFFDF7')
  }
}
