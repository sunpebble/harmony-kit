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
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { systemShare } from '@kit.ShareKit'
import { appProfile } from '../AppProfile'

interface Reading {
  id: number
  date?: string
  kind: string
  value: string
  unit: string
  context: string
}

interface Medication {
  name: string
  dose: string
  time?: string
  times?: string[]
  taken?: boolean
  takenSlots?: string[]
}

interface Symptom {
  id: number
  name: string
  severity: number
  context: string
}

interface ReadingMemory {
  kind: string
  primary: string
  secondary: string
}

PersistentStorage.persistProp('steady.tab.v1', 'Timeline')
PersistentStorage.persistProp('steady.nextId.v1', 1)
PersistentStorage.persistProp('steady.selectedKind.v1', 'Blood pressure')
PersistentStorage.persistProp('steady.draftPrimary.v1', '')
PersistentStorage.persistProp('steady.draftSecondary.v1', '')
PersistentStorage.persistProp('steady.draftNote.v1', '')
PersistentStorage.persistProp('steady.readings.v1', '')
PersistentStorage.persistProp('steady.lastReadings.v1', '')
PersistentStorage.persistProp('steady.meds.v1', '')
PersistentStorage.persistProp('steady.symptoms.v1', '')
PersistentStorage.persistProp('steady.reminderEnabled.v1', false)
PersistentStorage.persistProp('steady.reminderHour.v1', 8)
PersistentStorage.persistProp('steady.reminderMinute.v1', 0)
PersistentStorage.persistProp('steady.trendRange.v1', '7D')
PersistentStorage.persistProp('steady.proUnlocked.v1', false)
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
  @StorageLink('steady.nextId.v1') private nextId: number = 1
  @StorageLink('steady.selectedKind.v1') private selectedKind: string = 'Blood pressure'
  @StorageLink('steady.draftPrimary.v1') private draftPrimary: string = ''
  @StorageLink('steady.draftSecondary.v1') private draftSecondary: string = ''
  @StorageLink('steady.draftNote.v1') private draftNote: string = ''
  @StorageLink('steady.readings.v1') private readingsJson: string = ''
  @StorageLink('steady.lastReadings.v1') private lastReadingsJson: string = ''
  @StorageLink('steady.meds.v1') private medsJson: string = ''
  @StorageLink('steady.symptoms.v1') private symptomsJson: string = ''
  @StorageLink('steady.reminderEnabled.v1') private reminderEnabled: boolean = false
  @StorageLink('steady.reminderHour.v1') private reminderHour: number = 8
  @StorageLink('steady.reminderMinute.v1') private reminderMinute: number = 0
  @StorageLink('steady.trendRange.v1') private trendRange: string = '7D'
  @StorageLink('steady.proUnlocked.v1') private proUnlocked: boolean = false
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
  @State private medTimes: string[] = ['08:00']
  @State private editingMedKey: string = ''
  @State private confirmingDeleteMedKey: string = ''
  @State private medRevision: number = 0
  @State private symptoms: Symptom[] = []
  @State private symptomName: string = ''
  @State private symptomSeverity: number = 1
  @State private symptomNote: string = ''
  @State private reportOpen: boolean = false
  @State private confirmingTimelineDeleteKey: string = ''

  aboutToAppear(): void {
    this.loadReadings()
    this.loadMeds()
    this.loadSymptoms()
    if (this.draftPrimary.length === 0 && this.draftSecondary.length === 0) {
      this.applyLastReading(this.selectedKind)
    }
  }

  private loadReadings(): void {
    if (this.readingsJson.length === 0) {
      this.readings = []
      this.saveReadings()
      return
    }
    try {
      const parsed = JSON.parse(this.readingsJson) as Reading[]
      this.readings = parsed
    } catch (_error) {
      this.readings = []
      this.saveReadings()
    }
  }

  private loadMeds(): void {
    if (this.medsJson.length === 0) {
      this.meds = []
      this.saveMeds()
      return
    }
    try {
      const parsed = JSON.parse(this.medsJson) as Medication[]
      this.meds = this.normalizeMeds(parsed)
      this.saveMeds()
    } catch (_error) {
      this.meds = []
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

  private lastReadings(): ReadingMemory[] {
    if (this.lastReadingsJson.length === 0) {
      return []
    }
    try {
      return JSON.parse(this.lastReadingsJson) as ReadingMemory[]
    } catch (_error) {
      this.lastReadingsJson = ''
      return []
    }
  }

  private saveLastReading(primary: string, secondary: string): void {
    const rest = this.lastReadings().filter((memory: ReadingMemory) => memory.kind !== this.selectedKind)
    this.lastReadingsJson = JSON.stringify([
      { kind: this.selectedKind, primary, secondary },
      ...rest
    ])
  }

  private applyLastReading(kind: string): void {
    const memory = this.lastReadings().find((item: ReadingMemory) => item.kind === kind)
    this.draftPrimary = memory ? memory.primary : ''
    this.draftSecondary = kind === 'Blood pressure' && memory ? memory.secondary : ''
  }

  private saveMeds(): void {
    this.medsJson = JSON.stringify(this.meds)
  }

  private saveMedsAndSyncReminders(): void {
    this.saveMeds()
    this.syncReminders()
  }

  private normalizeMeds(meds: Medication[]): Medication[] {
    return meds.map((med: Medication) => {
      const times = this.medTimesFor(med)
      const normalized: Medication = {
        name: med.name,
        dose: med.dose,
        times,
        takenSlots: med.takenSlots ? med.takenSlots.filter((time: string) => times.includes(time)) : (med.taken ? [times[0]] : [])
      }
      return normalized
    })
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
    this.saveLastReading(
      this.cleanNumber(primary),
      this.selectedKind === 'Blood pressure' ? this.cleanNumber(secondary) : ''
    )
    this.readings = [
      {
        id: this.nextId,
        date: new Date().toISOString(),
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
    this.confirmingTimelineDeleteKey = ''
    this.saveReadings()
  }

  private readingDeleteKey(reading: Reading): string {
    return `reading-${reading.id}`
  }

  private symptomDeleteKey(symptom: Symptom): string {
    return `symptom-${symptom.id}`
  }

  private deleteReading(id: number): void {
    this.readings = this.readings.filter((reading: Reading) => reading.id !== id)
    this.confirmingTimelineDeleteKey = ''
    this.saveReadings()
  }

  private deleteSymptom(id: number): void {
    this.symptoms = this.symptoms.filter((symptom: Symptom) => symptom.id !== id)
    this.confirmingTimelineDeleteKey = ''
    this.saveSymptoms()
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

  private unlockPro(): void {
    this.proUnlocked = true
    this.showToast('Steady Pro unlocked on this device.')
  }

  private showProToast(): void {
    this.showToast('Steady Pro unlocks long trends, doctor reports, and CSV export.')
  }

  private toggleDoctorReport(): void {
    if (!this.proUnlocked) {
      this.reportOpen = false
      this.showProToast()
      return
    }
    this.reportOpen = !this.reportOpen
  }

  private exportCsv(): void {
    if (!this.proUnlocked) {
      this.showProToast()
      return
    }
    this.shareText('CSV', this.csvPreview())
  }

  private shareDoctorReport(): void {
    this.shareText('Doctor report', this.doctorReportText())
  }

  private async copyText(label: string, text: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      await pasteboard.getSystemPasteboard().setData(data)
      this.showToast(`${label} copied.`)
    } catch (_error) {
      this.showToast('Copy failed.')
    }
  }

  private async shareText(label: string, text: string): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (!context) {
      await this.copyText(label, text)
      return
    }
    try {
      const shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.TEXT,
        content: text
      })
      const controller: systemShare.ShareController = new systemShare.ShareController(shareData)
      await controller.show(context as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      })
    } catch (_error) {
      await this.copyText(label, text)
    }
  }

  private medTimesFor(med: Medication): string[] {
    if (med.times && med.times.length > 0) {
      return [...med.times].sort((a: string, b: string) => a.localeCompare(b))
    }
    return [med.time ? med.time : '08:00']
  }

  private takenSlotsFor(med: Medication): string[] {
    const times = this.medTimesFor(med)
    if (med.takenSlots) {
      return med.takenSlots.filter((time: string) => times.includes(time))
    }
    return med.taken ? [times[0]] : []
  }

  private timesLabel(med: Medication): string {
    return this.medTimesFor(med).join(', ')
  }

  private medKey(med: Medication): string {
    return `${med.name}|${med.dose}|${this.timesLabel(med)}`
  }

  private toggleMedTime(time: string): void {
    if (this.medTimes.includes(time)) {
      if (this.medTimes.length > 1) {
        this.medTimes = this.medTimes.filter((item: string) => item !== time)
      }
      return
    }
    this.medTimes = [...this.medTimes, time].sort((a: string, b: string) => a.localeCompare(b))
  }

  private toggleMedSlot(name: string, time: string): void {
    const index = this.meds.findIndex((med: Medication) => med.name === name)
    if (index < 0) {
      return
    }
    const med = this.meds[index]
    const times = this.medTimesFor(med)
    const slot = times.includes(time) ? time : times[0]
    const taken = this.takenSlotsFor(med)
    const updatedTaken = taken.includes(slot)
      ? taken.filter((takenSlot: string) => takenSlot !== slot)
      : [...taken, slot].sort((a: string, b: string) => a.localeCompare(b))
    const updated: Medication = { name: med.name, dose: med.dose, times, takenSlots: updatedTaken }
    const next = [...this.meds]
    next[index] = updated
    this.meds = next
    this.saveMeds()
    this.medRevision += 1
  }

  private editMedication(med: Medication): void {
    this.editingMedKey = this.medKey(med)
    this.confirmingDeleteMedKey = ''
    this.medName = med.name
    this.medDose = med.dose
    this.medTimes = this.medTimesFor(med)
  }

  private resetMedicationForm(): void {
    this.medName = ''
    this.medDose = ''
    this.medTimes = ['08:00']
    this.editingMedKey = ''
    this.confirmingDeleteMedKey = ''
  }

  private addMedication(): void {
    const name = this.medName.trim()
    if (name.length === 0) {
      this.showToast('Enter medication name first.')
      return
    }
    const times = [...this.medTimes]
    const nextMed: Medication = {
      name,
      dose: this.medDose.trim().length > 0 ? this.medDose.trim() : 'Dose',
      times,
      takenSlots: []
    }
    if (this.editingMedKey.length > 0) {
      const index = this.meds.findIndex((med: Medication) => this.medKey(med) === this.editingMedKey)
      if (index >= 0) {
        const existing = this.meds[index]
        const next = [...this.meds]
        next[index] = {
          name: nextMed.name,
          dose: nextMed.dose,
          times,
          takenSlots: this.takenSlotsFor(existing).filter((time: string) => times.includes(time))
        }
        this.meds = next
      } else {
        this.meds = [...this.meds, nextMed]
      }
    } else {
      this.meds = [...this.meds, nextMed]
    }
    this.resetMedicationForm()
    this.saveMedsAndSyncReminders()
    this.medRevision += 1
  }

  private startDeleteMedication(target: Medication): void {
    this.confirmingDeleteMedKey = this.medKey(target)
  }

  private deleteMedication(target: Medication): void {
    const targetKey = this.medKey(target)
    this.meds = this.meds.filter((med: Medication) => this.medKey(med) !== targetKey)
    if (this.editingMedKey === targetKey) {
      this.resetMedicationForm()
    }
    this.confirmingDeleteMedKey = ''
    this.saveMedsAndSyncReminders()
    this.medRevision += 1
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
    this.confirmingTimelineDeleteKey = ''
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
    const readings = this.readingsForKind(kind).slice(0, this.trendLimit())
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

  private averageForKind(kind: string): string {
    const readings = this.readingsForKind(kind)
    if (readings.length === 0) {
      return 'No readings'
    }
    const total = readings.reduce((sum: number, reading: Reading) => sum + this.readingNumber(reading), 0)
    return `${this.cleanNumber(total / readings.length)} ${this.unitForKind(kind)}`
  }

  private rangeForKind(kind: string): string {
    const values = this.readingsForKind(kind).map((reading: Reading) => this.readingNumber(reading))
    if (values.length === 0) {
      return 'No readings'
    }
    return `${this.cleanNumber(Math.min(...values))}-${this.cleanNumber(Math.max(...values))}`
  }

  private reportKindSection(kind: string): string {
    const readings = this.readingsForKind(kind)
    if (readings.length === 0) {
      return ''
    }
    const lines: string[] = [
      kind,
      `Average ${this.averageForKind(kind)}`,
      `Range ${this.rangeForKind(kind)}`,
      this.hasTargetRange(kind) ? this.trendSummary(kind) : 'No patient-set range'
    ]
    readings.slice(0, 3).forEach((reading: Reading) => {
      lines.push(`${reading.value} ${reading.unit} · ${reading.context}`)
    })
    return lines.join('\n')
  }

  private medicationReportLine(): string {
    if (this.meds.length === 0) {
      return 'No medications set up.'
    }
    const expected = this.meds.reduce((total: number, med: Medication) => total + this.medTimesFor(med).length, 0)
    const taken = this.meds.reduce((total: number, med: Medication) => total + this.takenSlotsFor(med).length, 0)
    return `${taken} of ${expected} scheduled doses logged today`
  }

  private symptomReportLines(): string {
    if (this.symptoms.length === 0) {
      return 'No symptoms logged.'
    }
    return this.symptoms.slice(0, 3).map((symptom: Symptom) => {
      return `${symptom.name} (${symptom.severity}/3) · ${symptom.context}`
    }).join('\n')
  }

  private doctorReportText(): string {
    const sections = this.kinds.map((kind: string) => this.reportKindSection(kind))
      .filter((section: string) => section.length > 0)
    return [
      'Steady - Health record',
      'Current snapshot',
      ...sections,
      'Medication',
      this.medicationReportLine(),
      'Symptoms',
      this.symptomReportLines(),
      'Steady is a record-keeping tool, not a medical device.'
    ].join('\n\n')
  }

  private csvKind(kind: string): string {
    if (kind === 'Blood pressure') {
      return 'bloodPressure'
    }
    if (kind === 'Blood glucose') {
      return 'glucose'
    }
    if (kind === 'Heart rate') {
      return 'heartRate'
    }
    if (kind === 'Blood oxygen') {
      return 'oxygen'
    }
    return kind.toLowerCase()
  }

  private csvValue(value: string): string {
    if (value.includes(',') || value.includes('"') || value.includes('\n') || value.includes('\r')) {
      return `"${value.replaceAll('"', '""')}"`
    }
    return value
  }

  private readingPrimary(reading: Reading): string {
    return reading.value.split('/')[0]
  }

  private readingSecondary(reading: Reading): string {
    return reading.value.includes('/') ? reading.value.split('/')[1] : ''
  }

  private readingNote(reading: Reading): string {
    return reading.context === 'Just now' ? '' : reading.context
  }

  private csvPreview(): string {
    const readingRows = this.readings.map((reading: Reading) => {
      return [
        reading.date ? reading.date : '',
        this.csvKind(reading.kind),
        this.readingPrimary(reading),
        this.readingSecondary(reading),
        '',
        this.csvValue(this.readingNote(reading))
      ].join(',')
    })
    return ['date,kind,value,secondary,mealtime,note', ...readingRows].join('\n')
  }

  private trendLimit(): number {
    if (this.trendRange === '90D') {
      return 90
    }
    if (this.trendRange === '30D') {
      return 30
    }
    return 7
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

  private enableMeasurementReminder(): void {
    this.reminderEnabled = true
    this.syncReminders(true)
  }

  private async syncReminders(showMeasurementToast: boolean = false): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders()
      if (!this.reminderEnabled && this.meds.length === 0) {
        return
      }
      if (!await this.requestNotificationAccess()) {
        this.reminderEnabled = false
        this.showToast('Enable notifications to use reminders.')
        return
      }
      let notificationId = 210000
      for (const med of this.meds) {
        for (const time of this.medTimesFor(med)) {
          const parts = time.split(':')
          const hour = Number(parts[0])
          const minute = Number(parts[1])
          const request: reminderAgentManager.ReminderRequestAlarm = {
            reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
            hour,
            minute,
            daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
            title: med.name,
            content: `Time for ${med.dose.length > 0 ? med.dose : med.name}.`,
            expiredContent: `${med.name} reminder missed.`,
            notificationId,
            tapDismissed: true
          }
          notificationId += 1
          await reminderAgentManager.publishReminder(request)
        }
      }
      if (this.reminderEnabled) {
        const request: reminderAgentManager.ReminderRequestAlarm = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
          hour: this.reminderHour,
          minute: this.reminderMinute,
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          title: 'Steady',
          content: 'Measurement time: take a minute to log your readings.',
          expiredContent: 'Steady reminder missed.',
          notificationId: 2001,
          tapDismissed: true
        }
        await reminderAgentManager.publishReminder(request)
      }
      if (showMeasurementToast) {
        this.showToast(`Daily reminder set for ${this.reminderLabel()}.`)
      }
    } catch (_error) {
      this.reminderEnabled = false
      this.showToast('Enable notifications to use reminders.')
    }
  }

  private disableMeasurementReminder(): void {
    this.cancelMeasurementReminder()
  }

  private async cancelMeasurementReminder(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders()
      this.reminderEnabled = false
      this.syncReminders()
    } catch (_error) {
      // ponytail: stale reminder ids should not block the visible off state.
    }
    this.showToast('Daily reminder off.')
  }

  private testMeasurementReminder(): void {
    this.scheduleTestMeasurementReminder()
  }

  private async scheduleTestMeasurementReminder(): Promise<void> {
    try {
      if (!await this.requestNotificationAccess()) {
        this.showToast('Enable notifications to test reminders.')
        return
      }
      const request: reminderAgentManager.ReminderRequestTimer = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
        triggerTimeInSeconds: 3,
        title: 'Steady',
        content: 'Measurement time: take a minute to log your readings.',
        expiredContent: 'Steady reminder missed.',
        notificationId: 2002,
        tapDismissed: true
      }
      await reminderAgentManager.publishReminder(request)
      this.showToast('Test reminder scheduled.')
    } catch (_error) {
      this.showToast('Enable notifications to test reminders.')
    }
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

  @Builder
  private trendRangeButton(label: string) {
    Button(label !== '7D' && !this.proUnlocked ? `${label} Pro` : label)
      .height(36)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.trendRange === label ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => {
        if (label !== '7D' && !this.proUnlocked) {
          this.showProToast()
          return
        }
        this.trendRange = label
      })
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
      .onClick(() => {
        this.selectedKind = kind
        this.applyLastReading(kind)
      })
  }

  @Builder
  private medTimeButton(time: string) {
    Button(time)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.medTimes.includes(time) ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.toggleMedTime(time))
  }

  @Builder
  private medDoseRow(name: string, time: string, taken: boolean) {
    Button(`${name} · ${time} · ${taken ? 'Taken' : 'Due'}`)
      .height(42)
      .width('100%')
      .borderRadius(999)
      .backgroundColor(taken ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.toggleMedSlot(name, time))
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
        if (this.reminderEnabled) {
          this.syncReminders(true)
        }
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
            Text('Log your first reading with Quick Log.')
              .fontSize(SunType.body)
              .fontColor(SunColor.pebble)
          } else {
            ForEach(this.readings, (reading: Reading) => {
              Column({ space: SunSpacing.xs }) {
                SunListRow({
                  title: `${reading.value} ${reading.unit}`,
                  caption: `${reading.kind} · ${reading.context}`
                })

                if (this.confirmingTimelineDeleteKey === this.readingDeleteKey(reading)) {
                  Row({ space: SunSpacing.sm }) {
                    SunButton({
                      label: 'Confirm Delete',
                      role: SunButtonRole.Danger,
                      action: () => this.deleteReading(reading.id)
                    })

                    SunButton({
                      label: 'Cancel',
                      role: SunButtonRole.Secondary,
                      action: () => this.confirmingTimelineDeleteKey = ''
                    })
                  }
                  .width('100%')
                } else {
                  SunButton({
                    label: 'Delete',
                    role: SunButtonRole.Danger,
                    action: () => this.confirmingTimelineDeleteKey = this.readingDeleteKey(reading)
                  })
                }
              }
              .width('100%')
            }, (reading: Reading) => reading.id.toString())

            ForEach(this.symptoms, (symptom: Symptom) => {
              Column({ space: SunSpacing.xs }) {
                SunListRow({
                  title: `${symptom.name} · ${String('•').repeat(symptom.severity)}`,
                  caption: `Symptom · ${symptom.context}`
                })

                if (this.confirmingTimelineDeleteKey === this.symptomDeleteKey(symptom)) {
                  Row({ space: SunSpacing.sm }) {
                    SunButton({
                      label: 'Confirm Delete',
                      role: SunButtonRole.Danger,
                      action: () => this.deleteSymptom(symptom.id)
                    })

                    SunButton({
                      label: 'Cancel',
                      role: SunButtonRole.Secondary,
                      action: () => this.confirmingTimelineDeleteKey = ''
                    })
                  }
                  .width('100%')
                } else {
                  SunButton({
                    label: 'Delete',
                    role: SunButtonRole.Danger,
                    action: () => this.confirmingTimelineDeleteKey = this.symptomDeleteKey(symptom)
                  })
                }
              }
              .width('100%')
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

          Row({ space: SunSpacing.sm }) {
            this.trendRangeButton('7D')
            this.trendRangeButton('30D')
            this.trendRangeButton('90D')
          }
          .width('100%')

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
          Text(this.editingMedKey.length > 0 ? 'EDIT MEDICATION' : 'NEW MEDICATION')
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
            label: this.editingMedKey.length > 0 ? 'Save Medication' : 'Add Medication',
            role: SunButtonRole.Secondary,
            action: () => this.addMedication()
          })

          if (this.editingMedKey.length > 0) {
            SunButton({
              label: 'Cancel Edit',
              role: SunButtonRole.Secondary,
              action: () => this.resetMedicationForm()
            })
          }
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
            Column({ space: SunSpacing.sm }) {
              SunListRow({
                title: med.name,
                caption: `${med.dose} · ${this.timesLabel(med)}`,
                action: () => this.editMedication(med)
              })

              ForEach(this.medTimesFor(med), (time: string) => {
                this.medDoseRow(med.name, time, this.takenSlotsFor(med).includes(time))
              }, (time: string) => `${med.name}-${time}-${this.medRevision}`)

              if (this.confirmingDeleteMedKey === this.medKey(med)) {
                Row({ space: SunSpacing.sm }) {
                  Button('Confirm Delete')
                    .height(34)
                    .padding({ left: 12, right: 12 })
                    .borderRadius(999)
                    .backgroundColor(SunColor.danger)
                    .fontColor(SunColor.white)
                    .onClick(() => this.deleteMedication(med))

                  Button('Cancel')
                    .height(34)
                    .padding({ left: 12, right: 12 })
                    .borderRadius(999)
                    .backgroundColor(SunColor.white)
                    .fontColor(SunColor.ink)
                    .border({ width: 1, color: SunColor.border })
                    .onClick(() => this.confirmingDeleteMedKey = '')
                }
              } else {
                Button('Delete')
                  .height(34)
                  .padding({ left: 12, right: 12 })
                  .borderRadius(999)
                  .backgroundColor(SunColor.white)
                  .fontColor(SunColor.danger)
                  .border({ width: 1, color: SunColor.border })
                  .onClick(() => this.startDeleteMedication(med))
              }
            }
            .width('100%')
            .padding({ bottom: SunSpacing.sm })
            .border({ width: { bottom: 1 }, color: SunColor.border })
          }, (med: Medication) => `${med.name}-${this.timesLabel(med)}-${this.medRevision}`)

          if (this.meds.length === 0) {
            Text('No medications set up.')
              .fontSize(SunType.body)
              .fontColor(SunColor.pebble)
          }
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
        Column({ space: SunSpacing.sm }) {
          if (!this.proUnlocked) {
            SunButton({
              label: 'Unlock Pro',
              role: SunButtonRole.Secondary,
              action: () => this.unlockPro()
            })
          }

          SunButton({
            label: this.reportOpen ? 'Hide Doctor Report' : (this.proUnlocked ? 'Doctor Report' : 'Doctor Report Pro'),
            role: SunButtonRole.Secondary,
            action: () => this.toggleDoctorReport()
          })

          if (this.reportOpen && this.proUnlocked) {
            Text(this.doctorReportText())
              .width('100%')
              .fontSize(12)
              .fontColor(SunColor.ink)
              .lineHeight(18)

            SunButton({
              label: 'Share Doctor Report',
              role: SunButtonRole.Secondary,
              action: () => {
                this.shareDoctorReport()
              }
            })
          }

          SunButton({
            label: this.proUnlocked ? 'Export CSV' : 'Export CSV Pro',
            role: SunButtonRole.Secondary,
            action: () => this.exportCsv()
          })

          if (this.proUnlocked) {
            SunListRow({
              title: 'CSV Preview',
              caption: this.csvPreview()
            })
          }
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
            .onClick(() => {
              if (this.reminderEnabled) {
                this.disableMeasurementReminder()
              } else {
                this.enableMeasurementReminder()
              }
            })

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
