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

@Entry
@Component
struct Index {
  private moods: string[] = ['😄', '🙂', '😐', '😞', '😣']
  @State private mood: string = '😐'
  @State private draftLine: string = ''
  @State private entries: RollEntry[] = []
  @State private exportOpen: boolean = false

  private saveToday(): void {
    const line = this.draftLine.trim()
    if (line.length === 0) {
      return
    }
    const today: RollEntry = { day: 'TODAY', month: 'JULY 2026', mood: this.mood, line }
    const rest = this.entries.filter((entry: RollEntry) => entry.day !== 'TODAY')
    this.entries = [today, ...rest]
    this.draftLine = ''
  }

  private deleteToday(): void {
    this.entries = this.entries.filter((entry: RollEntry) => entry.day !== 'TODAY')
  }

  private streak(): number {
    return this.entries.length
  }

  private exportText(): string {
    if (this.entries.length === 0) {
      return 'No entries yet.'
    }
    return this.entries.map((entry: RollEntry) => {
      return `${entry.day} ${entry.mood} ${entry.line}`
    }).join('\n')
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
