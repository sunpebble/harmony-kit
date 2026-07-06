import {
  SunButton,
  SunButtonRole,
  SunColor,
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
PersistentStorage.persistProp('dayroll.reminderOpen.v1', false)
PersistentStorage.persistProp('dayroll.reminderEnabled.v1', false)
PersistentStorage.persistProp('dayroll.reminderHour.v1', 21)
PersistentStorage.persistProp('dayroll.reminderMinute.v1', 0)
PersistentStorage.persistProp('dayroll.proUnlocked.v1', false)

@Entry
@Component
struct Index {
  private moods: string[] = ['😄', '🙂', '😐', '😞', '😣']
  @StorageLink('dayroll.mood.v1') private mood: string = '😐'
  @StorageLink('dayroll.entries.v1') private entriesJson: string = ''
  @StorageLink('dayroll.exportOpen.v1') private exportOpen: boolean = false
  @StorageLink('dayroll.statsOpen.v1') private statsOpen: boolean = false
  @StorageLink('dayroll.exportFormat.v1') private exportFormat: string = 'Plain Text'
  @StorageLink('dayroll.reminderOpen.v1') private reminderOpen: boolean = false
  @StorageLink('dayroll.reminderEnabled.v1') private reminderEnabled: boolean = false
  @StorageLink('dayroll.reminderHour.v1') private reminderHour: number = 21
  @StorageLink('dayroll.reminderMinute.v1') private reminderMinute: number = 0
  @StorageLink('dayroll.proUnlocked.v1') private proUnlocked: boolean = false
  @State private draftLine: string = ''
  @State private editingDate: string = ''
  @State private confirmingDelete: boolean = false
  @State private composerOpen: boolean = false
  @State private selectedMonth: string = ''
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
    const line = this.draftLine.trim()
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
      line: entry.line
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

  private visibleMonths(): string[] {
    const months = this.months()
    return this.selectedMonth.length > 0 && months.includes(this.selectedMonth) ? [this.selectedMonth] : months
  }

  private toggleMonth(month: string): void {
    this.selectedMonth = this.selectedMonth === month ? '' : month
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

  private memoryAge(entry: RollEntry): string {
    const years = Math.max(1, this.dateFromKey(this.activeDate()).getFullYear() - this.dateFromKey(entry.date).getFullYear())
    return years === 1 ? '1 YR AGO' : `${years} YRS AGO`
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

  private async scheduleDailyReminder(): Promise<void> {
    try {
      if (!await this.requestNotificationAccess()) {
        this.reminderEnabled = false
        this.showToast('Enable notifications to use daily reminders.')
        return
      }
      await reminderAgentManager.cancelAllReminders()
      const request: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: this.reminderHour,
        minute: this.reminderMinute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: 'Dayroll',
        content: 'One line about today?',
        expiredContent: 'Dayroll reminder missed.',
        notificationId: 1001,
        tapDismissed: true
      }
      await reminderAgentManager.publishReminder(request)
      this.reminderEnabled = true
      this.showToast(`Daily reminder set for ${this.reminderTimeLabel()}.`)
    } catch (_error) {
      this.reminderEnabled = false
      this.showToast('Enable notifications to use daily reminders.')
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
    this.showToast('Daily reminder off.')
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

  private showToast(message: string): void {
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
      this.scheduleDailyReminder()
    }
  }

  private unlockPro(): void {
    this.proUnlocked = true
    this.showToast('Dayroll Pro unlocked on this device.')
  }

  private toggleStats(): void {
    if (!this.proUnlocked) {
      this.statsOpen = false
      this.showToast('Dayroll Pro unlocks stats and yearly review.')
      return
    }
    this.statsOpen = !this.statsOpen
  }

  private toggleExport(): void {
    if (!this.proUnlocked) {
      this.exportOpen = false
      this.showToast('Dayroll Pro unlocks text, Markdown, and CSV export.')
      return
    }
    this.exportOpen = !this.exportOpen
  }

  private async copyExportText(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.exportText())
      await pasteboard.getSystemPasteboard().setData(data)
      this.showToast(`${this.exportFormat} copied.`)
    } catch (_error) {
      this.showToast('Copy failed.')
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
          .backgroundColor('#C8BDAA')
      }, (item: number) => item.toString())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private header() {
    Column({ space: SunSpacing.sm }) {
      Text('DAYROLL')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(6)
        .fontColor(SunColor.ink)

      Text('* ONE LINE A DAY *')
        .fontSize(11)
        .letterSpacing(1.5)
        .fontColor(SunColor.pebble)

      Row() {
        Text(`TOTAL DAYS: ${this.entries.length}`)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.pebble)
        Blank().layoutWeight(1)
        Text(`STREAK: ${this.streak()}`)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.pebble)
      }
      .width('100%')
      .padding({ top: SunSpacing.sm })
    }
    .width('100%')
  }

  @Builder
  private composer() {
    Column({ space: SunSpacing.md }) {
      Text(this.composerTitle())
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(SunColor.pebble)

      Row({ space: SunSpacing.md }) {
        ForEach(this.moods, (candidate: string) => {
          Button(candidate)
            .width(46)
            .height(46)
            .borderRadius(999)
            .backgroundColor(this.mood === candidate ? SunColor.ink : '#F5EBD9')
            .fontColor(this.mood === candidate ? SunColor.cream : SunColor.ink)
            .fontSize(22)
            .onClick(() => this.mood = candidate)
        }, (candidate: string) => candidate)
      }

      TextInput({ placeholder: 'One line about today…', text: this.draftLine })
        .height(52)
        .fontSize(15)
        .fontColor(SunColor.ink)
        .placeholderColor(SunColor.pebble)
        .backgroundColor('#FFFDF7')
        .borderRadius(8)
        .border({ width: 1, color: '#C8BDAA' })
        .onChange((value: string) => this.draftLine = value)

      if (this.memories().length > 0) {
        Column({ space: SunSpacing.sm }) {
          Text('ON THIS DAY')
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
                .fontSize(13)

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
        Text('Delete this day?')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.pebble)

        Row({ space: SunSpacing.md }) {
          SunButton({
            label: 'Delete',
            role: SunButtonRole.Danger,
            action: () => this.deleteToday()
          })

          SunButton({
            label: 'Cancel',
            role: SunButtonRole.Secondary,
            action: () => this.confirmingDelete = false
          })
        }
      } else {
        Row({ space: SunSpacing.md }) {
          SunButton({
            label: 'Save',
            action: () => this.saveToday()
          })

          SunButton({
            label: 'Cancel',
            role: SunButtonRole.Secondary,
            action: () => this.cancelComposer()
          })
        }

        if (this.hasActiveEntry()) {
          SunButton({
            label: 'DELETE THIS DAY',
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
          Text('NO ENTRIES YET\nTAP + TO LOG TODAY')
            .fontSize(13)
            .fontColor(SunColor.pebble)
            .textAlign(TextAlign.Center)
            .lineHeight(22)
            .width('100%')
            .padding({ top: 30, bottom: 30 })
        } else {
          ForEach(this.visibleMonths(), (month: string) => {
            Column({ space: SunSpacing.sm }) {
              Row() {
                Text(month)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .letterSpacing(1.5)
                  .fontColor(SunColor.pebble)

                Blank().layoutWeight(1)

                Text(`${this.entriesForMonth(month).length} DAYS`)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(SunColor.pebble)
              }
                .width('100%')

              ForEach(this.entriesForMonth(month), (entry: RollEntry) => {
                Row({ space: 10 }) {
                  Text(entry.day)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(SunColor.pebble)
                    .width(68)
                  Text(this.moodMark(entry.mood))
                    .fontSize(14)
                  Text(entry.line.length === 0 ? '—' : entry.line)
                    .fontSize(13)
                    .fontColor(SunColor.ink)
                    .layoutWeight(1)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
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
          .onClick(() => this.toggleMonth(month))
      }, (month: string) => month)
    }
    .width(24)
  }

  @Builder
  private exportPreview() {
    if (this.exportOpen && this.proUnlocked) {
      Column({ space: SunSpacing.sm }) {
        Text('EXPORT PREVIEW')
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
          label: 'Share Export',
          role: SunButtonRole.Secondary,
          action: () => {
            this.shareExportText()
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(SunSpacing.md)
      .backgroundColor('#FFFDF7')
      .border({ width: 1, color: '#C8BDAA' })
    }
  }

  @Builder
  private formatButton(label: string) {
    Button(label)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.exportFormat === label ? SunColor.ink : '#F5EBD9')
      .fontColor(this.exportFormat === label ? SunColor.cream : SunColor.ink)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .onClick(() => this.exportFormat = label)
  }

  @Builder
  private statsPreview() {
    if (this.statsOpen && this.proUnlocked) {
      Column({ space: SunSpacing.md }) {
        Text('YOUR TAPE, COUNTED')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(3)
          .fontColor(SunColor.ink)

        Row() {
          this.statPill('TOTAL', this.entries.length.toString())
          Blank().layoutWeight(1)
          this.statPill('STREAK', this.streak().toString())
          Blank().layoutWeight(1)
          this.statPill('BEST', this.longestStreak().toString())
        }
        .width('100%')

        this.perforation()

        Text('DAYS LOGGED — LAST 12 MONTHS')
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
              .backgroundColor(stat.logged > 0 ? SunColor.ink : '#D8CCBA')
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

        Text('MOOD TREND — LAST 12 MONTHS')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.pebble)
          .width('100%')

        Row({ space: SunSpacing.sm }) {
          ForEach(this.monthlyStats(), (stat: MonthStat) => {
            Column({ space: 4 }) {
              Text(this.moodForScore(stat.avgMood))
                .fontSize(14)
              Text(stat.label)
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor(SunColor.pebble)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }, (stat: MonthStat) => stat.key)
        }
        .width('100%')

        this.perforation()

        Text('MOOD MIX — ALL TIME')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.pebble)
          .width('100%')

        ForEach(this.moods, (candidate: string) => {
          Row({ space: SunSpacing.sm }) {
            Text(candidate)
              .fontSize(18)
              .width(34)
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
      .backgroundColor('#FFFDF7')
      .border({ width: 1, color: '#C8BDAA' })
    }
  }

  @Builder
  private statPill(label: string, value: string) {
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
  private reminderPanel() {
    if (this.reminderOpen) {
      Column({ space: SunSpacing.md }) {
        Text('DAILY REMINDER')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
          .fontColor(SunColor.pebble)

        Button('REMIND ME TO LOG')
          .height(42)
          .width('100%')
          .borderRadius(999)
          .backgroundColor(this.reminderEnabled ? SunColor.ink : '#F5EBD9')
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

        Text(this.reminderEnabled ? `REMIND ME AT ${this.reminderTimeLabel()}` : 'REMINDER PAUSED')
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
      .backgroundColor('#FFFDF7')
      .border({ width: 1, color: '#C8BDAA' })
    }
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: SunSpacing.lg }) {
          this.header()
          this.perforation()
          if (this.composerOpen) {
            this.composer()
            this.perforation()
          }
          this.rollList()
          this.perforation()

          Button('+')
            .width(52)
            .height(52)
            .borderRadius(999)
            .backgroundColor(SunColor.ink)
            .fontColor('#FFFDF7')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .alignSelf(ItemAlign.Center)
            .onClick(() => this.composeToday())

          SunButton({
            label: this.reminderOpen ? 'Hide Reminder' : 'Reminder',
            role: SunButtonRole.Secondary,
            action: () => this.reminderOpen = !this.reminderOpen
          })
          this.reminderPanel()

          if (!this.proUnlocked) {
            SunButton({
              label: 'Unlock Pro',
              role: SunButtonRole.Secondary,
              action: () => this.unlockPro()
            })
          }

          SunButton({
            label: this.statsOpen ? 'Hide Stats' : 'Stats',
            role: SunButtonRole.Secondary,
            action: () => this.toggleStats()
          })
          this.statsPreview()

          SunButton({
            label: this.exportOpen ? 'Hide Export' : 'Export',
            role: SunButtonRole.Secondary,
            action: () => this.toggleExport()
          })
          this.exportPreview()
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFDF7')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SunColor.cream)
  }
}
