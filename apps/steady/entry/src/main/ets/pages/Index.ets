import {
  SunButton,
  SunButtonRole,
  SunCard,
  SunColor,
  SunListRow,
  SunSpacing,
  SunToolShell,
  SunType
} from 'sunpebble_ui'
import { appProfile } from '../AppProfile'

interface Reading {
  id: number
  kind: string
  value: string
  unit: string
  context: string
}

interface Medication {
  name: string
  dose: string
  time: string
  taken: boolean
}

@Entry
@Component
struct Index {
  private kinds: string[] = ['Blood pressure', 'Blood glucose', 'Weight', 'Heart rate', 'Blood oxygen']
  @State private tab: string = 'Timeline'
  @State private nextId: number = 4
  @State private selectedKind: string = 'Blood pressure'
  @State private readings: Reading[] = [
    { id: 1, kind: 'Blood pressure', value: '128/84', unit: 'mmHg', context: 'Today · morning' },
    { id: 2, kind: 'Blood glucose', value: '105', unit: 'mg/dL', context: 'Fasting' },
    { id: 3, kind: 'Heart rate', value: '72', unit: 'bpm', context: 'Resting' }
  ]
  @State private meds: Medication[] = [
    { name: 'Metformin', dose: '500mg', time: '08:00', taken: true },
    { name: 'Vitamin D', dose: '1000 IU', time: '20:00', taken: false }
  ]

  private logReading(): void {
    const value = this.valueForKind(this.selectedKind)
    this.readings = [
      {
        id: this.nextId,
        kind: this.selectedKind,
        value: value.value,
        unit: value.unit,
        context: 'Just now'
      },
      ...this.readings
    ]
    this.nextId += 1
  }

  private valueForKind(kind: string): Reading {
    if (kind === 'Blood glucose') {
      return { id: 0, kind, value: '108', unit: 'mg/dL', context: '' }
    }
    if (kind === 'Weight') {
      return { id: 0, kind, value: '154', unit: 'lb', context: '' }
    }
    if (kind === 'Heart rate') {
      return { id: 0, kind, value: '74', unit: 'bpm', context: '' }
    }
    if (kind === 'Blood oxygen') {
      return { id: 0, kind, value: '98', unit: '%', context: '' }
    }
    return { id: 0, kind, value: '126/82', unit: 'mmHg', context: '' }
  }

  private toggleMed(target: Medication): void {
    this.meds = this.meds.map((med: Medication, i: number) => {
      if (med.name !== target.name || med.time !== target.time) {
        return med
      }
      return { name: med.name, dose: med.dose, time: med.time, taken: !med.taken }
    })
  }

  private addMedication(): void {
    this.meds = [...this.meds, { name: 'Medication', dose: 'Dose', time: '21:00', taken: false }]
  }

  private readingsForKind(kind: string): Reading[] {
    return this.readings.filter((reading: Reading) => reading.kind === kind)
  }

  private csvPreview(): string {
    return this.readings.map((reading: Reading) => {
      return `${reading.kind},${reading.value},${reading.unit}`
    }).join('\n')
  }

  @Builder
  private tabButton(label: string) {
    Button(label)
      .height(36)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.tab === label ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.tab = label)
  }

  @Builder
  private kindButton(kind: string) {
    Button(kind)
      .height(36)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.selectedKind === kind ? SunColor.ink : SunColor.white)
      .fontColor(this.selectedKind === kind ? SunColor.cream : SunColor.ink)
      .fontSize(12)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.selectedKind = kind)
  }

  @Builder
  private quickLogCard() {
    SunCard() {
      Column({ space: SunSpacing.md }) {
        Text('QUICK LOG')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.4)
          .fontColor(SunColor.pebble)

        Scroll() {
          Row({ space: SunSpacing.sm }) {
            ForEach(this.kinds, (kind: string) => {
              this.kindButton(kind)
            }, (kind: string) => kind)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(44)

        SunButton({
          label: `Save ${this.selectedKind}`,
          action: () => this.logReading()
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private timeline() {
    Column({ space: SunSpacing.md }) {
      this.quickLogCard()

      SunCard() {
        Column() {
          if (this.readings.length === 0) {
            Text('Log your first reading with the + button.')
              .fontSize(SunType.body)
              .fontColor(SunColor.pebble)
          } else {
            ForEach(this.readings, (reading: Reading) => {
              SunListRow({
                title: `${reading.value} ${reading.unit}`,
                caption: `${reading.kind} · ${reading.context}`
              })
            }, (reading: Reading) => reading.id.toString())
          }
        }
        .width('100%')
      }
    }
  }

  @Builder
  private trends() {
    Column({ space: SunSpacing.md }) {
      SunCard() {
        Column({ space: SunSpacing.md }) {
          Text('TRENDS')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          ForEach(this.kinds.slice(0, 4), (kind: string) => {
            Row({ space: SunSpacing.md }) {
              Text(kind)
                .fontSize(SunType.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(SunColor.ink)
                .layoutWeight(1)
              Text(`${this.readingsForKind(kind).length} logs`)
                .fontSize(SunType.body)
                .fontColor(SunColor.pebble)
            }
            .width('100%')
            .height(42)
          }, (kind: string) => kind)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
  }

  @Builder
  private medsView() {
    Column({ space: SunSpacing.md }) {
      SunCard() {
        Column({ space: SunSpacing.sm }) {
          Text('TODAY')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          ForEach(this.meds, (med: Medication) => {
            Row({ space: SunSpacing.md }) {
              Column({ space: SunSpacing.xs }) {
                Text(`${med.name} · ${med.time}`)
                  .fontSize(SunType.body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(SunColor.ink)
                Text(med.dose)
                  .fontSize(SunType.caption)
                  .fontColor(SunColor.pebble)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Button(med.taken ? 'Taken' : 'Due')
                .height(34)
                .padding({ left: 12, right: 12 })
                .borderRadius(999)
                .backgroundColor(med.taken ? SunColor.sun : SunColor.white)
                .fontColor(SunColor.ink)
                .border({ width: 1, color: SunColor.border })
                .onClick(() => this.toggleMed(med))
            }
            .width('100%')
            .height(58)
          }, (med: Medication) => `${med.name}-${med.time}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      SunButton({
        label: 'Add medication',
        role: SunButtonRole.Secondary,
        action: () => this.addMedication()
      })
    }
  }

  @Builder
  private settings() {
    Column({ space: SunSpacing.md }) {
      SunCard() {
        Column() {
          SunListRow({
            title: 'Doctor report',
            caption: 'Readings, medication adherence, and symptoms.'
          })
          SunListRow({
            title: 'Export CSV',
            caption: this.csvPreview()
          })
          SunListRow({
            title: 'Measurement reminder',
            value: '09:30',
            caption: 'Take a minute to log your readings.'
          })
        }
        .width('100%')
      }

      Text('Steady is a record-keeping tool, not a medical device. It does not diagnose, treat, or give medical advice.')
        .fontSize(12)
        .fontColor(SunColor.pebble)
        .lineHeight(18)
    }
  }

  build() {
    Column() {
      SunToolShell({
        manifest: appProfile,
        onPrimaryAction: () => this.logReading()
      }) {
        Column({ space: SunSpacing.md }) {
          Scroll() {
            Row({ space: SunSpacing.sm }) {
              this.tabButton('Timeline')
              this.tabButton('Trends')
              this.tabButton('Meds')
              this.tabButton('Settings')
            }
          }
          .width('100%')
          .height(44)
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)

          Scroll() {
            if (this.tab === 'Timeline') {
              this.timeline()
            } else if (this.tab === 'Trends') {
              this.trends()
            } else if (this.tab === 'Meds') {
              this.medsView()
            } else {
              this.settings()
            }
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
