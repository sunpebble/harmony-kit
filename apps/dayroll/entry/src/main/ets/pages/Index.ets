import {
  SunButton,
  SunButtonRole,
  SunColor,
  SunFitText,
  SunMode,
  SunSafeRoot,
  SunSpacing
} from 'sunpebble_ui'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { systemShare } from '@kit.ShareKit'

interface RollEntry {
  date: string
  day: string
  month: string
  mood: string
  line: string
}

interface MonthStat {
  key: string
  label: string
  logged: number
  avgMood: number
}

PersistentStorage.persistProp('dayroll.mood.v1', '😐')
PersistentStorage.persistProp('dayroll.entries.v1', '')
PersistentStorage.persistProp('dayroll.exportOpen.v1', false)
PersistentStorage.persistProp('dayroll.statsOpen.v1', false)
PersistentStorage.persistProp('dayroll.exportFormat.v1', 'Plain Text')
PersistentStorage.persistProp('dayroll.reminderEnabled.v1', false)
PersistentStorage.persistProp('dayroll.reminderHour.v1', 21)
PersistentStorage.persistProp('dayroll.reminderMinute.v1', 0)
PersistentStorage.persistProp('dayroll.proUnlocked.v1', false)

@Entry
@Component
struct Index {
  private moods: string[] = ['😄', '🙂', '😐', '😞', '😣']
  private tapeScroller: Scroller = new Scroller()
  @StorageLink('dayroll.mood.v1') private mood: string = '😐'
  @StorageLink('dayroll.entries.v1') private entriesJson: string = ''
  @StorageLink('dayroll.exportOpen.v1') private exportOpen: boolean = false
  @StorageLink('dayroll.statsOpen.v1') private statsOpen: boolean = false
  @StorageLink('dayroll.exportFormat.v1') private exportFormat: string = 'Plain Text'
  @State private reminderOpen: boolean = false
  @StorageLink('dayroll.reminderEnabled.v1') private reminderEnabled: boolean = false
  @StorageLink('dayroll.reminderHour.v1') private reminderHour: number = 21
  @StorageLink('dayroll.reminderMinute.v1') private reminderMinute: number = 0
  @StorageLink('dayroll.proUnlocked.v1') private proUnlocked: boolean = false
  @State private draftLine: string = ''
  @State private editingDate: string = ''
  @State private confirmingDelete: boolean = false
  @State private composerOpen: boolean = false
  @State private selectedMonth: string = ''
  @State private paywallOpen: boolean = false
  @State private paywallIntent: string = ''
  @State private entries: RollEntry[] = []

  aboutToAppear(): void {
    this.loadEntries()
  }

  private loadEntries(): void {
    if (this.entriesJson.length === 0) {
      return
    }
    try {
      const parsed = JSON.parse(this.entriesJson) as RollEntry[]
      const dates: string[] = []
      this.entries = this.sortEntries(parsed.map((entry: RollEntry) => this.normalizeEntry(entry))
        .filter((entry: RollEntry) => {
          if (dates.includes(entry.date)) {
            return false
          }
          dates.push(entry.date)
          return true
        }))
      this.saveEntries()
    } catch (_error) {
      this.entries = []
      this.saveEntries()
    }
  }

  private saveEntries(): void {
    this.entriesJson = JSON.stringify(this.entries)
  }

  private saveToday(): void {
    const line = this.draftLine
    const date = this.activeDate()
    const day = this.dateFromKey(date)
    const entry: RollEntry = { date, day: this.dayLabel(day), month: this.monthLabel(day), mood: this.mood, line }
    const rest = this.entries.filter((item: RollEntry) => item.date !== date)
    this.entries = this.sortEntries([entry, ...rest])
    this.draftLine = ''
    this.editingDate = ''
    this.confirmingDelete = false
    this.composerOpen = false
    this.saveEntries()
  }

  private deleteToday(): void {
    const date = this.activeDate()
    this.entries = this.entries.filter((entry: RollEntry) => entry.date !== date)
    this.draftLine = ''
    this.editingDate = ''
    this.confirmingDelete = false
    this.composerOpen = false
    this.saveEntries()
  }

  private editEntry(entry: RollEntry): void {
    this.editingDate = entry.date
    this.mood = this.validMood(entry.mood) || '😐'
    this.draftLine = entry.line
    this.confirmingDelete = false
    this.composerOpen = true
  }

  private cancelComposer(): void {
    this.draftLine = ''
    this.editingDate = ''
    this.confirmingDelete = false
    this.composerOpen = false
  }

  private composeToday(): void {
    const today = this.dateKey(new Date())
    const entry = this.entries.find((item: RollEntry) => item.date === today)
    if (entry) {
      this.editEntry(entry)
      return
    }
    this.editingDate = ''
    this.mood = '😐'
    this.draftLine = ''
    this.confirmingDelete = false
    this.composerOpen = true
  }

  private activeDate(): string {
    return this.editingDate.length > 0 ? this.editingDate : this.dateKey(new Date())
  }

  private hasActiveEntry(): boolean {
    const date = this.activeDate()
    return this.entries.some((entry: RollEntry) => entry.date === date)
  }

  private composerTitle(): string {
    return this.composeDateTitle(this.dateFromKey(this.activeDate()))
  }

  private streak(): number {
    if (this.entries.length === 0) {
      return 0
    }
    const logged = this.dateKeys()
    let cursor = this.dateKey(new Date())
    if (!logged.includes(cursor)) {
      cursor = this.addDays(cursor, -1)
      if (!logged.includes(cursor)) {
        return 0
      }
    }
    let count = 0
    while (logged.includes(cursor)) {
      count += 1
      cursor = this.addDays(cursor, -1)
    }
    return count
  }

  private longestStreak(): number {
    const logged = this.dateKeys()
    let best = 0
    logged.forEach((date: string) => {
      if (logged.includes(this.addDays(date, -1))) {
        return
      }
      let cursor = date
      let count = 0
      while (logged.includes(cursor)) {
        count += 1
        cursor = this.addDays(cursor, 1)
      }
      best = Math.max(best, count)
    })
    return best
  }

  private moodCount(mood: string): number {
    return this.entries.filter((entry: RollEntry) => entry.mood === mood).length
  }

  private moodScore(mood: string): number {
    const index = this.moods.indexOf(mood)
    return index < 0 ? 0 : this.moods.length - index
  }

  private validMood(mood: string): string {
    return this.moods.includes(mood) ? mood : ''
  }

  private moodRaw(mood: string): string {
    const labels: string[] = ['great', 'good', 'meh', 'bad', 'awful']
    const index = this.moods.indexOf(mood)
    return index < 0 ? '' : labels[index]
  }

  private moodMark(mood: string): string {
    return this.validMood(mood) || '·'
  }

  private moodForScore(score: number): string {
    if (score <= 0) {
      return '-'
    }
    const index = Math.max(0, Math.min(this.moods.length - 1, this.moods.length - Math.round(score)))
    return this.moods[index]
  }

  private moodTrendHeight(score: number): number {
    return score <= 0 ? 8 : 20 + Math.round(score / 5 * 84)
  }

  private monthKey(date: Date): string {
    return `${date.getFullYear()}-${this.pad(date.getMonth() + 1)}`
  }

  private monthShortLabel(date: Date): string {
    const months: string[] = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D']
    return months[date.getMonth()]
  }

  private monthlyStats(): MonthStat[] {
    const cursor = new Date()
    cursor.setDate(1)
    const stats: MonthStat[] = []
    for (let offset = 11; offset >= 0; offset--) {
      const month = new Date(cursor.getFullYear(), cursor.getMonth() - offset, 1)
      const key = this.monthKey(month)
      const entries = this.entries.filter((entry: RollEntry) => entry.date.startsWith(key))
      const scores = entries.map((entry: RollEntry) => this.moodScore(entry.mood)).filter((score: number) => score > 0)
      const scoreTotal = scores.reduce((total: number, score: number) => total + score, 0)
      const stat: MonthStat = {
        key,
        label: this.monthShortLabel(month),
        logged: entries.length,
        avgMood: scores.length > 0 ? scoreTotal / scores.length : 0
      }
      stats.push(stat)
    }
    return stats
  }

  private maxMonthlyLogged(): number {
    return Math.max(1, ...this.monthlyStats().map((stat: MonthStat) => stat.logged))
  }

  private exportText(): string {
    const sorted = [...this.entries].sort((a: RollEntry, b: RollEntry) => a.date.localeCompare(b.date))
    if (this.exportFormat === 'Markdown') {
      return sorted.map((entry: RollEntry) => {
        const mood = this.validMood(entry.mood)
        return `- **${entry.date}**${mood.length > 0 ? ` ${mood}` : ''} ${entry.line}`
      }).join('\n')
    }
    if (this.exportFormat === 'CSV') {
      const rows = sorted.map((entry: RollEntry) => {
        return `${entry.date},${this.moodRaw(entry.mood)},${this.csvValue(entry.line)}`
      })
      return ['date,mood,line', ...rows].join('\n')
    }
    return sorted.map((entry: RollEntry) => {
      const mood = this.moodRaw(entry.mood)
      return `${entry.date}${mood.length > 0 ? ` [${mood}]` : ''} ${entry.line}`
    }).join('\n')
  }

  private normalizeEntry(entry: RollEntry): RollEntry {
    const date = entry.date ? entry.date : this.dateKey(new Date())
    const parsed = this.dateFromKey(date)
    return {
      date,
      day: this.dayLabel(parsed),
      month: this.monthLabel(parsed),
      mood: this.validMood(entry.mood),
      line: typeof entry.line === 'string' ? entry.line : ''
    }
  }

  private sortEntries(entries: RollEntry[]): RollEntry[] {
    return [...entries].sort((a: RollEntry, b: RollEntry) => b.date.localeCompare(a.date))
  }

  private dateKeys(): string[] {
    const keys: string[] = []
    this.entries.forEach((entry: RollEntry) => {
      if (!keys.includes(entry.date)) {
        keys.push(entry.date)
      }
    })
    return keys.sort((a: string, b: string) => a.localeCompare(b))
  }

  private months(): string[] {
    const months: string[] = []
    this.entries.forEach((entry: RollEntry) => {
      if (!months.includes(entry.month)) {
        months.push(entry.month)
      }
    })
    return months
  }

  private monthOffset(month: string): number {
    let offset = this.composerOpen ? 380 : 128
    for (const item of this.months()) {
      if (item === month) {
        return offset
      }
      offset += 28 + SunSpacing.sm + this.entriesForMonth(item).length * (32 + SunSpacing.sm) + SunSpacing.md
    }
    return 0
  }

  private scrollToMonth(month: string): void {
    this.selectedMonth = month
    this.tapeScroller.scrollTo({ xOffset: 0, yOffset: this.monthOffset(month) })
  }

  private monthIndexLabel(month: string): string {
    return month.startsWith('JANUARY ') ? month.slice(month.length - 2) : month.slice(0, 1)
  }

  private entriesForMonth(month: string): RollEntry[] {
    return this.entries.filter((entry: RollEntry) => entry.month === month)
  }

  private memories(): RollEntry[] {
    if (!this.proUnlocked) {
      return []
    }
    const active = this.dateFromKey(this.activeDate())
    return this.entries.filter((entry: RollEntry) => {
      if (entry.date === this.activeDate()) {
        return false
      }
      const date = this.dateFromKey(entry.date)
      const years = active.getFullYear() - date.getFullYear()
      return years >= 1 && years <= 30 && date.getMonth() === active.getMonth() && date.getDate() === active.getDate()
    }).sort((a: RollEntry, b: RollEntry) => b.date.localeCompare(a.date))
  }

  private memoryAge(entry: RollEntry): Resource {
    const years = Math.max(1, this.dateFromKey(this.activeDate()).getFullYear() - this.dateFromKey(entry.date).getFullYear())
    return years === 1 ? $r('app.string.dayroll_memory_age_one') : $r('app.string.dayroll_memory_age_format', years)
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

  private addDays(key: string, delta: number): string {
    const date = this.dateFromKey(key)
    date.setDate(date.getDate() + delta)
    return this.dateKey(date)
  }

  private dayLabel(date: Date): string {
    const months: string[] = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC']
    return `${months[date.getMonth()]} ${this.pad(date.getDate())}`
  }

  private monthLabel(date: Date): string {
    const months: string[] = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER']
    return `${months[date.getMonth()]} ${date.getFullYear()}`
  }

  private composeDateTitle(date: Date): string {
    const weekdays: string[] = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY']
    const months: string[] = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC']
    return `${weekdays[date.getDay()]} ${months[date.getMonth()]} ${date.getDate()}`
  }

  private csvValue(value: string): string {
    if (value.includes(',') || value.includes('"') || value.includes('\n')) {
      return `"${value.replaceAll('"', '""')}"`
    }
    return value
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private enableReminder(): void {
    this.scheduleDailyReminder()
  }

  private async scheduleDailyReminder(quiet: boolean = false): Promise<void> {
    try {
      if (!await this.requestNotificationAccess()) {
        this.reminderEnabled = false
        this.showToast($r('app.string.dayroll_toast_enable_notifications'))
        return
      }
      await reminderAgentManager.cancelAllReminders()
      const request: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: this.reminderHour,
        minute: this.reminderMinute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: 'Dayroll',
        content: this.resString($r('app.string.dayroll_reminder_content')),
        expiredContent: this.resString($r('app.string.dayroll_reminder_expired')),
        notificationId: 1001,
        tapDismissed: true
      }
      await reminderAgentManager.publishReminder(request)
      this.reminderEnabled = true
      if (!quiet) {
        this.showToast($r('app.string.dayroll_toast_reminder_set', this.reminderTimeLabel()))
      }
    } catch (_error) {
      this.reminderEnabled = false
      this.showToast($r('app.string.dayroll_toast_enable_notifications'))
    }
  }

  private disableReminder(): void {
    this.cancelDailyReminder()
  }

  private async cancelDailyReminder(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders()
    } catch (_error) {
      // ponytail: stale reminder ids should not block the visible off state.
    }
    this.reminderEnabled = false
    this.showToast($r('app.string.dayroll_toast_reminder_off'))
  }

  private async requestNotificationAccess(): Promise<boolean> {
    const context = this.getUIContext().getHostContext()
    if (!context) {
      return false
    }
    try {
      await notificationManager.requestEnableNotification(context as common.UIAbilityContext)
      return true
    } catch (_error) {
      return false
    }
  }

  private resString(res: Resource): string {
    const context = this.getUIContext().getHostContext()
    return context ? context.resourceManager.getStringSync(res) : ''
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message,
        duration: 2000
      })
    } catch (_error) {
      // ponytail: visible lock state is enough if toast is unavailable.
    }
  }

  private reminderTimeLabel(): string {
    return `${this.pad(this.reminderHour)}:${this.pad(this.reminderMinute)}`
  }

  private reminderDate(): Date {
    return new Date(2024, 0, 1, this.reminderHour, this.reminderMinute, 0)
  }

  private setReminderTime(hour: number, minute: number): void {
    this.reminderHour = Math.max(0, Math.min(23, hour))
    this.reminderMinute = Math.max(0, Math.min(59, minute))
    if (this.reminderEnabled) {
      this.scheduleDailyReminder(true)
    }
  }

  private unlockPro(): void {
    this.proUnlocked = true
    this.paywallOpen = false
    if (this.paywallIntent === 'Stats') {
      this.statsOpen = true
    } else if (this.paywallIntent === 'Export') {
      this.exportOpen = true
    }
    this.paywallIntent = ''
    this.showToast($r('app.string.dayroll_toast_pro_unlocked'))
  }

  private showPaywall(): void {
    this.paywallOpen = true
  }

  private toggleStats(): void {
    if (!this.proUnlocked) {
      this.statsOpen = false
      this.paywallIntent = 'Stats'
      this.showPaywall()
      return
    }
    this.statsOpen = !this.statsOpen
  }

  private toggleExport(): void {
    if (!this.proUnlocked) {
      this.exportOpen = false
      this.paywallIntent = 'Export'
      this.showPaywall()
      return
    }
    this.exportOpen = !this.exportOpen
  }

  private formatDisplay(format: string): Resource {
    if (format === 'Markdown') {
      return $r('app.string.dayroll_format_markdown')
    }
    if (format === 'CSV') {
      return $r('app.string.dayroll_format_csv')
    }
    return $r('app.string.dayroll_format_plain_text')
  }

  private async copyExportText(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.exportText())
      await pasteboard.getSystemPasteboard().setData(data)
      this.showToast($r('app.string.dayroll_toast_copied_format', this.resString(this.formatDisplay(this.exportFormat))))
    } catch (_error) {
      this.showToast($r('app.string.dayroll_toast_copy_failed'))
    }
  }

  private async shareExportText(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (!context) {
      await this.copyExportText()
      return
    }
    try {
      const shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.TEXT,
        content: this.exportText()
      })
      const controller: systemShare.ShareController = new systemShare.ShareController(shareData)
      await controller.show(context as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      })
    } catch (_error) {
      await this.copyExportText()
    }
  }

  @Builder
  private perforation() {
    Row({ space: 4 }) {
      ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], (item: number) => {
        Blank()
          .width(10)
          .height(1)
          .backgroundColor('#C8BDAA') // ponytail: paper perforation tint, no Sun token
      }, (item: number) => item.toString())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private headerTitleRow() {
    Row() {
      Text('DAYROLL')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(2)
        .fontColor(SunColor.ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Row({ space: 6 }) {
        this.toolbarIcon('🔔', () => {
          this.reminderOpen = !this.reminderOpen
        })
        this.toolbarIcon('📊', () => {
          this.toggleStats()
        })
        this.toolbarIcon('↗', () => {
          this.toggleExport()
        })
      }
      .flexShrink(0)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private headerMeta() {
    Column({ space: 4 }) {
      SunFitText({
        text: $r('app.string.dayroll_tagline'),
        maxFontSize: 11,
        minFontSize: 8,
        fontColor: SunColor.pebble,
        letterSpacing: 0
      })

      Row({ space: SunSpacing.sm }) {
        SunFitText({
          text: $r('app.string.dayroll_header_total_days', this.entries.length),
          maxFontSize: 11,
          minFontSize: 8,
          fontColor: SunColor.pebble,
          fontWeight: FontWeight.Bold
        })
          .layoutWeight(1)

        SunFitText({
          text: $r('app.string.dayroll_header_streak', this.streak()),
          maxFontSize: 11,
          minFontSize: 8,
          fontColor: SunColor.pebble,
          fontWeight: FontWeight.Bold,
          textAlign: TextAlign.End
        })
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private toolbarIconActive(label: string): boolean {
    if (label === '🔔') {
      return this.reminderOpen
    }
    if (label === '📊') {
      return this.statsOpen || (this.paywallOpen && this.paywallIntent === 'Stats')
    }
    return this.exportOpen || (this.paywallOpen && this.paywallIntent === 'Export')
  }

  @Builder
  private toolbarIcon(label: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Text(label)
        .fontSize(20)
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width(40)
    .height(40)
    .padding(0)
    .borderRadius(999)
    .backgroundColor(this.toolbarIconActive(label) ? SunColor.sun : '#F5EBD9')
    .onClick(action)
  }

  @Builder
  private topChrome() {
    Column({ space: SunSpacing.xs }) {
      this.headerTitleRow()
      this.headerMeta()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: SunSpacing.sm, bottom: SunSpacing.sm })
    .backgroundColor('#FFFDF7')
  }

  @Builder
  private composer() {
    Column({ space: SunSpacing.md }) {
      Text(this.composerTitle())
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(SunColor.pebble)

      Row({ space: SunSpacing.sm }) {
        ForEach(this.moods, (candidate: string) => {
          Button({ type: ButtonType.Normal }) {
            Text(candidate)
              .fontSize(30)
              .lineHeight(36)
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          .width(52)
          .height(52)
          .padding(0)
          .borderRadius(999)
          .backgroundColor(this.mood === candidate ? SunColor.ink : '#F5EBD9')
          .opacity(this.mood === candidate ? 1 : 0.85)
          .scale({ x: this.mood === candidate ? 1.08 : 1, y: this.mood === candidate ? 1.08 : 1 })
          .onClick(() => this.mood = candidate)
        }, (candidate: string) => candidate)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      TextArea({ placeholder: $r('app.string.dayroll_composer_placeholder'), text: this.draftLine })
        .height(96)
        .fontSize(15)
        .fontColor(SunColor.ink)
        .placeholderColor(SunColor.pebble)
        .backgroundColor('#FFFDF7') // ponytail: tape paper white, no Sun token
        .borderRadius(8)
        .border({ width: 1, color: '#C8BDAA' }) // ponytail: paper edge tint, no Sun token
        .onChange((value: string) => this.draftLine = value)

      if (this.memories().length > 0) {
        Column({ space: SunSpacing.sm }) {
          Text($r('app.string.dayroll_on_this_day'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.5)
            .fontColor(SunColor.pebble)

          ForEach(this.memories(), (memory: RollEntry) => {
            Row({ space: SunSpacing.sm }) {
              Text(this.memoryAge(memory))
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(SunColor.pebble)
                .width(72)

              Text(this.moodMark(memory.mood))
                .fontSize(18)
                .lineHeight(22)
                .width(28)
                .textAlign(TextAlign.Center)

              Text(memory.line.length === 0 ? '—' : memory.line)
                .fontSize(12)
                .fontColor(SunColor.ink)
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
          }, (memory: RollEntry) => memory.date)
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      }

      if (this.confirmingDelete) {
        Text($r('app.string.dayroll_delete_confirm'))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.pebble)

        Row({ space: SunSpacing.md }) {
          SunButton({
            label: $r('app.string.dayroll_delete'),
            role: SunButtonRole.Danger,
            action: () => this.deleteToday()
          })

          SunButton({
            label: $r('app.string.dayroll_cancel'),
            role: SunButtonRole.Secondary,
            action: () => this.confirmingDelete = false
          })
        }
      } else {
        Row({ space: SunSpacing.md }) {
          SunButton({
            label: $r('app.string.dayroll_save'),
            action: () => this.saveToday()
          })

          SunButton({
            label: $r('app.string.dayroll_cancel'),
            role: SunButtonRole.Secondary,
            action: () => this.cancelComposer()
          })
        }

        if (this.hasActiveEntry()) {
          SunButton({
            label: $r('app.string.dayroll_delete_this_day'),
            role: SunButtonRole.Danger,
            action: () => this.confirmingDelete = true
          })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private rollList() {
    Row({ space: SunSpacing.xs }) {
      Column({ space: SunSpacing.md }) {
        if (this.entries.length === 0) {
          Text($r('app.string.dayroll_empty_tape'))
            .fontSize(13)
            .fontColor(SunColor.pebble)
            .textAlign(TextAlign.Center)
            .lineHeight(22)
            .width('100%')
            .padding({ top: 30, bottom: 30 })
        } else {
          ForEach(this.months(), (month: string) => {
            Column({ space: SunSpacing.sm }) {
              Row() {
                Text(month)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .letterSpacing(1.5)
                  .fontColor(SunColor.pebble)

                Blank().layoutWeight(1)

                Text($r('app.plural.dayroll_month_days', this.entriesForMonth(month).length, this.entriesForMonth(month).length))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(SunColor.pebble)
              }
                .width('100%')
                .height(28)

              ForEach(this.entriesForMonth(month), (entry: RollEntry) => {
                Row({ space: 10 }) {
                  Text(entry.day)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(SunColor.pebble)
                    .width(68)
                  Text(this.moodMark(entry.mood))
                    .fontSize(20)
                    .lineHeight(24)
                    .width(32)
                    .textAlign(TextAlign.Center)
                  Text(entry.line.length === 0 ? '—' : entry.line)
                    .fontSize(13)
                    .fontColor(SunColor.ink)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .height(32)
                .padding({ top: SunSpacing.xs, bottom: SunSpacing.xs })
                .onClick(() => this.editEntry(entry))
              }, (entry: RollEntry) => entry.date)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (month: string) => month)
        }
      }
      .layoutWeight(1)

      if (this.months().length > 1) {
        this.monthIndexStrip()
      }
    }
    .width('100%')
  }

  @Builder
  private monthIndexStrip() {
    Column() {
      ForEach(this.months(), (month: string) => {
        Button(this.monthIndexLabel(month))
          .width(24)
          .height(18)
          .borderRadius(6)
          .backgroundColor(this.selectedMonth === month ? SunColor.ink : SunColor.cream)
          .fontColor(this.selectedMonth === month ? SunColor.cream : (month.startsWith('JANUARY ') ? SunColor.ink : SunColor.pebble))
          .fontSize(9)
          .fontWeight(month.startsWith('JANUARY ') ? FontWeight.Bold : FontWeight.Medium)
          .onClick(() => this.scrollToMonth(month))
      }, (month: string) => month)
    }
    .width(24)
  }

  @Builder
  private exportPreview() {
    if (this.exportOpen && this.proUnlocked) {
      Column({ space: SunSpacing.sm }) {
        Text($r('app.string.dayroll_export_preview_title'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.pebble)

        Row({ space: SunSpacing.sm }) {
          this.formatButton('Plain Text')
          this.formatButton('Markdown')
          this.formatButton('CSV')
        }

        Text(this.exportText())
          .fontSize(12)
          .fontColor(SunColor.ink)
          .lineHeight(18)
          .width('100%')

        SunButton({
          label: $r('app.string.dayroll_share_export'),
          role: SunButtonRole.Secondary,
          action: () => {
            this.shareExportText()
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(SunSpacing.md)
      .backgroundColor('#FFFDF7') // ponytail: tape paper white, no Sun token
      .border({ width: 1, color: '#C8BDAA' }) // ponytail: paper edge tint, no Sun token
    }
  }

  @Builder
  private formatButton(label: string) {
    Button(this.formatDisplay(label))
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.exportFormat === label ? SunColor.ink : '#F5EBD9') // ponytail: pill idle tint, no Sun token
      .fontColor(this.exportFormat === label ? SunColor.cream : SunColor.ink)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .onClick(() => this.exportFormat = label)
  }

  @Builder
  private statsPreview() {
    if (this.statsOpen && this.proUnlocked) {
      Column({ space: SunSpacing.md }) {
        Text($r('app.string.dayroll_stats_title'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(3)
          .fontColor(SunColor.ink)

        Row() {
          this.statPill($r('app.string.dayroll_stat_total'), this.entries.length.toString())
          Blank().layoutWeight(1)
          this.statPill($r('app.string.dayroll_stat_streak'), this.streak().toString())
          Blank().layoutWeight(1)
          this.statPill($r('app.string.dayroll_stat_best'), this.longestStreak().toString())
        }
        .width('100%')

        this.perforation()

        Text($r('app.string.dayroll_stats_days_logged'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.pebble)
          .width('100%')

        ForEach(this.monthlyStats(), (stat: MonthStat) => {
          Row({ space: SunSpacing.sm }) {
            Text(stat.label)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.pebble)
              .width(18)
            Blank()
              .height(8)
              .layoutWeight(Math.max(1, stat.logged))
              .backgroundColor(stat.logged > 0 ? SunColor.ink : '#D8CCBA') // ponytail: empty bar tint, no Sun token
            Blank()
              .height(8)
              .layoutWeight(Math.max(1, this.maxMonthlyLogged() - stat.logged + 1))
            Text(stat.logged.toString())
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.ink)
              .width(22)
          }
          .width('100%')
        }, (stat: MonthStat) => stat.key)

        this.perforation()

        Text($r('app.string.dayroll_stats_mood_trend'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.pebble)
          .width('100%')

        this.moodTrendChart()

        this.perforation()

        Text($r('app.string.dayroll_stats_mood_mix'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.pebble)
          .width('100%')

        ForEach(this.moods, (candidate: string) => {
          Row({ space: SunSpacing.sm }) {
            Text(candidate)
              .fontSize(22)
              .lineHeight(28)
              .width(40)
              .textAlign(TextAlign.Center)
            Text(this.moodCount(candidate).toString())
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.ink)
              .width(26)
            Blank()
              .height(8)
              .layoutWeight(Math.max(1, this.moodCount(candidate)))
              .backgroundColor(SunColor.ink)
            Blank()
              .height(8)
              .layoutWeight(Math.max(1, this.entries.length - this.moodCount(candidate) + 1))
          }
          .width('100%')
        }, (candidate: string) => candidate)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(SunSpacing.md)
      .backgroundColor('#FFFDF7') // ponytail: tape paper white, no Sun token
      .border({ width: 1, color: '#C8BDAA' }) // ponytail: paper edge tint, no Sun token
    }
  }

  @Builder
  private moodTrendChart() {
    Row({ space: SunSpacing.xs }) {
      ForEach(this.monthlyStats(), (stat: MonthStat) => {
        Column({ space: 4 }) {
          Blank()
            .width('100%')
            .height(this.moodTrendHeight(stat.avgMood))
            .backgroundColor(stat.avgMood > 0 ? SunColor.ink : '#D8CCBA') // ponytail: empty bar tint, no Sun token
            .borderRadius(4)

          Text(this.moodForScore(stat.avgMood))
            .fontSize(12)

          Text(stat.label)
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(SunColor.pebble)
        }
        .layoutWeight(1)
        .height(138)
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.Center)
      }, (stat: MonthStat) => stat.key)
    }
    .width('100%')
    .height(142)
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private statPill(label: ResourceStr, value: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(SunColor.ink)
      Text(label)
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)
        .fontColor(SunColor.pebble)
    }
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
        .fontColor(SunColor.ink)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private paywallPanel() {
    if (this.paywallOpen && !this.proUnlocked) {
      Column({ space: SunSpacing.lg }) {
        Text('DAYROLL PRO')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(4)
          .fontColor(SunColor.ink)
          .width('100%')
          .textAlign(TextAlign.Center)

        this.perforation()

        Column({ space: 14 }) {
          this.paywallFeature('↗', $r('app.string.dayroll_paywall_feature_export'))
          this.paywallFeature('▥', $r('app.string.dayroll_paywall_feature_stats'))
          this.paywallFeature('↺', $r('app.string.dayroll_paywall_feature_memories'))
          this.paywallFeature('♥', $r('app.string.dayroll_paywall_feature_indie'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        this.perforation()

        Text($r('app.string.dayroll_paywall_pitch'))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.pebble)
          .lineHeight(17)
          .width('100%')
          .textAlign(TextAlign.Center)

        SunButton({
          label: $r('app.string.dayroll_paywall_unlock'),
          action: () => this.unlockPro()
        })

        Button($r('app.string.dayroll_restore_purchase'))
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(12)
          .fontColor(SunColor.pebble)
          .onClick(() => this.unlockPro())

        Button($r('app.string.dayroll_paywall_close'))
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(12)
          .fontColor(SunColor.pebble)
          .onClick(() => {
            this.paywallOpen = false
            this.paywallIntent = ''
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding(SunSpacing.lg)
      .backgroundColor('#FFFDF7') // ponytail: tape paper white, no Sun token
      .border({ width: 1, color: '#C8BDAA' }) // ponytail: paper edge tint, no Sun token
    }
  }

  @Builder
  private reminderPanel() {
    if (this.reminderOpen) {
      Column({ space: SunSpacing.md }) {
        Text($r('app.string.dayroll_reminder_panel_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
          .fontColor(SunColor.pebble)

        Button($r('app.string.dayroll_reminder_button'))
          .height(42)
          .width('100%')
          .borderRadius(999)
          .backgroundColor(this.reminderEnabled ? SunColor.ink : '#F5EBD9') // ponytail: pill idle tint, no Sun token
          .fontColor(this.reminderEnabled ? SunColor.cream : SunColor.ink)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .onClick(() => {
            if (this.reminderEnabled) {
              this.disableReminder()
            } else {
              this.enableReminder()
            }
          })

        Text(this.reminderTimeLabel())
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.ink)
          .width('100%')
          .textAlign(TextAlign.Center)

        TimePicker({ selected: this.reminderDate() })
          .width('100%')
          .height(120)
          .selectedTextStyle({ color: SunColor.ink, font: { size: 22, weight: FontWeight.Bold } })
          .textStyle({ color: SunColor.pebble, font: { size: 18, weight: FontWeight.Medium } })
          .onChange((value: TimePickerResult) => this.setReminderTime(value.hour, value.minute))

        Text(this.reminderEnabled ? $r('app.string.dayroll_reminder_at_format', this.reminderTimeLabel()) : $r('app.string.dayroll_reminder_paused'))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.2)
          .fontColor(SunColor.pebble)
          .width('100%')
          .textAlign(TextAlign.Center)

      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(SunSpacing.md)
      .backgroundColor('#FFFDF7') // ponytail: tape paper white, no Sun token
      .border({ width: 1, color: '#C8BDAA' }) // ponytail: paper edge tint, no Sun token
    }
  }

  @Builder
  private logBar() {
    Column({ space: SunSpacing.sm }) {
      this.perforation()

      Button('+')
        .width(52)
        .height(52)
        .borderRadius(999)
        .backgroundColor(SunColor.ink)
        .fontColor('#FFFDF7')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .onClick(() => this.composeToday())
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .backgroundColor('#FFFDF7')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      SunSafeRoot({ mode: SunMode.Light }) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            this.topChrome()

            Scroll(this.tapeScroller) {
              Column({ space: SunSpacing.lg }) {
              this.perforation()
              if (this.composerOpen) {
                this.composer()
                this.perforation()
              }
              this.rollList()

              this.reminderPanel()
              this.paywallPanel()
              this.statsPreview()
              this.exportPreview()
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: SunSpacing.sm, bottom: 120 })
            .backgroundColor('#FFFDF7')
            }
            .width('100%')
            .layoutWeight(1)
            .align(Alignment.Top)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          }
          .width('100%')
          .height('100%')

          this.logBar()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
