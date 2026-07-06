import {
  SunButton,
  SunButtonRole,
  SunColor,
  SunSpacing,
  SunToolShell
} from 'sunpebble_ui'
import { appProfile } from '../AppProfile'

interface RollEntry {
  day: string
  month: string
  mood: string
  line: string
}

PersistentStorage.persistProp('dayroll.mood.v1', '😐')
PersistentStorage.persistProp('dayroll.entries.v1', '')
PersistentStorage.persistProp('dayroll.exportOpen.v1', false)
PersistentStorage.persistProp('dayroll.statsOpen.v1', false)
PersistentStorage.persistProp('dayroll.exportFormat.v1', 'Plain Text')
PersistentStorage.persistProp('dayroll.reminderOpen.v1', false)
PersistentStorage.persistProp('dayroll.reminderEnabled.v1', false)
PersistentStorage.persistProp('dayroll.reminderHour.v1', 21)

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
  @State private draftLine: string = ''
  @State private entries: RollEntry[] = []

  aboutToAppear(): void {
    this.loadEntries()
  }

  private loadEntries(): void {
    if (this.entriesJson.length === 0) {
      return
    }
    try {
      this.entries = JSON.parse(this.entriesJson) as RollEntry[]
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
    if (line.length === 0) {
      return
    }
    const today: RollEntry = { day: 'TODAY', month: 'JULY 2026', mood: this.mood, line }
    const rest = this.entries.filter((entry: RollEntry) => entry.day !== 'TODAY')
    this.entries = [today, ...rest]
    this.draftLine = ''
    this.saveEntries()
  }

  private deleteToday(): void {
    this.entries = this.entries.filter((entry: RollEntry) => entry.day !== 'TODAY')
    this.saveEntries()
  }

  private streak(): number {
    return this.entries.length
  }

  private longestStreak(): number {
    return this.entries.length
  }

  private moodCount(mood: string): number {
    return this.entries.filter((entry: RollEntry) => entry.mood === mood).length
  }

  private exportText(): string {
    if (this.entries.length === 0) {
      return 'No entries yet.'
    }
    if (this.exportFormat === 'Markdown') {
      return this.entries.map((entry: RollEntry) => {
        return `- **${entry.day}** ${entry.mood} ${entry.line}`
      }).join('\n')
    }
    if (this.exportFormat === 'CSV') {
      const rows = this.entries.map((entry: RollEntry) => {
        return `${entry.day},${entry.mood},${entry.line.replaceAll('"', '""')}`
      })
      return ['day,mood,line', ...rows].join('\n')
    }
    return this.entries.map((entry: RollEntry) => {
      return `${entry.day} ${entry.mood} ${entry.line}`
    }).join('\n')
  }

  private testReminder(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: 'One line about today?',
        duration: 2000
      })
    } catch (_error) {
      // ponytail: toast is best-effort; persisted reminder settings are the fallback.
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
      Text('TODAY')
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

      TextInput({ placeholder: 'One line about today...', text: this.draftLine })
        .height(52)
        .fontSize(15)
        .fontColor(SunColor.ink)
        .placeholderColor(SunColor.pebble)
        .backgroundColor('#FFFDF7')
        .borderRadius(8)
        .border({ width: 1, color: '#C8BDAA' })
        .onChange((value: string) => this.draftLine = value)

      Row({ space: SunSpacing.md }) {
        SunButton({
          label: 'Save',
          action: () => this.saveToday()
        })

        SunButton({
          label: 'Delete Today',
          role: SunButtonRole.Danger,
          action: () => this.deleteToday()
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private rollList() {
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
        Text(this.entries[0].month)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .fontColor(SunColor.pebble)
          .width('100%')

        ForEach(this.entries, (entry: RollEntry) => {
          Row({ space: 10 }) {
            Text(entry.day)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.pebble)
              .width(68)
            Text(entry.mood)
              .fontSize(14)
            Text(entry.line)
              .fontSize(13)
              .fontColor(SunColor.ink)
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ top: SunSpacing.xs, bottom: SunSpacing.xs })
        }, (entry: RollEntry) => `${entry.day}-${entry.line}`)
      }
    }
    .width('100%')
  }

  @Builder
  private exportPreview() {
    if (this.exportOpen) {
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
    if (this.statsOpen) {
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

        Text('MOOD MIX · ALL TIME')
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

        Button(this.reminderEnabled ? 'Reminder On' : 'Reminder Off')
          .height(42)
          .width('100%')
          .borderRadius(999)
          .backgroundColor(this.reminderEnabled ? SunColor.ink : '#F5EBD9')
          .fontColor(this.reminderEnabled ? SunColor.cream : SunColor.ink)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .onClick(() => this.reminderEnabled = !this.reminderEnabled)

        Row({ space: SunSpacing.sm }) {
          this.reminderHourButton(20)
          this.reminderHourButton(21)
          this.reminderHourButton(22)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Text(this.reminderEnabled ? `REMIND ME AT ${this.reminderHour}:00` : 'REMINDER PAUSED')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.2)
          .fontColor(SunColor.pebble)
          .width('100%')
          .textAlign(TextAlign.Center)

        SunButton({
          label: 'Test Reminder',
          role: SunButtonRole.Secondary,
          action: () => this.testReminder()
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
  private reminderHourButton(hour: number) {
    Button(`${hour}:00`)
      .height(34)
      .padding({ left: 14, right: 14 })
      .borderRadius(999)
      .backgroundColor(this.reminderHour === hour ? SunColor.ink : '#F5EBD9')
      .fontColor(this.reminderHour === hour ? SunColor.cream : SunColor.ink)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .onClick(() => this.reminderHour = hour)
  }

  build() {
    Column() {
      SunToolShell({
        manifest: appProfile,
        onPrimaryAction: () => this.saveToday()
      }) {
        Scroll() {
          Column({ space: SunSpacing.lg }) {
            this.header()
            this.perforation()
            this.composer()
            this.perforation()
            this.rollList()
            this.perforation()

            SunButton({
              label: this.reminderOpen ? 'Hide Reminder' : 'Reminder',
              role: SunButtonRole.Secondary,
              action: () => this.reminderOpen = !this.reminderOpen
            })
            this.reminderPanel()

            SunButton({
              label: this.statsOpen ? 'Hide Stats' : 'Stats',
              role: SunButtonRole.Secondary,
              action: () => this.statsOpen = !this.statsOpen
            })
            this.statsPreview()

            SunButton({
              label: this.exportOpen ? 'Hide Export' : 'Export',
              role: SunButtonRole.Secondary,
              action: () => this.exportOpen = !this.exportOpen
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
    }
    .width('100%')
    .height('100%')
  }
}
