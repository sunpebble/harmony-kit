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

interface Symptom {
  id: number
  name: string
  severity: number
  context: string
}

PersistentStorage.persistProp('steady.tab.v1', 'Timeline')
PersistentStorage.persistProp('steady.nextId.v1', 4)
PersistentStorage.persistProp('steady.selectedKind.v1', 'Blood pressure')
PersistentStorage.persistProp('steady.draftPrimary.v1', '')
PersistentStorage.persistProp('steady.draftSecondary.v1', '')
PersistentStorage.persistProp('steady.draftNote.v1', '')
PersistentStorage.persistProp('steady.readings.v1', '')
PersistentStorage.persistProp('steady.meds.v1', '')
PersistentStorage.persistProp('steady.symptoms.v1', '')
PersistentStorage.persistProp('steady.reminderEnabled.v1', false)
PersistentStorage.persistProp('steady.reminderHour.v1', 8)
PersistentStorage.persistProp('steady.reminderMinute.v1', 0)
PersistentStorage.persistProp('steady.targetBpLow.v1', '')
PersistentStorage.persistProp('steady.targetBpHigh.v1', '')
PersistentStorage.persistProp('steady.targetGlucoseLow.v1', '')
PersistentStorage.persistProp('steady.targetGlucoseHigh.v1', '')
PersistentStorage.persistProp('steady.targetWeightLow.v1', '')
PersistentStorage.persistProp('steady.targetWeightHigh.v1', '')

@Entry
@Component
struct Index {
  private kinds: string[] = ['Blood pressure', 'Blood glucose', 'Weight', 'Heart rate', 'Blood oxygen']
  @StorageLink('steady.tab.v1') private tab: string = 'Timeline'
  @StorageLink('steady.nextId.v1') private nextId: number = 4
  @StorageLink('steady.selectedKind.v1') private selectedKind: string = 'Blood pressure'
  @StorageLink('steady.draftPrimary.v1') private draftPrimary: string = ''
  @StorageLink('steady.draftSecondary.v1') private draftSecondary: string = ''
  @StorageLink('steady.draftNote.v1') private draftNote: string = ''
  @StorageLink('steady.readings.v1') private readingsJson: string = ''
  @StorageLink('steady.meds.v1') private medsJson: string = ''
  @StorageLink('steady.symptoms.v1') private symptomsJson: string = ''
  @StorageLink('steady.reminderEnabled.v1') private reminderEnabled: boolean = false
  @StorageLink('steady.reminderHour.v1') private reminderHour: number = 8
  @StorageLink('steady.reminderMinute.v1') private reminderMinute: number = 0
  @StorageLink('steady.targetBpLow.v1') private targetBpLow: string = ''
  @StorageLink('steady.targetBpHigh.v1') private targetBpHigh: string = ''
  @StorageLink('steady.targetGlucoseLow.v1') private targetGlucoseLow: string = ''
  @StorageLink('steady.targetGlucoseHigh.v1') private targetGlucoseHigh: string = ''
  @StorageLink('steady.targetWeightLow.v1') private targetWeightLow: string = ''
  @StorageLink('steady.targetWeightHigh.v1') private targetWeightHigh: string = ''
  @State private readings: Reading[] = []
  @State private meds: Medication[] = []
  @State private medName: string = ''
  @State private medDose: string = ''
  @State private medTime: string = '08:00'
  @State private symptoms: Symptom[] = []
  @State private symptomName: string = ''
  @State private symptomSeverity: number = 1
  @State private symptomNote: string = ''

  aboutToAppear(): void {
    this.loadReadings()
    this.loadMeds()
    this.loadSymptoms()
  }

  private defaultReadings(): Reading[] {
    return [
      { id: 1, kind: 'Blood pressure', value: '128/84', unit: 'mmHg', context: 'Today · morning' },
      { id: 2, kind: 'Blood glucose', value: '105', unit: 'mg/dL', context: 'Fasting' },
      { id: 3, kind: 'Heart rate', value: '72', unit: 'bpm', context: 'Resting' }
    ]
  }

  private defaultMeds(): Medication[] {
    return [
      { name: 'Metformin', dose: '500mg', time: '08:00', taken: true },
      { name: 'Vitamin D', dose: '1000 IU', time: '20:00', taken: false }
    ]
  }

  private loadReadings(): void {
    if (this.readingsJson.length === 0) {
      this.readings = this.defaultReadings()
      this.saveReadings()
      return
    }
    try {
      const parsed = JSON.parse(this.readingsJson) as Reading[]
      this.readings = parsed.length > 0 ? parsed : this.defaultReadings()
    } catch (_error) {
      this.readings = this.defaultReadings()
      this.saveReadings()
    }
  }

  private loadMeds(): void {
    if (this.medsJson.length === 0) {
      this.meds = this.defaultMeds()
      this.saveMeds()
      return
    }
    try {
      const parsed = JSON.parse(this.medsJson) as Medication[]
      this.meds = parsed.length > 0 ? parsed : this.defaultMeds()
    } catch (_error) {
      this.meds = this.defaultMeds()
      this.saveMeds()
    }
  }

  private loadSymptoms(): void {
    if (this.symptomsJson.length === 0) {
      return
    }
    try {
      this.symptoms = JSON.parse(this.symptomsJson) as Symptom[]
    } catch (_error) {
      this.symptoms = []
      this.saveSymptoms()
    }
  }

  private saveReadings(): void {
    this.readingsJson = JSON.stringify(this.readings)
  }

  private saveMeds(): void {
    this.medsJson = JSON.stringify(this.meds)
  }

  private saveSymptoms(): void {
    this.symptomsJson = JSON.stringify(this.symptoms)
  }

  private logReading(): void {
    const primary = Number(this.draftPrimary)
    const secondary = Number(this.draftSecondary)
    if (this.selectedKind === 'Blood pressure') {
      if (!(primary > 0) || !(secondary > 0)) {
        this.showToast('Enter systolic and diastolic first.')
        return
      }
    } else if (!(primary > 0)) {
      this.showToast('Enter a value first.')
      return
    }

    const note = this.draftNote.trim()
    this.readings = [
      {
        id: this.nextId,
        kind: this.selectedKind,
        value: this.selectedKind === 'Blood pressure'
          ? `${this.cleanNumber(primary)}/${this.cleanNumber(secondary)}`
          : this.cleanNumber(primary),
        unit: this.unitForKind(this.selectedKind),
        context: note.length > 0 ? note : 'Just now'
      },
      ...this.readings
    ]
    this.nextId += 1
    this.draftNote = ''
    this.saveReadings()
  }

  private cleanNumber(value: number): string {
    const rounded = Math.round(value * 10) / 10
    return Math.round(rounded) === rounded ? Math.round(rounded).toString() : rounded.toString()
  }

  private unitForKind(kind: string): string {
    if (kind === 'Blood glucose') {
      return 'mg/dL'
    }
    if (kind === 'Weight') {
      return 'lb'
    }
    if (kind === 'Heart rate') {
      return 'bpm'
    }
    if (kind === 'Blood oxygen') {
      return '%'
    }
    return 'mmHg'
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 1800 })
    } catch (_error) {
      // ponytail: validation still blocks the bad save if toast is unavailable.
    }
  }

  private toggleMed(target: Medication): void {
    this.meds = this.meds.map((med: Medication, i: number) => {
      if (med.name !== target.name || med.time !== target.time) {
        return med
      }
      return { name: med.name, dose: med.dose, time: med.time, taken: !med.taken }
    })
    this.saveMeds()
  }

  private addMedication(): void {
    const name = this.medName.trim()
    if (name.length === 0) {
      this.showToast('Enter medication name first.')
      return
    }
    this.meds = [
      ...this.meds,
      {
        name,
        dose: this.medDose.trim().length > 0 ? this.medDose.trim() : 'Dose',
        time: this.medTime,
        taken: false
      }
    ]
    this.medName = ''
    this.medDose = ''
    this.saveMeds()
  }

  private logSymptom(): void {
    const name = this.symptomName.trim()
    if (name.length === 0) {
      this.showToast('Enter symptom first.')
      return
    }
    this.symptoms = [
      {
        id: this.nextId,
        name,
        severity: this.symptomSeverity,
        context: this.symptomNote.trim().length > 0 ? this.symptomNote.trim() : 'Just now'
      },
      ...this.symptoms
    ]
    this.nextId += 1
    this.symptomName = ''
    this.symptomNote = ''
    this.saveSymptoms()
  }

  private readingsForKind(kind: string): Reading[] {
    return this.readings.filter((reading: Reading) => reading.kind === kind)
  }

  private targetLowForKind(kind: string): string {
    if (kind === 'Blood pressure') {
      return this.targetBpLow
    }
    if (kind === 'Blood glucose') {
      return this.targetGlucoseLow
    }
    if (kind === 'Weight') {
      return this.targetWeightLow
    }
    return ''
  }

  private targetHighForKind(kind: string): string {
    if (kind === 'Blood pressure') {
      return this.targetBpHigh
    }
    if (kind === 'Blood glucose') {
      return this.targetGlucoseHigh
    }
    if (kind === 'Weight') {
      return this.targetWeightHigh
    }
    return ''
  }

  private setTargetLow(kind: string, value: string): void {
    if (kind === 'Blood pressure') {
      this.targetBpLow = value
    } else if (kind === 'Blood glucose') {
      this.targetGlucoseLow = value
    } else if (kind === 'Weight') {
      this.targetWeightLow = value
    }
  }

  private setTargetHigh(kind: string, value: string): void {
    if (kind === 'Blood pressure') {
      this.targetBpHigh = value
    } else if (kind === 'Blood glucose') {
      this.targetGlucoseHigh = value
    } else if (kind === 'Weight') {
      this.targetWeightHigh = value
    }
  }

  private hasTargetRange(kind: string): boolean {
    const lowText = this.targetLowForKind(kind).trim()
    const highText = this.targetHighForKind(kind).trim()
    return lowText.length > 0 && highText.length > 0 && Number(highText) > Number(lowText)
  }

  private readingNumber(reading: Reading): number {
    return Number(reading.value.split('/')[0])
  }

  private targetRangeLabel(kind: string): string {
    if (!this.hasTargetRange(kind)) {
      return 'Not set'
    }
    return `${this.targetLowForKind(kind)}-${this.targetHighForKind(kind)} ${this.unitForKind(kind)}`
  }

  private trendSummary(kind: string): string {
    const readings = this.readingsForKind(kind)
    if (readings.length === 0 || !this.hasTargetRange(kind)) {
      return `${readings.length} logs`
    }
    const low = Number(this.targetLowForKind(kind))
    const high = Number(this.targetHighForKind(kind))
    const inRange = readings.filter((reading: Reading) => {
      const value = this.readingNumber(reading)
      return value >= low && value <= high
    }).length
    return `${inRange} of ${readings.length} in range`
  }

  private csvPreview(): string {
    const readingRows = this.readings.map((reading: Reading) => {
      return `${reading.kind},${reading.value},${reading.unit}`
    })
    const symptomRows = this.symptoms.map((symptom: Symptom) => {
      return `Symptom,${symptom.name},severity ${symptom.severity}`
    })
    return [...readingRows, ...symptomRows].join('\n')
  }

  private reminderLabel(): string {
    if (!this.reminderEnabled) {
      return 'Paused'
    }
    return `${this.pad(this.reminderHour)}:${this.pad(this.reminderMinute)}`
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private testMeasurementReminder(): void {
    this.showToast('Measurement time: take a minute to log your readings.')
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
  private medTimeButton(time: string) {
    Button(time)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.medTime === time ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.medTime = time)
  }

  @Builder
  private symptomSeverityButton(label: string, severity: number) {
    Button(label)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.symptomSeverity === severity ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.symptomSeverity = severity)
  }

  @Builder
  private reminderTimeButton(label: string, hour: number, minute: number) {
    Button(label)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.reminderHour === hour && this.reminderMinute === minute ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => {
        this.reminderHour = hour
        this.reminderMinute = minute
      })
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

        if (this.selectedKind === 'Blood pressure') {
          Row({ space: SunSpacing.sm }) {
            TextInput({ placeholder: 'Systolic', text: this.draftPrimary })
              .height(46)
              .layoutWeight(1)
              .fontSize(14)
              .fontColor(SunColor.ink)
              .backgroundColor(SunColor.white)
              .borderRadius(8)
              .border({ width: 1, color: SunColor.border })
              .onChange((value: string) => this.draftPrimary = value)

            TextInput({ placeholder: 'Diastolic', text: this.draftSecondary })
              .height(46)
              .layoutWeight(1)
              .fontSize(14)
              .fontColor(SunColor.ink)
              .backgroundColor(SunColor.white)
              .borderRadius(8)
              .border({ width: 1, color: SunColor.border })
              .onChange((value: string) => this.draftSecondary = value)
          }
          .width('100%')
        } else {
          TextInput({ placeholder: this.unitForKind(this.selectedKind), text: this.draftPrimary })
            .height(46)
            .width('100%')
            .fontSize(14)
            .fontColor(SunColor.ink)
            .backgroundColor(SunColor.white)
            .borderRadius(8)
            .border({ width: 1, color: SunColor.border })
            .onChange((value: string) => this.draftPrimary = value)
        }

        TextInput({ placeholder: 'Note (optional)', text: this.draftNote })
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.draftNote = value)

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
  private symptomLogCard() {
    SunCard() {
      Column({ space: SunSpacing.md }) {
        Text('SYMPTOM')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.4)
          .fontColor(SunColor.pebble)

        TextInput({ placeholder: 'Symptom (e.g. headache)', text: this.symptomName })
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.symptomName = value)

        Row({ space: SunSpacing.sm }) {
          this.symptomSeverityButton('Mild', 1)
          this.symptomSeverityButton('Moderate', 2)
          this.symptomSeverityButton('Severe', 3)
        }
        .width('100%')

        TextInput({ placeholder: 'Note', text: this.symptomNote })
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.symptomNote = value)

        SunButton({
          label: 'Save symptom',
          role: SunButtonRole.Secondary,
          action: () => this.logSymptom()
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private targetRangeEditor(kind: string) {
    Column({ space: SunSpacing.sm }) {
      Row({ space: SunSpacing.md }) {
        Text(kind)
          .fontSize(SunType.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(SunColor.ink)
          .layoutWeight(1)

        Text(this.targetRangeLabel(kind))
          .fontSize(SunType.caption)
          .fontColor(SunColor.pebble)
      }
      .width('100%')

      Row({ space: SunSpacing.sm }) {
        TextInput({ placeholder: 'low', text: this.targetLowForKind(kind) })
          .height(42)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.setTargetLow(kind, value))

        TextInput({ placeholder: 'high', text: this.targetHighForKind(kind) })
          .height(42)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.setTargetHigh(kind, value))
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private timeline() {
    Column({ space: SunSpacing.md }) {
      this.quickLogCard()
      this.symptomLogCard()

      SunCard() {
        Column({ space: SunSpacing.sm }) {
          if (this.readings.length === 0 && this.symptoms.length === 0) {
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

            ForEach(this.symptoms, (symptom: Symptom) => {
              SunListRow({
                title: `${symptom.name} · ${String('•').repeat(symptom.severity)}`,
                caption: `Symptom · ${symptom.context}`
              })
            }, (symptom: Symptom) => symptom.id.toString())
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
              Text(this.trendSummary(kind))
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
        Column({ space: SunSpacing.md }) {
          Text('NEW MEDICATION')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          TextInput({ placeholder: 'Name', text: this.medName })
            .height(46)
            .width('100%')
            .fontSize(14)
            .fontColor(SunColor.ink)
            .backgroundColor(SunColor.white)
            .borderRadius(8)
            .border({ width: 1, color: SunColor.border })
            .onChange((value: string) => this.medName = value)

          TextInput({ placeholder: 'Dose', text: this.medDose })
            .height(46)
            .width('100%')
            .fontSize(14)
            .fontColor(SunColor.ink)
            .backgroundColor(SunColor.white)
            .borderRadius(8)
            .border({ width: 1, color: SunColor.border })
            .onChange((value: string) => this.medDose = value)

          Row({ space: SunSpacing.sm }) {
            this.medTimeButton('08:00')
            this.medTimeButton('12:00')
            this.medTimeButton('20:00')
            this.medTimeButton('21:00')
          }
          .width('100%')

          SunButton({
            label: 'Add Medication',
            role: SunButtonRole.Secondary,
            action: () => this.addMedication()
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

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
        }
        .width('100%')
      }

      SunCard() {
        Column({ space: SunSpacing.md }) {
          Text('MY TARGET RANGES')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          ForEach(this.kinds.slice(0, 3), (kind: string) => {
            this.targetRangeEditor(kind)
          }, (kind: string) => kind)

          Text('Set these with your doctor. Steady only counts readings against ranges you enter.')
            .fontSize(12)
            .fontColor(SunColor.pebble)
            .lineHeight(18)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      SunCard() {
        Column({ space: SunSpacing.md }) {
          Text('MEASUREMENT REMINDER')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          Button(this.reminderEnabled ? 'Daily reminder on' : 'Daily reminder off')
            .height(42)
            .width('100%')
            .borderRadius(999)
            .backgroundColor(this.reminderEnabled ? SunColor.sun : SunColor.white)
            .fontColor(SunColor.ink)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .border({ width: 1, color: SunColor.border })
            .onClick(() => this.reminderEnabled = !this.reminderEnabled)

          Row({ space: SunSpacing.sm }) {
            this.reminderTimeButton('08:00', 8, 0)
            this.reminderTimeButton('09:30', 9, 30)
            this.reminderTimeButton('20:00', 20, 0)
          }
          .width('100%')

          SunListRow({
            title: 'Measurement reminder',
            value: this.reminderLabel(),
            caption: 'Take a minute to log your readings.'
          })

          SunButton({
            label: 'Test Reminder',
            role: SunButtonRole.Secondary,
            action: () => this.testMeasurementReminder()
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
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
