import {
  SunButton,
  SunButtonRole,
  SunCard,
  SunColor,
  SunListRow,
  SunSpacing,
  SunSafeRoot,
  SunTabItem,
  SunTabShell,
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
  mealtime?: string
  context: string
}

interface Medication {
  name: string
  dose: string
  time?: string
  times?: string[]
  taken?: boolean
  takenSlots?: string[]
  takenLog?: string[]
  archived?: boolean
  createdAt?: string
}

interface MedicationTimelineLog {
  key: string
  time: number
  title: string
  caption: string
}

interface TimelineItem {
  key: string
  kind: string
  time: number
  title: string
  caption: string
  readingId: number
  symptomId: number
}

interface Symptom {
  id: number
  date?: string
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
PersistentStorage.persistProp('steady.selectedMealtime.v1', '')
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
PersistentStorage.persistProp('steady.trendKind.v1', 'Blood pressure')
PersistentStorage.persistProp('steady.proUnlocked.v1', false)
PersistentStorage.persistProp('steady.targetBpLow.v1', '')
PersistentStorage.persistProp('steady.targetBpHigh.v1', '')
PersistentStorage.persistProp('steady.targetGlucoseLow.v1', '')
PersistentStorage.persistProp('steady.targetGlucoseHigh.v1', '')
PersistentStorage.persistProp('steady.targetWeightLow.v1', '')
PersistentStorage.persistProp('steady.targetWeightHigh.v1', '')
PersistentStorage.persistProp('steady.targetHeartRateLow.v1', '')
PersistentStorage.persistProp('steady.targetHeartRateHigh.v1', '')
PersistentStorage.persistProp('steady.targetOxygenLow.v1', '')
PersistentStorage.persistProp('steady.targetOxygenHigh.v1', '')

@Entry
@Component
struct Index {
  private kinds: string[] = ['Blood pressure', 'Blood glucose', 'Weight', 'Heart rate', 'Blood oxygen']
  @StorageLink('steady.tab.v1') private tab: string = 'Timeline'
  @StorageLink('steady.nextId.v1') private nextId: number = 1
  @StorageLink('steady.selectedKind.v1') private selectedKind: string = 'Blood pressure'
  @StorageLink('steady.selectedMealtime.v1') private selectedMealtime: string = ''
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
  @StorageLink('steady.trendKind.v1') private trendKind: string = 'Blood pressure'
  @StorageLink('steady.proUnlocked.v1') private proUnlocked: boolean = false
  @StorageLink('steady.targetBpLow.v1') private targetBpLow: string = ''
  @StorageLink('steady.targetBpHigh.v1') private targetBpHigh: string = ''
  @StorageLink('steady.targetGlucoseLow.v1') private targetGlucoseLow: string = ''
  @StorageLink('steady.targetGlucoseHigh.v1') private targetGlucoseHigh: string = ''
  @StorageLink('steady.targetWeightLow.v1') private targetWeightLow: string = ''
  @StorageLink('steady.targetWeightHigh.v1') private targetWeightHigh: string = ''
  @StorageLink('steady.targetHeartRateLow.v1') private targetHeartRateLow: string = ''
  @StorageLink('steady.targetHeartRateHigh.v1') private targetHeartRateHigh: string = ''
  @StorageLink('steady.targetOxygenLow.v1') private targetOxygenLow: string = ''
  @StorageLink('steady.targetOxygenHigh.v1') private targetOxygenHigh: string = ''
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
  @State private draftReadingAt: number = 0
  @State private reportStartAt: number = 0
  @State private reportEndAt: number = 0
  @State private reportOpen: boolean = false
  @State private paywallOpen: boolean = false
  @State private confirmingTimelineDeleteKey: string = ''
  @State private quickActionsOpen: boolean = false
  private usedEntityIds: number[] = []

  aboutToAppear(): void {
    this.usedEntityIds = []
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
      this.readings = parsed.map((reading: Reading) => this.normalizeReading(reading))
      this.saveReadings()
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
      const parsed = JSON.parse(this.symptomsJson) as Symptom[]
      this.symptoms = parsed.map((symptom: Symptom) => this.normalizeSymptom(symptom))
      this.saveSymptoms()
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
        takenLog: this.takenLogFor(med),
        archived: med.archived === true,
        createdAt: med.createdAt
      }
      return normalized
    })
  }

  private normalizeEntityId(id: number): number {
    let nextId = Math.max(1, this.nextId)
    if (!id || id <= 0 || this.usedEntityIds.includes(id)) {
      while (this.usedEntityIds.includes(nextId)) {
        nextId += 1
      }
      id = nextId
    }
    this.usedEntityIds.push(id)
    this.nextId = Math.max(nextId, id + 1)
    return id
  }

  private normalizeReading(reading: Reading): Reading {
    const kind = this.kinds.includes(reading.kind) ? reading.kind : 'Blood pressure'
    const context = reading.context === 'Just now' ? '' : (reading.context ? reading.context : '')
    const normalized: Reading = {
      id: this.normalizeEntityId(reading.id),
      date: reading.date ? reading.date : new Date().toISOString(),
      kind,
      value: reading.value,
      unit: reading.unit ? reading.unit : this.unitForKind(kind),
      mealtime: kind === 'Blood glucose' ? this.validMealtime(reading.mealtime) : '',
      context
    }
    return normalized
  }

  private saveSymptoms(): void {
    this.symptomsJson = JSON.stringify(this.symptoms)
  }

  private normalizeSymptom(symptom: Symptom): Symptom {
    const context = symptom.context === 'Just now' ? '' : (symptom.context ? symptom.context : '')
    const severity = Number.isFinite(symptom.severity) ? Math.max(1, Math.min(3, Math.round(symptom.severity))) : 1
    return {
      id: this.normalizeEntityId(symptom.id),
      date: symptom.date ? symptom.date : new Date().toISOString(),
      name: symptom.name && symptom.name.length > 0 ? symptom.name : 'Symptom',
      severity,
      context
    }
  }

  private logReading(): void {
    const primary = Number(this.draftPrimary)
    const secondary = Number(this.draftSecondary)
    if (this.selectedKind === 'Blood pressure') {
      if (!(primary > 0) || !(secondary > 0)) {
        this.showToast(this.t($r('app.string.steady_toast_enter_bp')))
        return
      }
    } else if (!(primary > 0)) {
      this.showToast(this.t($r('app.string.steady_toast_enter_value')))
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
        date: this.readingDate().toISOString(),
        kind: this.selectedKind,
        value: this.selectedKind === 'Blood pressure'
          ? `${this.cleanNumber(primary)}/${this.cleanNumber(secondary)}`
          : this.cleanNumber(primary),
        unit: this.unitForKind(this.selectedKind),
        mealtime: this.selectedKind === 'Blood glucose' ? this.validMealtime(this.selectedMealtime) : '',
        context: note
      },
      ...this.readings
    ]
    this.nextId += 1
    this.draftNote = ''
    this.draftReadingAt = 0
    this.selectedMealtime = ''
    this.confirmingTimelineDeleteKey = ''
    this.saveReadings()
  }

  private selectQuickKind(kind: string): void {
    this.selectedKind = kind
    this.applyLastReading(kind)
    if (kind !== 'Blood glucose') {
      this.selectedMealtime = ''
    }
    this.tab = 'Timeline'
    this.quickActionsOpen = false
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
      return this.t($r('app.string.steady_unit_glucose'))
    }
    if (kind === 'Weight') {
      return this.t($r('app.string.steady_unit_weight'))
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

  private t(resource: Resource, ...args: Array<string | number>): string {
    try {
      const context = this.getUIContext().getHostContext()
      if (!context) {
        return ''
      }
      if (args.length === 0) {
        return context.resourceManager.getStringSync(resource)
      }
      return context.resourceManager.getStringSync(resource.id, ...args)
    } catch (_error) {
      return ''
    }
  }

  private tp(resource: Resource, count: number): string {
    try {
      const context = this.getUIContext().getHostContext()
      if (!context) {
        return ''
      }
      return context.resourceManager.getPluralStringValueSync(resource.id, count)
    } catch (_error) {
      return ''
    }
  }

  private kindLabel(kind: string): Resource {
    if (kind === 'Blood glucose') {
      return $r('app.string.steady_kind_blood_glucose')
    }
    if (kind === 'Weight') {
      return $r('app.string.steady_kind_weight')
    }
    if (kind === 'Heart rate') {
      return $r('app.string.steady_kind_heart_rate')
    }
    if (kind === 'Blood oxygen') {
      return $r('app.string.steady_kind_blood_oxygen')
    }
    return $r('app.string.steady_kind_blood_pressure')
  }

  private kindText(kind: string): string {
    return this.t(this.kindLabel(kind))
  }

  private mealtimeLabel(mealtime: string): Resource {
    return mealtime === 'After meal'
      ? $r('app.string.steady_mealtime_after_meal')
      : $r('app.string.steady_mealtime_fasting')
  }

  private trendRangeLabel(label: string): Resource {
    if (label === '90D') {
      return $r('app.string.steady_range_90d')
    }
    if (label === '30D') {
      return $r('app.string.steady_range_30d')
    }
    return $r('app.string.steady_range_7d')
  }

  private unlockPro(): void {
    this.proUnlocked = true
    this.paywallOpen = false
    this.showToast(this.t($r('app.string.steady_toast_pro_unlocked')))
  }

  private showPaywall(): void {
    this.paywallOpen = true
    // paywallPanel 只挂在 Settings 页；从 Trends 触发时必须切过去，否则用户看不到任何反馈
    this.tab = 'Settings'
  }

  private toggleDoctorReport(): void {
    this.reportOpen = !this.reportOpen
  }

  private exportCsv(): void {
    if (!this.proUnlocked) {
      this.showPaywall()
      return
    }
    this.shareText('CSV', this.csvPreview())
  }

  private shareDoctorReport(): void {
    this.shareText(this.t($r('app.string.steady_doctor_report')), this.doctorReportText())
  }

  private async copyText(label: string, text: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      await pasteboard.getSystemPasteboard().setData(data)
      this.showToast(this.t($r('app.string.steady_toast_copied_format'), label))
    } catch (_error) {
      this.showToast(this.t($r('app.string.steady_toast_copy_failed')))
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
    const today = this.todayKey()
    return this.takenLogFor(med)
      .filter((key: string) => key.startsWith(`${today}|`))
      .map((key: string) => this.medLogTime(key))
  }

  private takenLogFor(med: Medication): string[] {
    const times = this.medTimesFor(med)
    const today = this.todayKey()
    if (med.takenLog) {
      return med.takenLog
    }
    if (med.takenSlots) {
      return med.takenSlots
        .filter((time: string) => times.includes(time))
        .map((time: string) => this.medLogKey(today, time))
    }
    return med.taken ? [this.medLogKey(today, times[0])] : []
  }

  private todayKey(): string {
    return this.dateLabel(Date.now())
  }

  private medLogKey(date: string, time: string): string {
    return `${date}|${time}`
  }

  private medLogTime(key: string): string {
    const parts = key.split('|')
    return parts.length > 1 ? parts[1] : key
  }

  private timesLabel(med: Medication): string {
    return this.medTimesFor(med).join(', ')
  }

  private activeMeds(): Medication[] {
    return this.meds.filter((med: Medication) => med.archived !== true)
  }

  private medicationTimelineLogs(): MedicationTimelineLog[] {
    const logs: MedicationTimelineLog[] = []
    this.meds.forEach((med: Medication) => {
      this.takenLogFor(med).forEach((key: string) => {
        const parts = key.split('|')
        const date = parts.length > 0 ? parts[0] : this.todayKey()
        const time = this.medLogTime(key)
        const timestamp = this.medicationLogTimestamp(date, time)
        logs.push({
          key: `${this.medKey(med)}|${key}`,
          time: timestamp,
          title: this.t($r('app.string.steady_med_taken_format'), med.name),
          caption: `${date} ${time}${med.dose.length > 0 ? ` · ${med.dose}` : ''}`
        })
      })
    })
    return logs.sort((a: MedicationTimelineLog, b: MedicationTimelineLog) => b.time - a.time)
  }

  private medicationLogTimestamp(date: string, time: string): number {
    const timestamp = new Date(`${date}T${time}:00`).getTime()
    return Number.isNaN(timestamp) ? Date.now() : timestamp
  }

  private timelineItems(): TimelineItem[] {
    const items: TimelineItem[] = []
    this.readings.forEach((reading: Reading) => {
      const time = this.dateTime(reading.date)
      items.push({
        key: this.readingDeleteKey(reading),
        kind: 'Reading',
        time,
        title: `${reading.value} ${reading.unit}`,
        caption: this.timelineCaption(time, this.readingTimelineCaption(reading)),
        readingId: reading.id,
        symptomId: -1
      })
    })
    this.symptoms.forEach((symptom: Symptom) => {
      const time = this.dateTime(symptom.date)
      items.push({
        key: this.symptomDeleteKey(symptom),
        kind: 'Symptom',
        time,
        title: `${symptom.name} · ${String('•').repeat(symptom.severity)}`,
        caption: this.timelineCaption(time, this.t($r('app.string.steady_word_symptom'))),
        readingId: -1,
        symptomId: symptom.id
      })
    })
    this.medicationTimelineLogs().forEach((log: MedicationTimelineLog) => {
      items.push({
        key: `medication-${log.key}`,
        kind: 'Medication',
        time: log.time,
        title: log.title,
        caption: log.caption,
        readingId: -1,
        symptomId: -1
      })
    })
    return items.sort((a: TimelineItem, b: TimelineItem) => b.time - a.time)
  }

  private timelineCaption(time: number, detail: string): string {
    return `${this.dateTimeLabel(time)} · ${detail}`
  }

  private medKey(med: Medication): string {
    return `${med.name}|${med.dose}|${this.timesLabel(med)}`
  }

  private toggleMedTime(time: string): void {
    const value = this.validMedTime(time)
    if (value.length === 0) {
      return
    }
    if (this.medTimes.includes(value)) {
      if (this.medTimes.length > 1) {
        this.medTimes = this.medTimes.filter((item: string) => item !== value)
      }
      return
    }
    this.medTimes = [...this.medTimes, value].sort((a: string, b: string) => a.localeCompare(b))
  }

  private addMedTime(time: string): void {
    const value = this.validMedTime(time)
    if (value.length === 0 || this.medTimes.includes(value)) {
      return
    }
    this.medTimes = [...this.medTimes, value].sort((a: string, b: string) => a.localeCompare(b))
  }

  private validMedTime(time: string): string {
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

  private customMedTimes(): string[] {
    const presets: string[] = ['08:00', '12:00', '20:00', '21:00']
    return this.medTimes.filter((time: string) => !presets.includes(time))
  }

  private medTimeDate(time: string): Date {
    const value = this.validMedTime(time) || '08:00'
    const parts = value.split(':')
    const date = new Date()
    date.setHours(Number(parts[0]), Number(parts[1]), 0, 0)
    return date
  }

  private toggleMedSlot(targetKey: string, time: string): void {
    const index = this.meds.findIndex((med: Medication) => med.archived !== true && this.medKey(med) === targetKey)
    if (index < 0) {
      return
    }
    const med = this.meds[index]
    const times = this.medTimesFor(med)
    const slot = times.includes(time) ? time : times[0]
    const logKey = this.medLogKey(this.todayKey(), slot)
    const takenLog = this.takenLogFor(med)
    const updatedTaken = takenLog.includes(logKey)
      ? takenLog.filter((takenSlot: string) => takenSlot !== logKey)
      : [...takenLog, logKey].sort((a: string, b: string) => a.localeCompare(b))
    const updated: Medication = { name: med.name, dose: med.dose, times, takenLog: updatedTaken, archived: med.archived === true, createdAt: med.createdAt }
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
      this.showToast(this.t($r('app.string.steady_toast_enter_med_name')))
      return
    }
    const times = [...this.medTimes]
    const nextMed: Medication = {
      name,
      dose: this.medDose.trim(),
      times,
      takenLog: [],
      createdAt: this.todayKey()
    }
    if (this.editingMedKey.length > 0) {
      const index = this.meds.findIndex((med: Medication) => med.archived !== true && this.medKey(med) === this.editingMedKey)
      if (index >= 0) {
        const existing = this.meds[index]
        const next = [...this.meds]
        next[index] = {
          name: nextMed.name,
          dose: nextMed.dose,
          times,
          takenLog: this.takenLogFor(existing),
          archived: existing.archived === true,
          createdAt: existing.createdAt
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
    this.meds = this.meds.map((med: Medication) => this.medKey(med) === targetKey ? {
      name: med.name,
      dose: med.dose,
      times: this.medTimesFor(med),
      takenLog: this.takenLogFor(med),
      archived: true,
      createdAt: med.createdAt
    } : med)
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
      this.showToast(this.t($r('app.string.steady_toast_enter_symptom')))
      return
    }
    this.symptoms = [
      {
        id: this.nextId,
        date: new Date().toISOString(),
        name,
        severity: this.symptomSeverity,
        context: this.symptomNote.trim()
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
    if (kind === 'Heart rate') {
      return this.targetHeartRateLow
    }
    if (kind === 'Blood oxygen') {
      return this.targetOxygenLow
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
    if (kind === 'Heart rate') {
      return this.targetHeartRateHigh
    }
    if (kind === 'Blood oxygen') {
      return this.targetOxygenHigh
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
    } else if (kind === 'Heart rate') {
      this.targetHeartRateLow = value
    } else if (kind === 'Blood oxygen') {
      this.targetOxygenLow = value
    }
  }

  private setTargetHigh(kind: string, value: string): void {
    if (kind === 'Blood pressure') {
      this.targetBpHigh = value
    } else if (kind === 'Blood glucose') {
      this.targetGlucoseHigh = value
    } else if (kind === 'Weight') {
      this.targetWeightHigh = value
    } else if (kind === 'Heart rate') {
      this.targetHeartRateHigh = value
    } else if (kind === 'Blood oxygen') {
      this.targetOxygenHigh = value
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

  private dayMs(): number {
    return 24 * 60 * 60 * 1000
  }

  private dateTime(value?: string): number {
    if (!value) {
      return Date.now()
    }
    const time = new Date(value).getTime()
    return Number.isNaN(time) ? Date.now() : time
  }

  private dateLabel(time: number): string {
    const date = new Date(time)
    return `${date.getFullYear()}-${this.pad(date.getMonth() + 1)}-${this.pad(date.getDate())}`
  }

  private dateTimeLabel(time: number): string {
    const date = new Date(time)
    return `${this.dateLabel(time)} ${this.pad(date.getHours())}:${this.pad(date.getMinutes())}`
  }

  private readingDate(): Date {
    return this.draftReadingAt > 0 ? new Date(this.draftReadingAt) : new Date()
  }

  private readingTimeLabel(): string {
    return this.draftReadingAt > 0 ? this.dateTimeLabel(this.draftReadingAt) : this.t($r('app.string.steady_time_now'))
  }

  private startOfDay(time: number): number {
    const date = new Date(time)
    date.setHours(0, 0, 0, 0)
    return date.getTime()
  }

  private reportStartCandidateTime(): number {
    return this.reportStartAt > 0 ? this.reportStartAt : this.startOfDay(Date.now() - 30 * this.dayMs())
  }

  private reportEndCandidateTime(): number {
    return this.reportEndAt > 0 ? this.reportEndAt : this.startOfDay(Date.now())
  }

  private reportStartTime(): number {
    return Math.min(this.startOfDay(this.reportStartCandidateTime()), this.startOfDay(this.reportEndCandidateTime()))
  }

  private reportEndTime(): number {
    return Math.max(this.startOfDay(this.reportStartCandidateTime()), this.startOfDay(this.reportEndCandidateTime()))
  }

  private reportEndExclusiveTime(): number {
    return this.reportEndTime() + this.dayMs()
  }

  private reportDateInRange(value?: string): boolean {
    const time = this.dateTime(value)
    return time >= this.reportStartTime() && time < this.reportEndExclusiveTime()
  }

  private reportDateRangeLabel(): string {
    return `${this.dateLabel(this.reportStartTime())} - ${this.dateLabel(this.reportEndTime())}`
  }

  private reportDays(): number {
    return Math.max(1, Math.floor((this.reportEndTime() - this.reportStartTime()) / this.dayMs()) + 1)
  }

  private targetRangeLabel(kind: string): string {
    if (!this.hasTargetRange(kind)) {
      return this.t($r('app.string.steady_target_not_set'))
    }
    return `${this.targetLowForKind(kind)}-${this.targetHighForKind(kind)} ${this.unitForKind(kind)}`
  }

  private trendSummary(kind: string): string {
    const readings = this.trendReadings(kind)
    if (readings.length === 0) {
      return this.t($r('app.string.steady_trend_no_data'))
    }
    if (!this.hasTargetRange(kind)) {
      return this.tp($r('app.plural.steady_trend_logs'), readings.length)
    }
    const low = Number(this.targetLowForKind(kind))
    const high = Number(this.targetHighForKind(kind))
    const inRange = readings.filter((reading: Reading) => {
      const value = this.readingNumber(reading)
      return value >= low && value <= high
    }).length
    return this.t($r('app.string.steady_trend_in_range_format'), inRange, readings.length)
  }

  private trendReadings(kind: string): Reading[] {
    const cutoff = Date.now() - this.trendDays() * this.dayMs()
    return this.readingsForKind(kind).filter((reading: Reading) => this.dateTime(reading.date) >= cutoff)
  }

  private selectedTrendReadings(): Reading[] {
    return this.trendReadings(this.trendKind)
  }

  private hasSelectedTrendReadings(): boolean {
    return this.selectedTrendReadings().length > 0
  }

  private trendChartReadings(): Reading[] {
    return [...this.selectedTrendReadings()]
      .filter((reading: Reading) => !Number.isNaN(this.readingNumber(reading)))
      .sort((a: Reading, b: Reading) => this.dateTime(a.date) - this.dateTime(b.date))
  }

  private trendChartValues(): number[] {
    const values: number[] = []
    this.trendChartReadings().forEach((reading: Reading) => {
      values.push(this.readingNumber(reading))
      const secondary = this.readingSecondaryNumber(reading)
      if (!Number.isNaN(secondary)) {
        values.push(secondary)
      }
    })
    return values
  }

  private trendChartBarHeight(reading: Reading): number {
    const values = this.trendChartValues()
    if (values.length <= 1) {
      return 80
    }
    const min = Math.min(...values)
    const max = Math.max(...values)
    if (max === min) {
      return 80
    }
    return 28 + Math.round((this.readingNumber(reading) - min) / (max - min) * 96)
  }

  private readingSecondaryNumber(reading: Reading): number {
    const value = Number(this.readingSecondary(reading))
    return value > 0 ? value : Number.NaN
  }

  private trendChartSecondaryHeight(reading: Reading): number {
    const secondary = this.readingSecondaryNumber(reading)
    if (Number.isNaN(secondary)) {
      return 0
    }
    const values = this.trendChartValues()
    if (values.length <= 1) {
      return 80
    }
    const min = Math.min(...values)
    const max = Math.max(...values)
    if (max === min) {
      return 80
    }
    return 28 + Math.round((secondary - min) / (max - min) * 96)
  }

  private trendChartColor(reading: Reading): ResourceColor {
    if (!this.hasTargetRange(reading.kind)) {
      return SunColor.sun
    }
    const value = this.readingNumber(reading)
    const low = Number(this.targetLowForKind(reading.kind))
    const high = Number(this.targetHighForKind(reading.kind))
    return value >= low && value <= high ? SunColor.sun : SunColor.danger
  }

  private trendDateLabel(reading: Reading): string {
    const date = new Date(this.dateTime(reading.date))
    return `${this.pad(date.getMonth() + 1)}/${this.pad(date.getDate())}`
  }

  private trendChartStartLabel(): string {
    const readings = this.trendChartReadings()
    return readings.length === 0 ? '' : this.trendDateLabel(readings[0])
  }

  private trendChartEndLabel(): string {
    const readings = this.trendChartReadings()
    return readings.length === 0 ? '' : this.trendDateLabel(readings[readings.length - 1])
  }

  private selectedTrendTargetValue(): string {
    const readings = this.selectedTrendReadings()
    if (readings.length === 0 || !this.hasTargetRange(this.trendKind)) {
      return ''
    }
    const low = Number(this.targetLowForKind(this.trendKind))
    const high = Number(this.targetHighForKind(this.trendKind))
    const inRange = readings.filter((reading: Reading) => {
      const value = this.readingNumber(reading)
      return value >= low && value <= high
    }).length
    return this.t($r('app.string.steady_ratio_format'), inRange, readings.length)
  }

  // 依从率分母：createdAt 之前的天数不该计入，否则新加的药会立刻把完成率拉低
  private medExpectedDays(med: Medication, windowStartDay: number, windowEndDay: number): number {
    const fullDays = Math.max(1, Math.floor((windowEndDay - windowStartDay) / this.dayMs()) + 1)
    if (!med.createdAt) {
      return fullDays
    }
    const created = new Date(`${med.createdAt}T00:00:00`).getTime()
    if (Number.isNaN(created) || created <= windowStartDay) {
      return fullDays
    }
    if (created > windowEndDay) {
      return 0
    }
    return Math.floor((windowEndDay - created) / this.dayMs()) + 1
  }

  private trendMedicationValue(): string {
    const activeMeds = this.activeMeds()
    const trendEndDay = this.startOfDay(Date.now())
    const trendStartDay = trendEndDay - (this.trendDays() - 1) * this.dayMs()
    const expected = activeMeds.reduce((total: number, med: Medication) => total + this.medTimesFor(med).length * this.medExpectedDays(med, trendStartDay, trendEndDay), 0)
    if (expected === 0) {
      return this.t($r('app.string.steady_doses_ratio_format'), 0, 0, 0)
    }
    const cutoff = Date.now() - this.trendDays() * this.dayMs()
    // 只统计在册药物：已删除药物的历史打卡不该计入，否则完成率会超过 100%
    const taken = this.activeMeds().reduce((total: number, med: Medication) => {
      return total + this.takenLogFor(med).filter((key: string) => {
        const parts = key.split('|')
        const date = parts.length > 0 ? parts[0] : this.todayKey()
        return this.medicationLogTimestamp(date, this.medLogTime(key)) >= cutoff
      }).length
    }, 0)
    return this.t($r('app.string.steady_doses_ratio_format'), taken, expected, Math.round(taken / expected * 100))
  }

  private averageForKind(kind: string): string {
    const readings = this.readingsForKind(kind)
    if (readings.length === 0) {
      return this.t($r('app.string.steady_no_readings'))
    }
    const total = readings.reduce((sum: number, reading: Reading) => sum + this.readingNumber(reading), 0)
    return `${this.cleanNumber(total / readings.length)} ${this.unitForKind(kind)}`
  }

  private rangeForKind(kind: string): string {
    const values = this.readingsForKind(kind).map((reading: Reading) => this.readingNumber(reading))
    if (values.length === 0) {
      return this.t($r('app.string.steady_no_readings'))
    }
    return `${this.cleanNumber(Math.min(...values))}-${this.cleanNumber(Math.max(...values))}`
  }

  private averageForReadings(kind: string, readings: Reading[]): string {
    if (readings.length === 0) {
      return this.t($r('app.string.steady_no_readings'))
    }
    const total = readings.reduce((sum: number, reading: Reading) => sum + this.readingNumber(reading), 0)
    return `${this.cleanNumber(total / readings.length)} ${this.unitForKind(kind)}`
  }

  private rangeForReadings(readings: Reading[]): string {
    if (readings.length === 0) {
      return this.t($r('app.string.steady_no_readings'))
    }
    const values = readings.map((reading: Reading) => this.readingNumber(reading))
    return `${this.cleanNumber(Math.min(...values))}-${this.cleanNumber(Math.max(...values))}`
  }

  private targetSummaryForReadings(kind: string, readings: Reading[]): string {
    const low = Number(this.targetLowForKind(kind))
    const high = Number(this.targetHighForKind(kind))
    const inRange = readings.filter((reading: Reading) => {
      const value = this.readingNumber(reading)
      return value >= low && value <= high
    }).length
    return this.t($r('app.string.steady_trend_in_range_format'), inRange, readings.length)
  }

  private validMealtime(mealtime?: string): string {
    return mealtime === 'Fasting' || mealtime === 'After meal' ? mealtime : ''
  }

  private mealtimeRaw(mealtime?: string): string {
    const value = this.validMealtime(mealtime)
    if (value === 'Fasting') {
      return '1'
    }
    if (value === 'After meal') {
      return '2'
    }
    return ''
  }

  private reportKindSection(kind: string): string {
    const readings = this.readingsForKind(kind)
      .filter((reading: Reading) => this.reportDateInRange(reading.date))
      .sort((a: Reading, b: Reading) => this.dateTime(a.date) - this.dateTime(b.date))
    if (readings.length === 0) {
      return ''
    }
    const lines: string[] = [
      this.kindText(kind),
      `${this.t($r('app.string.steady_trend_average'))} ${this.averageForReadings(kind, readings)}`,
      `${this.t($r('app.string.steady_trend_range'))} ${this.rangeForReadings(readings)}`
    ]
    if (this.hasTargetRange(kind)) {
      lines.push(this.targetSummaryForReadings(kind, readings))
    }
    readings.forEach((reading: Reading) => {
      const note = this.readingNote(reading)
      const mealtime = this.validMealtime(reading.mealtime)
      lines.push(`${this.dateTimeLabel(this.dateTime(reading.date))}  ${reading.value} ${reading.unit}${mealtime.length > 0 ? ` (${this.t(this.mealtimeLabel(mealtime))})` : ''}${note.length > 0 ? ` - ${note}` : ''}`)
    })
    return lines.join('\n')
  }

  private medicationReportLine(): string {
    const activeMeds = this.activeMeds()
    if (activeMeds.length === 0) {
      return ''
    }
    const start = this.dateLabel(this.reportStartTime())
    const end = this.dateLabel(this.reportEndTime())
    const expected = activeMeds.reduce((total: number, med: Medication) => total + this.medTimesFor(med).length * this.medExpectedDays(med, this.reportStartTime(), this.reportEndTime()), 0)
    if (expected === 0) {
      return ''
    }
    const taken = activeMeds.reduce((total: number, med: Medication) => {
      return total + this.takenLogFor(med).filter((key: string) => {
        const date = key.split('|')[0]
        return date >= start && date <= end
      }).length
    }, 0)
    return this.t($r('app.string.steady_report_doses_format'), taken, expected, Math.round(taken / expected * 100))
  }

  private symptomReportLines(): string {
    const symptoms = this.symptoms
      .filter((symptom: Symptom) => this.reportDateInRange(symptom.date))
      .sort((a: Symptom, b: Symptom) => this.dateTime(a.date) - this.dateTime(b.date))
    if (symptoms.length === 0) {
      return ''
    }
    return symptoms.map((symptom: Symptom) => {
      const note = symptom.context.trim()
      return `${this.dateLabel(this.dateTime(symptom.date))} - ${symptom.name} (${symptom.severity}/3)${note.length > 0 ? `: ${note}` : ''}`
    }).join('\n')
  }

  private doctorReportText(): string {
    const sections = this.kinds.map((kind: string) => this.reportKindSection(kind))
      .filter((section: string) => section.length > 0)
    const medication = this.medicationReportLine()
    const symptoms = this.symptomReportLines()
    const report = [
      this.t($r('app.string.steady_report_title')),
      this.reportDateRangeLabel(),
      ...sections
    ]
    if (medication.length > 0) {
      report.push(this.t($r('app.string.steady_section_medication')), medication)
    }
    if (symptoms.length > 0) {
      report.push(this.t($r('app.string.steady_word_symptom')), symptoms)
    }
    report.push(this.t($r('app.string.steady_disclaimer')))
    return report.join('\n\n')
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
    return reading.context === 'Just now' ? '' : reading.context.trim()
  }

  private readingTimelineCaption(reading: Reading): string {
    const mealtime = this.validMealtime(reading.mealtime)
    const note = this.readingNote(reading)
    const detail = mealtime.length > 0 ? this.t(this.mealtimeLabel(mealtime)) : note
    const kindText = this.kindText(reading.kind)
    return detail.length > 0 ? `${kindText} · ${detail}` : kindText
  }

  private csvPreview(): string {
    const sorted = [...this.readings].sort((a: Reading, b: Reading) => this.dateTime(a.date) - this.dateTime(b.date))
    const readingRows = sorted.map((reading: Reading) => {
      return [
        reading.date ? reading.date : '',
        this.csvKind(reading.kind),
        this.readingPrimary(reading),
        this.readingSecondary(reading),
        this.mealtimeRaw(reading.mealtime),
        this.csvValue(this.readingNote(reading))
      ].join(',')
    })
    return ['date,kind,value,secondary,mealtime,note', ...readingRows].join('\n')
  }

  private trendDays(): number {
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
      return this.t($r('app.string.steady_paused'))
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
      const activeMeds = this.activeMeds()
      if (!this.reminderEnabled && activeMeds.length === 0) {
        return
      }
      if (!await this.requestNotificationAccess()) {
        this.reminderEnabled = false
        this.showToast(this.t($r('app.string.steady_toast_enable_notifications')))
        return
      }
      let notificationId = 210000
      for (const med of activeMeds) {
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
            content: this.t($r('app.string.steady_reminder_med_content_format'), med.dose.length > 0 ? med.dose : med.name),
            expiredContent: this.t($r('app.string.steady_reminder_med_missed_format'), med.name),
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
          content: this.t($r('app.string.steady_reminder_measure_content')),
          expiredContent: this.t($r('app.string.steady_reminder_measure_missed')),
          notificationId: 2001,
          tapDismissed: true
        }
        await reminderAgentManager.publishReminder(request)
      }
      if (showMeasurementToast) {
        this.showToast(this.t($r('app.string.steady_toast_reminder_set_format'), this.reminderLabel()))
      }
    } catch (_error) {
      this.reminderEnabled = false
      this.showToast(this.t($r('app.string.steady_toast_enable_notifications')))
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
    this.showToast(this.t($r('app.string.steady_toast_reminder_off')))
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
    Button(label !== '7D' && !this.proUnlocked
      ? $r('app.string.steady_range_pro_format', this.t(this.trendRangeLabel(label)))
      : this.trendRangeLabel(label))
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
          this.showPaywall()
          return
        }
        this.trendRange = label
      })
  }

  @Builder
  private kindButton(kind: string) {
    Button({ type: ButtonType.Normal }) {
      Text(this.kindLabel(kind))
        .fontSize(12)
        .fontColor(this.selectedKind === kind ? SunColor.cream : SunColor.ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 140 })
    }
      .height(36)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.selectedKind === kind ? SunColor.ink : SunColor.white)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => {
        this.selectedKind = kind
        this.applyLastReading(kind)
        if (kind !== 'Blood glucose') {
          this.selectedMealtime = ''
        }
      })
  }

  @Builder
  private mealtimeButton(label: ResourceStr, value: string) {
    Button(label)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.selectedMealtime === value ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.selectedMealtime = value)
  }

  private pickReadingTime(): void {
    try {
      this.getUIContext().showDatePickerDialog({
        start: new Date('2000-01-01T00:00:00'),
        end: new Date('2100-12-31T23:59:59'),
        selected: this.readingDate(),
        showTime: true,
        useMilitaryTime: true,
        dateTimeOptions: { hour: '2-digit', minute: '2-digit' },
        onDateAccept: (value: Date) => {
          this.draftReadingAt = value.getTime()
        }
      })
    } catch (_error) {
      this.showToast(this.t($r('app.string.steady_toast_time_picker_unavailable')))
    }
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

  private pickMedTime(): void {
    try {
      this.getUIContext().showTimePickerDialog({
        selected: this.medTimeDate('08:00'),
        useMilitaryTime: true,
        onAccept: (value: TimePickerResult) => {
          if (value.hour === undefined || value.minute === undefined) {
            return
          }
          this.addMedTime(`${this.pad(value.hour)}:${this.pad(value.minute)}`)
        }
      })
    } catch (_error) {
      this.showToast(this.t($r('app.string.steady_toast_time_picker_unavailable')))
    }
  }

  private pickReportDate(target: string): void {
    const selected = target === 'start' ? this.reportStartTime() : this.reportEndTime()
    try {
      this.getUIContext().showDatePickerDialog({
        start: new Date('2000-01-01T00:00:00'),
        end: new Date('2100-12-31T23:59:59'),
        selected: new Date(selected),
        onDateAccept: (value: Date) => {
          const time = this.startOfDay(value.getTime())
          if (target === 'start') {
            this.reportStartAt = time
          } else {
            this.reportEndAt = time
          }
        }
      })
    } catch (_error) {
      this.showToast(this.t($r('app.string.steady_toast_date_picker_unavailable')))
    }
  }

  @Builder
  private medDoseRow(name: string, targetKey: string, time: string, taken: boolean) {
    Button(`${name} · ${time}`)
      .height(42)
      .width('100%')
      .borderRadius(999)
      .backgroundColor(taken ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.toggleMedSlot(targetKey, time))
  }

  @Builder
  private symptomSeverityButton(label: ResourceStr, severity: number) {
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

  private reminderDate(): Date {
    return new Date(2024, 0, 1, this.reminderHour, this.reminderMinute, 0)
  }

  private setReminderTime(hour: number, minute: number): void {
    this.reminderHour = Math.max(0, Math.min(23, hour))
    this.reminderMinute = Math.max(0, Math.min(59, minute))
    if (this.reminderEnabled) {
      this.syncReminders(true)
    }
  }

  @Builder
  private quickLogCard() {
    SunCard() {
      Column({ space: SunSpacing.md }) {
        Text($r('app.string.steady_section_quick_log'))
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
            TextInput({ placeholder: $r('app.string.steady_placeholder_systolic'), text: this.draftPrimary })
              .height(46)
              .layoutWeight(1)
              .fontSize(14)
              .fontColor(SunColor.ink)
              .backgroundColor(SunColor.white)
              .borderRadius(8)
              .border({ width: 1, color: SunColor.border })
              .type(InputType.NUMBER_DECIMAL)
              .onChange((value: string) => this.draftPrimary = value)

            TextInput({ placeholder: $r('app.string.steady_placeholder_diastolic'), text: this.draftSecondary })
              .height(46)
              .layoutWeight(1)
              .fontSize(14)
              .fontColor(SunColor.ink)
              .backgroundColor(SunColor.white)
              .borderRadius(8)
              .border({ width: 1, color: SunColor.border })
              .type(InputType.NUMBER_DECIMAL)
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
            .type(InputType.NUMBER_DECIMAL)
              .onChange((value: string) => this.draftPrimary = value)
        }

        if (this.selectedKind === 'Blood glucose') {
          Row({ space: SunSpacing.sm }) {
            this.mealtimeButton('-', '')
            this.mealtimeButton($r('app.string.steady_mealtime_fasting'), 'Fasting')
            this.mealtimeButton($r('app.string.steady_mealtime_after_meal'), 'After meal')
          }
          .width('100%')
        }

        Button($r('app.string.steady_time_button_format', this.readingTimeLabel()))
          .height(40)
          .width('100%')
          .borderRadius(999)
          .backgroundColor(SunColor.white)
          .fontColor(SunColor.ink)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .border({ width: 1, color: SunColor.border })
          .onClick(() => this.pickReadingTime())

        TextInput({ placeholder: $r('app.string.steady_placeholder_note_optional'), text: this.draftNote })
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.draftNote = value)

        SunButton({
          label: $r('app.string.steady_save_kind_format', this.kindText(this.selectedKind)),
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
        Text($r('app.string.steady_section_symptom'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.4)
          .fontColor(SunColor.pebble)

        TextInput({ placeholder: $r('app.string.steady_placeholder_symptom'), text: this.symptomName })
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.symptomName = value)

        Row({ space: SunSpacing.sm }) {
          this.symptomSeverityButton($r('app.string.steady_severity_mild'), 1)
          this.symptomSeverityButton($r('app.string.steady_severity_moderate'), 2)
          this.symptomSeverityButton($r('app.string.steady_severity_severe'), 3)
        }
        .width('100%')

        TextInput({ placeholder: $r('app.string.steady_placeholder_note'), text: this.symptomNote })
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.symptomNote = value)

        SunButton({
          label: $r('app.string.steady_save'),
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
        Text(this.kindLabel(kind))
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
        TextInput({ placeholder: $r('app.string.steady_placeholder_low'), text: this.targetLowForKind(kind) })
          .height(42)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .type(InputType.NUMBER_DECIMAL)
              .onChange((value: string) => this.setTargetLow(kind, value))

        TextInput({ placeholder: $r('app.string.steady_placeholder_high'), text: this.targetHighForKind(kind) })
          .height(42)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .type(InputType.NUMBER_DECIMAL)
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
          if (this.timelineItems().length === 0) {
            Column({ space: SunSpacing.xs }) {
              Text($r('app.string.steady_timeline_empty_title'))
                .fontSize(SunType.body)
                .fontWeight(FontWeight.Bold)
                .fontColor(SunColor.ink)

              Text($r('app.string.steady_timeline_empty_message'))
                .fontSize(SunType.caption)
                .fontColor(SunColor.pebble)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          } else {
            ForEach(this.timelineItems(), (item: TimelineItem) => {
              Column({ space: SunSpacing.xs }) {
                SunListRow({
                  title: item.title,
                  caption: item.caption
                })

                if (item.kind === 'Reading') {
                  if (this.confirmingTimelineDeleteKey === item.key) {
                    Row({ space: SunSpacing.sm }) {
                      SunButton({
                        label: $r('app.string.steady_confirm_delete'),
                        role: SunButtonRole.Danger,
                        action: () => this.deleteReading(item.readingId)
                      })

                      SunButton({
                        label: $r('app.string.steady_cancel'),
                        role: SunButtonRole.Secondary,
                        action: () => this.confirmingTimelineDeleteKey = ''
                      })
                    }
                    .width('100%')
                  } else {
                    SunButton({
                      label: $r('app.string.steady_delete'),
                      role: SunButtonRole.Danger,
                      action: () => this.confirmingTimelineDeleteKey = item.key
                    })
                  }
                } else if (item.kind === 'Symptom') {
                  if (this.confirmingTimelineDeleteKey === item.key) {
                    Row({ space: SunSpacing.sm }) {
                      SunButton({
                        label: $r('app.string.steady_confirm_delete'),
                        role: SunButtonRole.Danger,
                        action: () => this.deleteSymptom(item.symptomId)
                      })

                      SunButton({
                        label: $r('app.string.steady_cancel'),
                        role: SunButtonRole.Secondary,
                        action: () => this.confirmingTimelineDeleteKey = ''
                      })
                    }
                    .width('100%')
                  } else {
                    SunButton({
                      label: $r('app.string.steady_delete'),
                      role: SunButtonRole.Danger,
                      action: () => this.confirmingTimelineDeleteKey = item.key
                    })
                  }
                }
              }
              .width('100%')
            }, (item: TimelineItem) => item.key)
          }
        }
        .width('100%')
      }
    }
  }

  @Builder
  private trendKindButton(kind: string) {
    Button(this.kindLabel(kind))
      .height(36)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.trendKind === kind ? SunColor.ink : SunColor.white)
      .fontColor(this.trendKind === kind ? SunColor.cream : SunColor.ink)
      .fontSize(12)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.trendKind = kind)
  }

  @Builder
  private trendFactRow(label: ResourceStr, value: string) {
    Row({ space: SunSpacing.md }) {
      Text(label)
        .fontSize(SunType.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(SunColor.ink)
        .layoutWeight(1)
      Text(value)
        .fontSize(SunType.body)
        .fontColor(SunColor.pebble)
    }
    .width('100%')
    .height(38)
  }

  @Builder
  private trends() {
    Column({ space: SunSpacing.md }) {
      SunCard() {
        Column({ space: SunSpacing.md }) {
          Text($r('app.string.steady_section_trends'))
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

          Scroll() {
            Row({ space: SunSpacing.sm }) {
              ForEach(this.kinds, (kind: string) => {
                this.trendKindButton(kind)
              }, (kind: string) => kind)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .height(44)

          if (this.hasSelectedTrendReadings()) {
            this.trendChart()
            this.trendFactRow($r('app.string.steady_trend_average'), this.averageForReadings(this.trendKind, this.selectedTrendReadings()))
            this.trendFactRow($r('app.string.steady_trend_range'), this.rangeForReadings(this.selectedTrendReadings()))
            if (this.selectedTrendTargetValue().length > 0) {
              this.trendFactRow($r('app.string.steady_trend_in_your_range'), this.selectedTrendTargetValue())
            }
          } else {
            Text($r('app.string.steady_trend_no_data'))
              .fontSize(SunType.body)
              .fontColor(SunColor.pebble)
          }

          ForEach(this.kinds, (kind: string) => {
            Row({ space: SunSpacing.md }) {
              Text(this.kindLabel(kind))
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

          Text($r('app.string.steady_section_medication'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)
            .padding({ top: SunSpacing.xs })

          if (this.activeMeds().length === 0) {
            Text($r('app.string.steady_no_meds_set_up'))
              .fontSize(SunType.body)
              .fontColor(SunColor.pebble)
          } else {
            Row({ space: SunSpacing.md }) {
              Text($r('app.string.steady_doses_logged'))
                .fontSize(SunType.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(SunColor.ink)
                .layoutWeight(1)
              Text(this.trendMedicationValue())
                .fontSize(SunType.body)
                .fontColor(SunColor.pebble)
            }
            .width('100%')
            .height(42)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
  }

  @Builder
  private trendChart() {
    Column({ space: SunSpacing.xs }) {
      Row({ space: 4 }) {
        ForEach(this.trendChartReadings(), (reading: Reading) => {
          Column() {
            Row({ space: 2 }) {
              Blank()
                .width(8)
                .height(this.trendChartBarHeight(reading))
                .backgroundColor(this.trendChartColor(reading))
                .borderRadius(4)

              if (this.trendChartSecondaryHeight(reading) > 0) {
                Blank()
                  .width(6)
                  .height(this.trendChartSecondaryHeight(reading))
                  .backgroundColor(SunColor.pebble)
                  .borderRadius(4)
              }
            }
              .width('100%')
              .alignItems(VerticalAlign.Bottom)
              .justifyContent(FlexAlign.Center)
          }
          .layoutWeight(1)
          .height(136)
          .justifyContent(FlexAlign.End)
        }, (reading: Reading) => `${reading.id}-${reading.date}`)
      }
      .width('100%')
      .height(136)
      .alignItems(VerticalAlign.Bottom)

      Row() {
        Text(this.trendChartStartLabel())
          .fontSize(10)
          .fontColor(SunColor.pebble)
        Blank().layoutWeight(1)
        Text(this.trendChartEndLabel())
          .fontSize(10)
          .fontColor(SunColor.pebble)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private medsView() {
    Column({ space: SunSpacing.md }) {
      SunCard() {
        Column({ space: SunSpacing.sm }) {
          Text($r('app.string.steady_section_today'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          ForEach(this.activeMeds(), (med: Medication) => {
            Column({ space: SunSpacing.sm }) {
              SunListRow({
                title: med.name,
                caption: `${med.dose.length > 0 ? `${med.dose} · ` : ''}${this.timesLabel(med)}`,
                action: () => this.editMedication(med)
              })

              ForEach(this.medTimesFor(med), (time: string) => {
                this.medDoseRow(med.name, this.medKey(med), time, this.takenSlotsFor(med).includes(time))
              }, (time: string) => `${this.medKey(med)}-${time}-${this.medRevision}`)

              if (this.confirmingDeleteMedKey === this.medKey(med)) {
                Row({ space: SunSpacing.sm }) {
                  SunButton({
                    label: $r('app.string.steady_confirm_delete'),
                    role: SunButtonRole.Danger,
                    action: () => this.deleteMedication(med)
                  })

                  SunButton({
                    label: $r('app.string.steady_cancel'),
                    role: SunButtonRole.Secondary,
                    action: () => this.confirmingDeleteMedKey = ''
                  })
                }
                .width('100%')
              } else {
                SunButton({
                  label: $r('app.string.steady_delete'),
                  role: SunButtonRole.Danger,
                  action: () => this.startDeleteMedication(med)
                })
              }
            }
            .width('100%')
            .padding({ bottom: SunSpacing.sm })
            .border({ width: { bottom: 1 }, color: SunColor.border })
          }, (med: Medication) => `${this.medKey(med)}-${this.medRevision}`)

          if (this.activeMeds().length === 0) {
            Column({ space: SunSpacing.xs }) {
              Text($r('app.string.steady_meds_empty_title'))
                .fontSize(SunType.body)
                .fontWeight(FontWeight.Bold)
                .fontColor(SunColor.ink)

              Text($r('app.string.steady_meds_empty_message'))
                .fontSize(SunType.caption)
                .fontColor(SunColor.pebble)
            }
            .width('100%')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      SunCard() {
        Column({ space: SunSpacing.md }) {
          Text(this.editingMedKey.length > 0 ? $r('app.string.steady_section_edit_medication') : $r('app.string.steady_section_new_medication'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          TextInput({ placeholder: $r('app.string.steady_placeholder_med_name'), text: this.medName })
            .height(46)
            .width('100%')
            .fontSize(14)
            .fontColor(SunColor.ink)
            .backgroundColor(SunColor.white)
            .borderRadius(8)
            .border({ width: 1, color: SunColor.border })
            .onChange((value: string) => this.medName = value)

          TextInput({ placeholder: $r('app.string.steady_placeholder_med_dose'), text: this.medDose })
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

          if (this.customMedTimes().length > 0) {
            Row({ space: SunSpacing.sm }) {
              ForEach(this.customMedTimes(), (time: string) => {
                this.medTimeButton(time)
              }, (time: string) => time)
            }
            .width('100%')
          }

          SunButton({
            label: $r('app.string.steady_add_time'),
            role: SunButtonRole.Secondary,
            action: () => this.pickMedTime()
          })

          SunButton({
            label: this.editingMedKey.length > 0 ? $r('app.string.steady_save_medication') : $r('app.string.steady_add_medication'),
            role: SunButtonRole.Secondary,
            action: () => this.addMedication()
          })

          if (this.editingMedKey.length > 0) {
            SunButton({
              label: $r('app.string.steady_cancel_edit'),
              role: SunButtonRole.Secondary,
              action: () => this.resetMedicationForm()
            })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
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
        .fontSize(16)
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
        Text('Steady Pro')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.ink)

        Column({ space: 12 }) {
          this.paywallFeature('▣', $r('app.string.steady_paywall_feature_reports'))
          this.paywallFeature('⌁', $r('app.string.steady_paywall_feature_trends'))
          this.paywallFeature('▦', $r('app.string.steady_paywall_feature_csv'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Text($r('app.string.steady_paywall_pitch'))
          .fontSize(14)
          .fontColor(SunColor.pebble)

        SunButton({
          label: $r('app.string.steady_paywall_unlock'),
          action: () => this.unlockPro()
        })

        Button($r('app.string.steady_paywall_restore'))
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(14)
          .fontColor(SunColor.pebble)
          .onClick(() => this.unlockPro())

        Button($r('app.string.steady_paywall_close'))
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(14)
          .fontColor(SunColor.pebble)
          .onClick(() => this.paywallOpen = false)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding(SunSpacing.lg)
      .backgroundColor(SunColor.white)
      .borderRadius(16)
    }
  }

  @Builder
  private settings() {
    Column({ space: SunSpacing.md }) {
      this.paywallPanel()

      SunCard() {
        Column({ space: SunSpacing.sm }) {
          SunButton({
            label: this.reportOpen ? $r('app.string.steady_hide_doctor_report') : $r('app.string.steady_doctor_report'),
            role: SunButtonRole.Secondary,
            action: () => this.toggleDoctorReport()
          })

          if (this.reportOpen) {
            Row({ space: SunSpacing.sm }) {
              SunButton({
                label: $r('app.string.steady_report_from_format', this.dateLabel(this.reportStartTime())),
                role: SunButtonRole.Secondary,
                action: () => this.pickReportDate('start')
              })

              SunButton({
                label: $r('app.string.steady_report_to_format', this.dateLabel(this.reportEndTime())),
                role: SunButtonRole.Secondary,
                action: () => this.pickReportDate('end')
              })
            }
            .width('100%')

            if (this.proUnlocked) {
              Text(this.doctorReportText())
                .width('100%')
                .fontSize(12)
                .fontColor(SunColor.ink)
                .lineHeight(18)

              SunButton({
                label: $r('app.string.steady_share_report'),
                role: SunButtonRole.Secondary,
                action: () => {
                  this.shareDoctorReport()
                }
              })
            } else {
              SunButton({
                label: $r('app.string.steady_generate_report'),
                role: SunButtonRole.Secondary,
                action: () => this.showPaywall()
              })
            }
          }

          SunButton({
            label: $r('app.string.steady_export_csv'),
            role: SunButtonRole.Secondary,
            action: () => this.exportCsv()
          })

          if (this.proUnlocked) {
            SunListRow({
              title: $r('app.string.steady_csv_preview'),
              caption: this.csvPreview()
            })
          }
        }
        .width('100%')
      }

      SunCard() {
        Column({ space: SunSpacing.md }) {
          Text($r('app.string.steady_section_target_ranges'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          ForEach(this.kinds, (kind: string) => {
            this.targetRangeEditor(kind)
          }, (kind: string) => kind)

          Text($r('app.string.steady_target_ranges_note'))
            .fontSize(12)
            .fontColor(SunColor.pebble)
            .lineHeight(18)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      SunCard() {
        Column({ space: SunSpacing.md }) {
          Text($r('app.string.steady_section_measurement_reminder'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(SunColor.pebble)

          Button(this.reminderEnabled ? $r('app.string.steady_reminder_on_label') : $r('app.string.steady_reminder_off_label'))
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

          TimePicker({ selected: this.reminderDate() })
            .width('100%')
            .height(120)
            .selectedTextStyle({ color: SunColor.ink, font: { size: 22, weight: FontWeight.Bold } })
            .textStyle({ color: SunColor.pebble, font: { size: 18, weight: FontWeight.Medium } })
            .onChange((value: TimePickerResult) => this.setReminderTime(value.hour, value.minute))

          SunListRow({
            title: $r('app.string.steady_measurement_reminder'),
            value: this.reminderLabel(),
            caption: $r('app.string.steady_reminder_caption')
          })

        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Text($r('app.string.steady_disclaimer'))
        .fontSize(12)
        .fontColor(SunColor.pebble)
        .lineHeight(18)

      SunCard() {
        Column({ space: SunSpacing.sm }) {
          if (!this.proUnlocked) {
            SunButton({
              label: $r('app.string.steady_pro_button'),
              role: SunButtonRole.Secondary,
              action: () => this.showPaywall()
            })
          } else {
            SunListRow({
              title: $r('app.string.steady_pro_unlocked_row')
            })
          }
        }
        .width('100%')
      }
    }
  }

  private steadyTabs(): SunTabItem[] {
    return [
      { id: 'Timeline', label: $r('app.string.steady_tab_timeline') },
      { id: 'Trends', label: $r('app.string.steady_tab_trends') },
      { id: 'Meds', label: $r('app.string.steady_tab_meds') },
      { id: 'Settings', label: $r('app.string.steady_tab_settings') }
    ]
  }

  @Builder
  private steadyTabBody(tabId: string) {
    Scroll() {
      Column() {
        if (tabId === 'Timeline') {
          this.timeline()
        } else if (tabId === 'Trends') {
          this.trends()
        } else if (tabId === 'Meds') {
          this.medsView()
        } else {
          this.settings()
        }
      }
      .width('100%')
      .padding({ left: SunSpacing.xl, right: SunSpacing.xl, bottom: 120 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    Column() {
      SunSafeRoot({ mode: appProfile.mode }) {
        Stack({ alignContent: Alignment.BottomEnd }) {
        SunTabShell({
        manifest: appProfile,
        tabs: this.steadyTabs(),
        activeTab: this.tab,
        onTabChange: (tabId: string) => {
          this.tab = tabId
          this.quickActionsOpen = false
        },
        tabBody: (tabId: string) => {
          this.steadyTabBody(tabId)
        }
      })

      Column({ space: SunSpacing.sm }) {
        if (this.quickActionsOpen) {
          Column({ space: SunSpacing.sm }) {
            ForEach(this.kinds, (kind: string) => {
              Button(this.kindLabel(kind))
                .height(38)
                .padding({ left: SunSpacing.lg, right: SunSpacing.lg })
                .borderRadius(999)
                .backgroundColor(SunColor.white)
                .fontColor(SunColor.ink)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .border({ width: 1, color: SunColor.border })
                .shadow({ radius: 12, color: '#00000018', offsetY: 4 }) // ponytail: translucent shadow, no SunColor token
                .onClick(() => this.selectQuickKind(kind))
            }, (kind: string) => kind)
          }
          .alignItems(HorizontalAlign.End)
          .padding(SunSpacing.sm)
          .borderRadius(18)
          .backgroundColor(SunColor.cream)
          .border({ width: 1, color: SunColor.border })
        }

        Button(this.quickActionsOpen ? '×' : '+')
          .width(56)
          .height(56)
          .borderRadius(999)
          .backgroundColor(SunColor.sun)
          .fontColor(SunColor.ink)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .shadow({ radius: 8, color: '#00000022', offsetY: 2 }) // ponytail: translucent shadow, no SunColor token
          .onClick(() => this.quickActionsOpen = !this.quickActionsOpen)
      }
        .alignItems(HorizontalAlign.End)
        // ponytail: 56 = SunTabShell barHeight，抬 FAB 到 tab bar 之上，避免遮住 Settings 标签
        .margin({ right: SunSpacing.xl, bottom: 56 + SunSpacing.lg })
      }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
