import {
  SunButton,
  SunColor,
  SunRadius,
  SunSpacing,
  SunMode,
  SunSafeRoot,
  SunToolShell,
  SunType
} from 'sunpebble_ui'
import { common } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { appProfile } from '../AppProfile'

interface PresetTimer {
  emoji: string
  label: string
  seconds: number
}

interface SavedPresetTimer {
  id: number
  emoji: string
  label: string
  seconds: number
}

interface TimerSnapshot {
  id: number
  label: string
  emoji: string
  seconds: number
  remaining: number
  running: boolean
  done: boolean
  endAt: number
  completedAt?: number
}

@Observed
class KitchenTimer {
  id: number
  label: string
  emoji: string
  seconds: number
  remaining: number
  running: boolean
  done: boolean
  endAt: number
  completedAt: number

  constructor(id: number, label: string, emoji: string, seconds: number, remaining: number, running: boolean, done: boolean, endAt: number, completedAt: number) {
    this.id = id
    this.label = label
    this.emoji = emoji
    this.seconds = seconds
    this.remaining = remaining
    this.running = running
    this.done = done
    this.endAt = endAt
    this.completedAt = completedAt
  }
}

PersistentStorage.persistProp('simmer.nextId.v1', 1)
PersistentStorage.persistProp('simmer.timers.v1', '')
PersistentStorage.persistProp('simmer.customMinutes.v1', 5)
PersistentStorage.persistProp('simmer.customSeconds.v1', 0)
PersistentStorage.persistProp('simmer.customEmoji.v1', '🍲')
PersistentStorage.persistProp('simmer.customLabel.v1', '')
PersistentStorage.persistProp('simmer.savedPresets.v1', '')
PersistentStorage.persistProp('simmer.nextPresetId.v1', 1)
PersistentStorage.persistProp('simmer.proUnlocked.v1', false)

// Stored timer/preset labels stay English (persisted data keys); translate at display only.
function presetLabelRes(label: string): Resource | undefined {
  switch (label) {
    case 'Timer': return $r('app.string.simmer_label_timer')
    case 'Tea': return $r('app.string.simmer_label_tea')
    case 'Ramen': return $r('app.string.simmer_label_ramen')
    case 'French Press': return $r('app.string.simmer_label_french_press')
    case 'Rest Steak': return $r('app.string.simmer_label_rest_steak')
    case 'Soft Egg': return $r('app.string.simmer_label_soft_egg')
    case 'Steam Veg': return $r('app.string.simmer_label_steam_veg')
    case 'Hard Egg': return $r('app.string.simmer_label_hard_egg')
    case 'Pasta': return $r('app.string.simmer_label_pasta')
    case 'Dumplings': return $r('app.string.simmer_label_dumplings')
    case 'Rice': return $r('app.string.simmer_label_rice')
    case 'Potatoes': return $r('app.string.simmer_label_potatoes')
    case 'Oven': return $r('app.string.simmer_label_oven')
    default: return undefined
  }
}

function displayLabel(context: common.Context | undefined, label: string): string {
  const res = presetLabelRes(label)
  if (!res || !context) {
    return label
  }
  try {
    return context.resourceManager.getStringSync(res)
  } catch (_error) {
    return label
  }
}

@Component
struct Burner {
  @ObjectLink timer: KitchenTimer
  @Prop
  nowMs: number = Date.now()
  onTap: (id: number) => void = (_id: number) => {}
  onAddMinute: (id: number) => void = (_id: number) => {}
  onRestart: (id: number) => void = (_id: number) => {}
  onCancel: (id: number) => void = (_id: number) => {}

  private timerText(seconds: number): string {
    const total = Math.max(0, Math.round(seconds))
    if (total >= 3600) {
      return `${Math.floor(total / 3600)}:${this.pad(Math.floor(total / 60) % 60)}:${this.pad(total % 60)}`
    }
    return `${Math.floor(total / 60)}:${this.pad(total % 60)}`
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private overdue(): number {
    if (!this.timer.done || this.timer.completedAt <= 0) {
      return 0
    }
    return Math.max(0, Math.floor((this.nowMs - this.timer.completedAt) / 1000))
  }

  private progress(): number {
    if (this.timer.seconds <= 0 || this.timer.done) {
      return 100
    }
    return Math.max(0, Math.min(100, Math.round((1 - this.timer.remaining / this.timer.seconds) * 100)))
  }

  private ringDash(): number[] {
    const circumference = 2 * Math.PI * 67
    return [circumference * this.progress() / 100, circumference]
  }

  build() {
    Column({ space: SunSpacing.sm }) {
      Stack() {
        Circle({ width: 142, height: 142 })
          .fillOpacity(0)
          .stroke(SunColor.border)
          .strokeWidth(8)

        Circle({ width: 142, height: 142 })
          .fillOpacity(0)
          .stroke(this.timer.done ? SunColor.sun : SunColor.ink)
          .strokeWidth(8)
          .strokeLineCap(LineCapStyle.Round)
          .strokeDashArray(this.ringDash())
          .rotate({ x: 0, y: 0, z: 1, angle: -90 })

        Column({ space: SunSpacing.xs }) {
          Text(this.timer.emoji)
            .fontSize(36)

          if (this.timer.done) {
            Text($r('app.string.simmer_burner_done'))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.ink)

            Text($r('app.string.simmer_burner_over_format', this.timerText(this.overdue())))
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor(SunColor.pebble)
          } else {
            Text(this.timerText(this.timer.remaining))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.ink)

            if (!this.timer.running) {
              Text($r('app.string.simmer_burner_paused'))
                .fontSize(9)
                .fontWeight(FontWeight.Medium)
                .fontColor(SunColor.pebble)
            }
          }
        }
      }
      .width(150)
      .height(150)
      .onClick(() => this.onTap(this.timer.id))

      Text(displayLabel(this.getUIContext().getHostContext(), this.timer.label).toUpperCase())
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(SunColor.pebble)
        .letterSpacing(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 6 }) {
        this.actionButton($r('app.string.simmer_action_add_minute'), () => this.onAddMinute(this.timer.id), SunColor.ink)
        this.actionButton($r('app.string.simmer_action_restart'), () => this.onRestart(this.timer.id), SunColor.ink)
        this.actionButton($r('app.string.simmer_action_cancel'), () => this.onCancel(this.timer.id), SunColor.danger)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width(190)
    .height(250)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private actionButton(label: ResourceStr, action: () => void, color: string) {
    Button(label)
      .height(30)
      .padding({ left: 8, right: 8 })
      .borderRadius(SunRadius.pill)
      .backgroundColor(SunColor.white)
      .fontColor(color)
      .fontSize(10)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: '#D8CFBD' }) // ponytail: no SunColor token for #D8CFBD hairline
      .onClick(action)
  }
}

@Entry
@Component
struct Index {
  private presets: PresetTimer[] = [
    { emoji: '🍵', label: 'Tea', seconds: 3 * 60 },
    { emoji: '🍜', label: 'Ramen', seconds: 4 * 60 },
    { emoji: '☕', label: 'French Press', seconds: 4 * 60 },
    { emoji: '🥩', label: 'Rest Steak', seconds: 5 * 60 },
    { emoji: '🥚', label: 'Soft Egg', seconds: 6 * 60 },
    { emoji: '🥦', label: 'Steam Veg', seconds: 8 * 60 },
    { emoji: '🍳', label: 'Hard Egg', seconds: 10 * 60 },
    { emoji: '🍝', label: 'Pasta', seconds: 10 * 60 },
    { emoji: '🥟', label: 'Dumplings', seconds: 10 * 60 },
    { emoji: '🍚', label: 'Rice', seconds: 15 * 60 },
    { emoji: '🥔', label: 'Potatoes', seconds: 20 * 60 },
    { emoji: '🍞', label: 'Oven', seconds: 25 * 60 }
  ]
  private customEmojis: string[] = ['🍲', '🍳', '🥚', '🍝', '🍚', '🥩', '🍞', '🍵', '🧁', '🥦', '🍕', '🦐']
  private customSecondOptions: number[] = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
  private intervalId: number = -1

  @StorageLink('simmer.nextId.v1') private nextId: number = 1
  @StorageLink('simmer.timers.v1') private timersJson: string = ''
  @StorageLink('simmer.customMinutes.v1') private customMinutes: number = 5
  @StorageLink('simmer.customSeconds.v1') private customSeconds: number = 0
  @StorageLink('simmer.customEmoji.v1') private customEmoji: string = '🍲'
  @StorageLink('simmer.customLabel.v1') private customLabelText: string = ''
  @StorageLink('simmer.savedPresets.v1') private savedPresetsJson: string = ''
  @StorageLink('simmer.nextPresetId.v1') private nextPresetId: number = 1
  @StorageLink('simmer.proUnlocked.v1') private proUnlocked: boolean = false
  @State private customOpen: boolean = false
  @State private timers: KitchenTimer[] = []
  @State private savedPresets: SavedPresetTimer[] = []
  @State private nowMs: number = Date.now()
  @State private confirmingPresetId: number = -1
  @State private customSaveAsPreset: boolean = false
  @State private paywallOpen: boolean = false

  aboutToAppear(): void {
    this.loadTimers()
    this.loadSavedPresets()
    if (this.intervalId < 0) {
      this.intervalId = setInterval(() => this.tick(), 1000)
    }
  }

  aboutToDisappear(): void {
    if (this.intervalId >= 0) {
      clearInterval(this.intervalId)
      this.intervalId = -1
    }
  }

  private startPreset(preset: PresetTimer): void {
    this.startTimer(preset.label, preset.emoji, preset.seconds)
  }

  private startSavedPreset(preset: SavedPresetTimer): void {
    this.confirmingPresetId = -1
    this.startTimer(preset.label, preset.emoji, preset.seconds)
  }

  private startCustom(): void {
    this.confirmingPresetId = -1
    const nextOpen = !this.customOpen
    this.customOpen = nextOpen
    if (nextOpen) {
      this.customMinutes = 5
      this.customSeconds = 0
      this.customEmoji = '🍲'
      this.customLabelText = ''
      this.customSaveAsPreset = false
    }
  }

  private startCustomTimer(): void {
    const seconds = this.customSecondsTotal()
    if (seconds <= 0) {
      return
    }
    if (this.startTimer(this.customLabel(), this.customEmoji, seconds)) {
      this.customOpen = false
      this.customSaveAsPreset = false
    }
  }

  private startCustomFromPanel(): void {
    if (this.proUnlocked && this.customSaveAsPreset) {
      this.saveCustomPresetAndStart()
    } else {
      this.startCustomTimer()
    }
  }

  private saveCustomPresetAndStart(): void {
    if (!this.proUnlocked) {
      this.showToast($r('app.string.simmer_toast_pro_required'))
      return
    }
    const seconds = this.customSecondsTotal()
    if (seconds <= 0) {
      return
    }
    const label = this.customLabel()
    this.savedPresets = [...this.savedPresets, { id: this.nextPresetId, emoji: this.customEmoji, label, seconds }]
    this.nextPresetId += 1
    this.confirmingPresetId = -1
    this.saveSavedPresets()
    if (this.startTimer(label, this.customEmoji, seconds)) {
      this.customOpen = false
      this.customSaveAsPreset = false
    }
  }

  private removeSavedPreset(id: number): void {
    this.savedPresets = this.savedPresets.filter((preset: SavedPresetTimer) => preset.id !== id)
    this.confirmingPresetId = -1
    this.saveSavedPresets()
  }

  private normalizeSavedPresets(presets: SavedPresetTimer[]): SavedPresetTimer[] {
    const usedIds: number[] = []
    let nextId = Math.max(1, this.nextPresetId)
    const normalized = presets.map((preset: SavedPresetTimer) => {
      let id = preset.id
      if (!id || id <= 0 || usedIds.includes(id)) {
        while (usedIds.includes(nextId)) {
          nextId += 1
        }
        id = nextId
      }
      usedIds.push(id)
      nextId = Math.max(nextId, id + 1)
      const normalizedPreset: SavedPresetTimer = { id, emoji: preset.emoji, label: preset.label, seconds: preset.seconds }
      return normalizedPreset
    })
    this.nextPresetId = nextId
    return normalized
  }

  private normalizeTimers(timers: TimerSnapshot[]): TimerSnapshot[] {
    const usedIds: number[] = []
    let nextId = Math.max(1, this.nextId)
    const normalized = timers.map((timer: TimerSnapshot) => {
      let id = timer.id
      if (!id || id <= 0 || usedIds.includes(id)) {
        while (usedIds.includes(nextId)) {
          nextId += 1
        }
        id = nextId
      }
      usedIds.push(id)
      nextId = Math.max(nextId, id + 1)
      const normalizedTimer: TimerSnapshot = {
        id,
        label: timer.label,
        emoji: timer.emoji,
        seconds: timer.seconds,
        remaining: timer.remaining,
        running: timer.running,
        done: timer.done,
        endAt: timer.endAt,
        completedAt: timer.completedAt
      }
      return normalizedTimer
    })
    this.nextId = nextId
    return normalized
  }

  private customSecondsTotal(): number {
    return this.customMinutes * 60 + this.customSeconds
  }

  private customMinuteOptions(): string[] {
    const unit = this.resString($r('app.string.simmer_minute_unit'))
    const options: string[] = []
    for (let minute = 0; minute <= 180; minute++) {
      options.push(`${minute} ${unit}`)
    }
    return options
  }

  private customSecondLabels(): string[] {
    const unit = this.resString($r('app.string.simmer_second_unit'))
    return this.customSecondOptions.map((seconds: number) => `${seconds} ${unit}`)
  }

  private customLabel(): string {
    const label = this.customLabelText.trim()
    return label.length > 0 ? label : 'Timer'
  }

  private setCustomMinutes(minutes: number): void {
    this.customMinutes = Math.max(0, Math.min(180, Math.round(minutes)))
  }

  private setCustomSeconds(seconds: number): void {
    this.customSeconds = seconds
  }

  private startTimer(label: string, emoji: string, seconds: number): boolean {
    if (!this.proUnlocked && this.timers.length > 0) {
      this.showPaywall()
      return false
    }
    this.timers = [...this.timers, new KitchenTimer(this.nextId, label, emoji, seconds, seconds, true, false, Date.now() + seconds * 1000, 0)]
    this.nextId += 1
    this.saveTimersAndSyncReminders()
    return true
  }

  private unlockPro(): void {
    this.proUnlocked = true
    this.paywallOpen = false
    this.showToast($r('app.string.simmer_toast_pro_unlocked'))
  }

  private showPaywall(): void {
    this.paywallOpen = true
    this.customOpen = false
    this.customSaveAsPreset = false
  }

  private toggleTimer(id: number): void {
    const timer = this.timers.find((item: KitchenTimer) => item.id === id)
    if (!timer || timer.done) {
      return
    }

    if (timer.running) {
      timer.remaining = this.remainingFromEnd(timer)
      timer.running = false
      timer.done = false
      timer.endAt = 0
      timer.completedAt = 0
    } else {
      timer.remaining = timer.remaining > 0 ? timer.remaining : timer.seconds
      timer.running = true
      timer.done = false
      timer.endAt = Date.now() + timer.remaining * 1000
      timer.completedAt = 0
    }
    this.tick()
    this.saveTimersAndSyncReminders()
  }

  private handleTimerTap(id: number): void {
    const done = this.timers.some((timer: KitchenTimer) => timer.id === id && timer.done)
    if (done) {
      this.deleteTimer(id)
      return
    }
    this.toggleTimer(id)
  }

  private deleteTimer(id: number): void {
    this.timers = this.timers.filter((timer: KitchenTimer) => timer.id !== id)
    this.saveTimersAndSyncReminders()
  }

  private addMinute(id: number): void {
    const timer = this.timers.find((item: KitchenTimer) => item.id === id)
    if (!timer) {
      return
    }

    timer.seconds += 60
    if (timer.running) {
      timer.endAt = Math.max(timer.endAt, Date.now()) + 60 * 1000
      timer.remaining = this.remainingFromEnd(timer)
      timer.done = false
      timer.completedAt = 0
    } else if (timer.done) {
      timer.remaining += 60
      timer.running = true
      timer.done = false
      timer.endAt = Date.now() + timer.remaining * 1000
      timer.completedAt = 0
    } else {
      timer.remaining += 60
      timer.running = false
      timer.done = false
      timer.endAt = 0
      timer.completedAt = 0
    }
    this.saveTimersAndSyncReminders()
  }

  private restartTimer(id: number): void {
    const timer = this.timers.find((item: KitchenTimer) => item.id === id)
    if (!timer) {
      return
    }

    timer.remaining = timer.seconds
    timer.running = true
    timer.done = false
    timer.endAt = Date.now() + timer.seconds * 1000
    timer.completedAt = 0
    this.saveTimersAndSyncReminders()
  }

  private tick(): void {
    const now = Date.now()
    this.nowMs = now
    if (!this.timers.some((timer: KitchenTimer) => timer.running)) {
      return
    }

    let anyDone = false
    this.timers.forEach((timer: KitchenTimer) => {
      if (!timer.running) {
        return
      }

      const remaining = this.remainingFromEnd(timer, now)
      if (remaining > 0) {
        timer.remaining = remaining
        timer.done = false
        return
      }

      this.showDone(timer.label)
      timer.remaining = 0
      timer.running = false
      timer.done = true
      timer.completedAt = timer.endAt > 0 ? timer.endAt : now
      timer.endAt = 0
      anyDone = true
    })
    if (anyDone) {
      this.saveTimersAndSyncReminders()
    }
  }

  private loadTimers(): void {
    if (this.timersJson.length === 0) {
      return
    }

    try {
      const saved = JSON.parse(this.timersJson) as TimerSnapshot[]
      this.timers = this.normalizeTimers(saved).map((timer: TimerSnapshot) => this.restoreTimer(timer))
      this.saveTimers()
      this.syncReminders()
    } catch (_error) {
      this.timers = []
      this.saveTimers()
      this.syncReminders()
    }
  }

  private loadSavedPresets(): void {
    if (this.savedPresetsJson.length === 0) {
      return
    }

    try {
      const saved = JSON.parse(this.savedPresetsJson) as SavedPresetTimer[]
      this.savedPresets = this.normalizeSavedPresets(saved)
      this.saveSavedPresets()
    } catch (_error) {
      this.savedPresets = []
      this.saveSavedPresets()
    }
  }

  private restoreTimer(timer: TimerSnapshot): KitchenTimer {
    const completedAt = timer.completedAt ? timer.completedAt : (timer.done ? Date.now() : 0)
    if (!timer.running) {
      return new KitchenTimer(timer.id, timer.label, timer.emoji, timer.seconds, timer.remaining, false, timer.done, 0, completedAt)
    }

    const remaining = Math.max(0, Math.ceil((timer.endAt - Date.now()) / 1000))
    return new KitchenTimer(timer.id, timer.label, timer.emoji, timer.seconds, remaining, remaining > 0, remaining <= 0, remaining > 0 ? timer.endAt : 0, remaining > 0 ? 0 : timer.endAt)
  }

  private saveTimers(): void {
    this.timersJson = JSON.stringify(this.timers)
  }

  private saveTimersAndSyncReminders(): void {
    this.saveTimers()
    this.syncReminders()
  }

  private saveSavedPresets(): void {
    this.savedPresetsJson = JSON.stringify(this.savedPresets)
  }

  private remainingFromEnd(timer: KitchenTimer, now: number = Date.now()): number {
    return Math.max(0, Math.ceil((timer.endAt - now) / 1000))
  }

  private async syncReminders(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders()
      const running = this.timers.filter((timer: KitchenTimer) => timer.running && !timer.done && timer.endAt > Date.now())
      if (running.length === 0 || !await this.requestNotificationAccess()) {
        return
      }
      const now = Date.now()
      for (const timer of running) {
        const request: reminderAgentManager.ReminderRequestTimer = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
          triggerTimeInSeconds: Math.max(1, Math.ceil((timer.endAt - now) / 1000)),
          title: `${timer.emoji} ${this.labelText(timer.label)}`,
          content: this.resString($r('app.string.simmer_reminder_content')),
          expiredContent: this.resString($r('app.string.simmer_reminder_expired_format'), this.labelText(timer.label)),
          notificationId: 400000 + timer.id,
          tapDismissed: true
        }
        await reminderAgentManager.publishReminder(request)
      }
    } catch (_error) {
      // ponytail: visible timers are source of truth; reminders rebuild on the next timer edit.
    }
  }

  private notifGranted: boolean = false

  private async requestNotificationAccess(): Promise<boolean> {
    if (this.notifGranted) {
      return true
    }
    const context = this.getUIContext().getHostContext()
    if (!context) {
      return false
    }
    try {
      await notificationManager.requestEnableNotification(context as common.UIAbilityContext)
      this.notifGranted = true
      return true
    } catch (_error) {
      return false
    }
  }

  private resString(res: Resource, ...args: Array<string | number>): string {
    const context = this.getUIContext().getHostContext()
    return context ? context.resourceManager.getStringSync(res, ...args) : ''
  }

  private labelText(label: string): string {
    return displayLabel(this.getUIContext().getHostContext(), label)
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message,
        duration: 2000
      })
    } catch (_error) {
      // ponytail: visible state is the fallback if toast is unavailable.
    }
  }

  private showDone(label: string): void {
    this.showToast($r('app.string.simmer_toast_done_format', this.labelText(label)))
  }

  private timerText(seconds: number): string {
    const total = Math.max(0, Math.round(seconds))
    if (total >= 3600) {
      return `${Math.floor(total / 3600)}:${this.pad(Math.floor(total / 60) % 60)}:${this.pad(total % 60)}`
    }
    return `${Math.floor(total / 60)}:${this.pad(total % 60)}`
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  @Builder
  private emptyState() {
    Column({ space: SunSpacing.md }) {
      Text('🍳')
        .fontSize(56)

      Text($r('app.string.simmer_empty_title'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(SunColor.ink)

      Text($r('app.string.simmer_empty_message'))
        .fontSize(13)
        .fontColor(SunColor.pebble)
        .textAlign(TextAlign.Center)
        .lineHeight(23)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private burnerList() {
    Scroll() {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
        ForEach(this.timers, (timer: KitchenTimer) => {
          Burner({
            timer: timer,
            nowMs: this.nowMs,
            onTap: (id: number) => this.handleTimerTap(id),
            onAddMinute: (id: number) => this.addMinute(id),
            onRestart: (id: number) => this.restartTimer(id),
            onCancel: (id: number) => this.deleteTimer(id)
          })
        }, (timer: KitchenTimer) => timer.id.toString())
      }
      .padding(SunSpacing.xl)
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private customPanel() {
    if (this.customOpen) {
      Column({ space: SunSpacing.md }) {
        Text($r('app.string.simmer_custom_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
          .fontColor(SunColor.pebble)

        Scroll() {
          Row({ space: SunSpacing.sm }) {
            ForEach(this.customEmojis, (emoji: string) => {
              Button({ type: ButtonType.Normal }) {
                Text(emoji)
                  .fontSize(22)
                  .lineHeight(26)
                  .textAlign(TextAlign.Center)
                  .width('100%')
              }
              .width(44)
              .height(44)
              .padding(0)
              .borderRadius(999)
              .backgroundColor(this.customEmoji === emoji ? SunColor.sun : SunColor.white)
              .onClick(() => this.customEmoji = emoji)
            }, (emoji: string) => emoji)
          }
        }
        .width('100%')
        .height(42)
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)

        Row({ space: SunSpacing.sm }) {
          TextPicker({ range: this.customMinuteOptions(), selected: this.customMinutes })
            .layoutWeight(1)
            .height(130)
            .selectedTextStyle({ color: SunColor.ink, font: { size: 22, weight: FontWeight.Bold } })
            .textStyle({ color: SunColor.pebble, font: { size: 18, weight: FontWeight.Medium } })
            .onChange((_value: string | string[], index: number | number[]) => {
              if (typeof index === 'number') {
                this.setCustomMinutes(index)
              }
            })

          TextPicker({
            range: this.customSecondLabels(),
            selected: Math.max(0, this.customSecondOptions.indexOf(this.customSeconds))
          })
            .layoutWeight(1)
            .height(130)
            .selectedTextStyle({ color: SunColor.ink, font: { size: 22, weight: FontWeight.Bold } })
            .textStyle({ color: SunColor.pebble, font: { size: 18, weight: FontWeight.Medium } })
            .onChange((_value: string | string[], index: number | number[]) => {
              if (typeof index === 'number') {
                this.setCustomSeconds(this.customSecondOptions[index])
              }
            })
        }
        .width('100%')

        TextInput({ placeholder: $r('app.string.simmer_label_placeholder'), text: this.customLabelText })
          .height(44)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: '#D8CFBD' }) // ponytail: no SunColor token for #D8CFBD hairline
          .onChange((value: string) => this.customLabelText = value)

        if (this.proUnlocked) {
          Button($r('app.string.simmer_save_as_preset'))
            .height(38)
            .width('100%')
            .borderRadius(SunRadius.pill)
            .backgroundColor(this.customSaveAsPreset ? SunColor.sun : SunColor.white)
            .fontColor(SunColor.ink)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .border({ width: 1, color: '#D8CFBD' }) // ponytail: no SunColor token for #D8CFBD hairline
            .onClick(() => this.customSaveAsPreset = !this.customSaveAsPreset)
        }

        Button($r('app.string.simmer_start'))
          .height(44)
          .width('100%')
          .borderRadius(SunRadius.pill)
          .backgroundColor(SunColor.ink)
          .fontColor(SunColor.cream)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .enabled(this.customSecondsTotal() > 0)
          .opacity(this.customSecondsTotal() > 0 ? 1 : 0.5)
          .onClick(() => this.startCustomFromPanel())

        Button($r('app.string.simmer_action_cancel'))
          .height(38)
          .width('100%')
          .borderRadius(SunRadius.pill)
          .backgroundColor(SunColor.white)
          .fontColor(SunColor.ink)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .border({ width: 1, color: '#D8CFBD' }) // ponytail: no SunColor token for #D8CFBD hairline
          .onClick(() => {
            this.customOpen = false
            this.customSaveAsPreset = false
          })

      }
      .width('100%')
      .padding(SunSpacing.lg)
      .backgroundColor('#F7F0E5') // ponytail: no SunColor token for #F7F0E5 panel tint
      .border({ width: 1, color: '#D8CFBD' }) // ponytail: no SunColor token for #D8CFBD hairline
      .borderRadius(18)
    }
  }

  @Builder
  private presetBar() {
    Scroll() {
      Row({ space: 10 }) {
        Button($r('app.string.simmer_custom_button'))
          .height(44)
          .padding({ left: 16, right: 16 })
          .borderRadius(SunRadius.pill)
          .backgroundColor(SunColor.cream)
          .fontColor(SunColor.ink)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .border({ width: 1, color: SunColor.pebble })
          .onClick(() => this.startCustom())

        ForEach(this.savedPresets, (preset: SavedPresetTimer) => {
          if (this.confirmingPresetId === preset.id) {
            Row({ space: 4 }) {
              Button($r('app.string.simmer_remove_preset'))
                .height(34)
                .padding({ left: 12, right: 12 })
                .borderRadius(999)
                .backgroundColor(SunColor.danger)
                .fontColor(SunColor.white)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .onClick(() => this.removeSavedPreset(preset.id))

              Button($r('app.string.simmer_action_cancel'))
                .height(34)
                .padding({ left: 12, right: 12 })
                .borderRadius(999)
                .backgroundColor(SunColor.white)
                .fontColor(SunColor.ink)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .border({ width: 1, color: '#D8CFBD' }) // ponytail: no SunColor token for #D8CFBD hairline
                .onClick(() => this.confirmingPresetId = -1)
            }
            .height(56)
          } else {
            Row({ space: 4 }) {
              Button({ type: ButtonType.Normal }) {
                Text(`${preset.emoji} ${this.labelText(preset.label)} · ${this.timerText(preset.seconds)}`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(SunColor.ink)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .constraintSize({ maxWidth: 220 })
              }
              .height(44)
              .padding({ left: 16, right: 12 })
              .borderRadius(SunRadius.pill)
              .backgroundColor(SunColor.sun)
              .onClick(() => this.startSavedPreset(preset))

              Button('×')
                .width(34)
                .height(34)
                .borderRadius(999)
                .backgroundColor(SunColor.white)
                .fontColor(SunColor.danger)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .border({ width: 1, color: '#D8CFBD' }) // ponytail: no SunColor token for #D8CFBD hairline
                .onClick(() => this.confirmingPresetId = preset.id)
            }
            .height(56)
          }
        }, (preset: SavedPresetTimer) => preset.id.toString())

        ForEach(this.presets, (preset: PresetTimer) => {
          Button({ type: ButtonType.Normal }) {
            Text(`${preset.emoji} ${this.labelText(preset.label)} · ${this.timerText(preset.seconds)}`)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(SunColor.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 220 })
          }
            .height(44)
            .padding({ left: 16, right: 16 })
            .borderRadius(SunRadius.pill)
            .backgroundColor('#F7F0E5')
            .onClick(() => this.startPreset(preset))
        }, (preset: PresetTimer) => preset.label)
      }
      .height(56)
    }
    .width('100%')
    .height(68)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
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
        Text($r('app.string.simmer_pro_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(4)
          .fontColor(SunColor.ink)

        Column({ space: 14 }) {
          this.paywallFeature('⏱', $r('app.string.simmer_paywall_feature_unlimited'))
          this.paywallFeature('⚡', $r('app.string.simmer_paywall_feature_alerts'))
          this.paywallFeature('★', $r('app.string.simmer_paywall_feature_presets'))
          this.paywallFeature('↺', $r('app.string.simmer_paywall_feature_restart'))
          this.paywallFeature('♥', $r('app.string.simmer_paywall_feature_indie'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Text($r('app.string.simmer_paywall_pitch'))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(SunColor.pebble)
          .lineHeight(17)
          .textAlign(TextAlign.Center)

        SunButton({ label: $r('app.string.simmer_paywall_unlock'), action: () => this.unlockPro() })

        Button($r('app.string.simmer_restore_purchase'))
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(12)
          .fontColor(SunColor.pebble)
          .onClick(() => this.unlockPro())

        Button($r('app.string.simmer_paywall_close'))
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(12)
          .fontColor(SunColor.pebble)
          .onClick(() => this.paywallOpen = false)
      }
      .width('100%')
      .padding(SunSpacing.lg)
      .backgroundColor(SunColor.cream)
      .borderRadius(SunRadius.lg)
    }
  }

  build() {
    Column() {
      SunSafeRoot({ mode: SunMode.Light }) {
      SunToolShell({
        manifest: appProfile,
        showPro: !this.proUnlocked,
        onPro: () => this.showPaywall()
      }) {
        Column() {
          if (this.timers.length === 0) {
            this.emptyState()
          } else {
            this.burnerList()
          }

          this.customPanel()
          this.presetBar()
          this.paywallPanel()
        }
        .width('100%')
        .height('100%')
      }
      }
    }
    .width('100%')
    .height('100%')
  }
}
