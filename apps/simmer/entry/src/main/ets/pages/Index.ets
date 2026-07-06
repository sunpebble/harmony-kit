import {
  SunColor,
  SunRadius,
  SunSpacing,
  SunToolShell,
  SunType
} from 'sunpebble_ui'
import { appProfile } from '../AppProfile'

interface PresetTimer {
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

  constructor(id: number, label: string, emoji: string, seconds: number, remaining: number, running: boolean, done: boolean, endAt: number) {
    this.id = id
    this.label = label
    this.emoji = emoji
    this.seconds = seconds
    this.remaining = remaining
    this.running = running
    this.done = done
    this.endAt = endAt
  }
}

PersistentStorage.persistProp('simmer.nextId.v1', 1)
PersistentStorage.persistProp('simmer.timers.v1', '')
PersistentStorage.persistProp('simmer.customMinutes.v1', 5)
PersistentStorage.persistProp('simmer.customSeconds.v1', 0)
PersistentStorage.persistProp('simmer.customEmoji.v1', '🍲')

@Component
struct Burner {
  @ObjectLink timer: KitchenTimer
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

  private progress(): number {
    if (this.timer.seconds <= 0 || this.timer.done) {
      return 100
    }
    return Math.max(0, Math.min(100, Math.round((1 - this.timer.remaining / this.timer.seconds) * 100)))
  }

  build() {
    Column({ space: SunSpacing.sm }) {
      Stack() {
        Progress({ value: this.progress(), total: 100, type: ProgressType.Ring })
          .width(150)
          .height(150)
          .color(this.timer.done ? SunColor.sun : SunColor.ink)
          .style({ strokeWidth: 8 })

        Column({ space: SunSpacing.xs }) {
          Text(this.timer.emoji)
            .fontSize(36)

          if (this.timer.done) {
            Text('DONE')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.sun)
          } else {
            Text(this.timerText(this.timer.remaining))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.ink)

            if (!this.timer.running) {
              Text('PAUSED')
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

      Text(this.timer.label.toUpperCase())
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(SunColor.pebble)
        .letterSpacing(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 6 }) {
        this.actionButton('+1m', () => this.onAddMinute(this.timer.id), SunColor.ink)
        this.actionButton('Restart', () => this.onRestart(this.timer.id), SunColor.ink)
        this.actionButton('Cancel', () => this.onCancel(this.timer.id), SunColor.danger)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width(190)
    .height(250)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private actionButton(label: string, action: () => void, color: string) {
    Button(label)
      .height(30)
      .padding({ left: 8, right: 8 })
      .borderRadius(SunRadius.pill)
      .backgroundColor(SunColor.white)
      .fontColor(color)
      .fontSize(10)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: '#D8CFBD' })
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
  private customEmojis: string[] = ['🍲', '🍳', '🥚', '🍝', '🍚', '🥩', '🍞', '🍵']
  private intervalId: number = -1

  @StorageLink('simmer.nextId.v1') private nextId: number = 1
  @StorageLink('simmer.timers.v1') private timersJson: string = ''
  @StorageLink('simmer.customMinutes.v1') private customMinutes: number = 5
  @StorageLink('simmer.customSeconds.v1') private customSeconds: number = 0
  @StorageLink('simmer.customEmoji.v1') private customEmoji: string = '🍲'
  @State private customOpen: boolean = false
  @State private timers: KitchenTimer[] = []

  aboutToAppear(): void {
    this.loadTimers()
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

  private startCustom(): void {
    this.customOpen = !this.customOpen
  }

  private startCustomTimer(): void {
    const seconds = this.customMinutes * 60 + this.customSeconds
    if (seconds <= 0) {
      return
    }
    this.startTimer('Custom', this.customEmoji, seconds)
    this.customOpen = false
  }

  private adjustCustomMinutes(delta: number): void {
    this.customMinutes = Math.max(0, Math.min(180, this.customMinutes + delta))
  }

  private setCustomSeconds(seconds: number): void {
    this.customSeconds = seconds
  }

  private startTimer(label: string, emoji: string, seconds: number): void {
    this.timers = [
      new KitchenTimer(this.nextId, label, emoji, seconds, seconds, true, false, Date.now() + seconds * 1000),
      ...this.timers
    ]
    this.nextId += 1
    this.saveTimers()
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
    } else {
      timer.remaining = timer.remaining > 0 ? timer.remaining : timer.seconds
      timer.running = true
      timer.done = false
      timer.endAt = Date.now() + timer.remaining * 1000
    }
    this.tick()
    this.saveTimers()
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
    this.saveTimers()
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
    } else {
      timer.remaining += 60
      timer.running = true
      timer.done = false
      timer.endAt = Date.now() + timer.remaining * 1000
    }
    this.saveTimers()
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
    this.saveTimers()
  }

  private tick(): void {
    if (!this.timers.some((timer: KitchenTimer) => timer.running)) {
      return
    }

    this.timers.forEach((timer: KitchenTimer) => {
      if (!timer.running) {
        return
      }

      const remaining = this.remainingFromEnd(timer)
      if (remaining > 0) {
        timer.remaining = remaining
        timer.done = false
        return
      }

      this.showDone(timer.label)
      timer.remaining = 0
      timer.running = false
      timer.done = true
      timer.endAt = 0
      this.saveTimers()
    })
  }

  private loadTimers(): void {
    if (this.timersJson.length === 0) {
      return
    }

    try {
      const saved = JSON.parse(this.timersJson) as TimerSnapshot[]
      this.timers = saved.map((timer: TimerSnapshot) => this.restoreTimer(timer))
    } catch (_error) {
      this.timers = []
      this.saveTimers()
    }
  }

  private restoreTimer(timer: TimerSnapshot): KitchenTimer {
    if (!timer.running) {
      return new KitchenTimer(timer.id, timer.label, timer.emoji, timer.seconds, timer.remaining, false, timer.done, 0)
    }

    const remaining = Math.max(0, Math.ceil((timer.endAt - Date.now()) / 1000))
    return new KitchenTimer(timer.id, timer.label, timer.emoji, timer.seconds, remaining, remaining > 0, remaining <= 0, remaining > 0 ? timer.endAt : 0)
  }

  private saveTimers(): void {
    this.timersJson = JSON.stringify(this.timers)
  }

  private remainingFromEnd(timer: KitchenTimer): number {
    return Math.max(0, Math.ceil((timer.endAt - Date.now()) / 1000))
  }

  private showDone(label: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: `${label} is done`,
        duration: 2000
      })
    } catch (_error) {
      // ponytail: toast is best-effort; visible Done state is the fallback.
    }
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

      Text('Nothing on the stove')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(SunColor.ink)

      Text('Tap a preset below to start a timer.\nIt lives on your Lock Screen and\nin the Dynamic Island.')
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
      Row({ space: SunSpacing.lg }) {
        ForEach(this.timers, (timer: KitchenTimer) => {
          Burner({
            timer: timer,
            onTap: (id: number) => this.handleTimerTap(id),
            onAddMinute: (id: number) => this.addMinute(id),
            onRestart: (id: number) => this.restartTimer(id),
            onCancel: (id: number) => this.deleteTimer(id)
          })
        }, (timer: KitchenTimer) => timer.id.toString())
      }
      .padding(SunSpacing.xl)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private customPanel() {
    if (this.customOpen) {
      Column({ space: SunSpacing.md }) {
        Text('CUSTOM TIMER')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
          .fontColor(SunColor.pebble)

        Row({ space: SunSpacing.sm }) {
          ForEach(this.customEmojis, (emoji: string) => {
            Button(emoji)
              .width(38)
              .height(38)
              .borderRadius(999)
              .backgroundColor(this.customEmoji === emoji ? SunColor.sun : SunColor.white)
              .fontSize(20)
              .onClick(() => this.customEmoji = emoji)
          }, (emoji: string) => emoji)
        }
        .width('100%')

        Row({ space: SunSpacing.md }) {
          Button('-')
            .width(38)
            .height(38)
            .borderRadius(999)
            .backgroundColor(SunColor.white)
            .fontColor(SunColor.ink)
            .border({ width: 1, color: '#D8CFBD' })
            .onClick(() => this.adjustCustomMinutes(-1))

          Text(`${this.customMinutes}m ${this.pad(this.customSeconds)}s`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(SunColor.ink)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Button('+')
            .width(38)
            .height(38)
            .borderRadius(999)
            .backgroundColor(SunColor.sun)
            .fontColor(SunColor.ink)
            .onClick(() => this.adjustCustomMinutes(1))
        }
        .width('100%')

        Row({ space: SunSpacing.sm }) {
          this.secondsButton(0)
          this.secondsButton(15)
          this.secondsButton(30)
          this.secondsButton(45)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Button('Start Custom')
          .height(44)
          .width('100%')
          .borderRadius(SunRadius.pill)
          .backgroundColor(SunColor.ink)
          .fontColor(SunColor.cream)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .onClick(() => this.startCustomTimer())
      }
      .width('100%')
      .padding(SunSpacing.lg)
      .backgroundColor('#F7F0E5')
      .border({ width: 1, color: '#D8CFBD' })
      .borderRadius(18)
    }
  }

  @Builder
  private secondsButton(seconds: number) {
    Button(`${seconds}s`)
      .height(32)
      .padding({ left: 12, right: 12 })
      .borderRadius(SunRadius.pill)
      .backgroundColor(this.customSeconds === seconds ? SunColor.sun : SunColor.white)
      .fontColor(SunColor.ink)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: '#D8CFBD' })
      .onClick(() => this.setCustomSeconds(seconds))
  }

  @Builder
  private presetBar() {
    Scroll() {
      Row({ space: 10 }) {
        Button('+  Custom')
          .height(44)
          .padding({ left: 16, right: 16 })
          .borderRadius(SunRadius.pill)
          .backgroundColor(SunColor.cream)
          .fontColor(SunColor.ink)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .border({ width: 1, color: SunColor.pebble })
          .onClick(() => this.startCustom())

        ForEach(this.presets, (preset: PresetTimer) => {
          Button(`${preset.emoji}  ${preset.label} · ${this.timerText(preset.seconds)}`)
            .height(44)
            .padding({ left: 16, right: 16 })
            .borderRadius(SunRadius.pill)
            .backgroundColor('#F7F0E5')
            .fontColor(SunColor.ink)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
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

  build() {
    Column() {
      SunToolShell({
        manifest: appProfile,
        onPrimaryAction: () => this.startCustom()
      }) {
        Column() {
          if (this.timers.length === 0) {
            this.emptyState()
          } else {
            this.burnerList()
          }

          this.customPanel()
          this.presetBar()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
