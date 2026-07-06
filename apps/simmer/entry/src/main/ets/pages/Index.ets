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

@Component
struct Burner {
  @ObjectLink timer: KitchenTimer
  onTap: (id: number) => void = (_id: number) => {}

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

      Text(this.timer.label.toUpperCase())
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(SunColor.pebble)
        .letterSpacing(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(170)
    .height(205)
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.onTap(this.timer.id))
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
  private nextId: number = 1
  private intervalId: number = -1

  @State private timers: KitchenTimer[] = []

  aboutToAppear(): void {
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
    this.startTimer('Timer', '🍲', 5 * 60)
  }

  private startTimer(label: string, emoji: string, seconds: number): void {
    this.timers = [
      new KitchenTimer(this.nextId, label, emoji, seconds, seconds, true, false, Date.now() + seconds * 1000),
      ...this.timers
    ]
    this.nextId += 1
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
    })
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
            onTap: (id: number) => this.handleTimerTap(id)
          })
        }, (timer: KitchenTimer) => timer.id.toString())
      }
      .padding(SunSpacing.xl)
    }
    .width('100%')
    .layoutWeight(1)
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
