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

interface KeepTask {
  id: number
  title: string
  area: string
  dueIn: number
  cadence: number
}

interface PresetTask {
  title: string
  area: string
  cadence: number
}

@Entry
@Component
struct Index {
  private presets: PresetTask[] = [
    { title: 'Replace HVAC filter', area: 'Air', cadence: 90 },
    { title: 'Test smoke alarms', area: 'Safety', cadence: 30 },
    { title: 'Clean dishwasher filter', area: 'Kitchen', cadence: 30 },
    { title: 'Flush water heater', area: 'Utility', cadence: 180 }
  ]
  @State private nextId: number = 4
  @State private filter: string = 'Due'
  @State private tasks: KeepTask[] = [
    { id: 1, title: 'Replace HVAC filter', area: 'Air', dueIn: -2, cadence: 90 },
    { id: 2, title: 'Test smoke alarms', area: 'Safety', dueIn: 5, cadence: 30 },
    { id: 3, title: 'Clean dishwasher filter', area: 'Kitchen', dueIn: 16, cadence: 30 }
  ]

  private addTask(): void {
    const preset = this.presets[this.tasks.length % this.presets.length]
    this.tasks = [
      ...this.tasks,
      {
        id: this.nextId,
        title: preset.title,
        area: preset.area,
        dueIn: preset.cadence,
        cadence: preset.cadence
      }
    ]
    this.nextId += 1
  }

  private addPreset(preset: PresetTask): void {
    this.tasks = [
      ...this.tasks,
      {
        id: this.nextId,
        title: preset.title,
        area: preset.area,
        dueIn: preset.cadence,
        cadence: preset.cadence
      }
    ]
    this.nextId += 1
  }

  private completeTask(id: number): void {
    this.tasks = this.tasks.map((task: KeepTask) => {
      if (task.id !== id) {
        return task
      }
      return {
        id: task.id,
        title: task.title,
        area: task.area,
        dueIn: task.cadence,
        cadence: task.cadence
      }
    })
  }

  private visibleTasks(): KeepTask[] {
    if (this.filter === 'All') {
      return this.tasks
    }
    if (this.filter === 'Soon') {
      return this.tasks.filter((task: KeepTask) => task.dueIn > 0 && task.dueIn <= 14)
    }
    return this.tasks.filter((task: KeepTask) => task.dueIn <= 0)
  }

  private dueLabel(task: KeepTask): string {
    if (task.dueIn < 0) {
      return `${Math.abs(task.dueIn)}d overdue`
    }
    if (task.dueIn === 0) {
      return 'Due today'
    }
    return `Due in ${task.dueIn}d`
  }

  private dueCount(): number {
    return this.tasks.filter((task: KeepTask) => task.dueIn <= 0).length
  }

  @Builder
  private filterButton(label: string) {
    Button(label)
      .height(36)
      .padding({ left: 14, right: 14 })
      .borderRadius(999)
      .backgroundColor(this.filter === label ? '#4F8A6D' : SunColor.white)
      .fontColor(this.filter === label ? SunColor.white : SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.filter = label)
  }

  @Builder
  private summary() {
    SunCard() {
      Row() {
        Column({ space: SunSpacing.xs }) {
          Text(this.dueCount().toString())
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.dueCount() > 0 ? SunColor.danger : '#4F8A6D')
          Text('DUE NOW')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.5)
            .fontColor(SunColor.pebble)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: SunSpacing.xs }) {
          Text(this.tasks.length.toString())
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(SunColor.ink)
          Text('TASKS')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.5)
            .fontColor(SunColor.pebble)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
    }
  }

  @Builder
  private taskList() {
    SunCard() {
      Column({ space: SunSpacing.sm }) {
        if (this.visibleTasks().length === 0) {
          Text('Nothing due in this view.')
            .fontSize(SunType.body)
            .fontColor(SunColor.pebble)
            .padding({ top: SunSpacing.lg, bottom: SunSpacing.lg })
        } else {
          ForEach(this.visibleTasks(), (task: KeepTask) => {
            Column({ space: SunSpacing.sm }) {
              SunListRow({
                title: task.title,
                value: this.dueLabel(task),
                caption: `${task.area} · every ${task.cadence}d`
              })

              if (task.dueIn <= 0) {
                SunButton({
                  label: 'Mark Done',
                  role: SunButtonRole.Secondary,
                  action: () => this.completeTask(task.id)
                })
              }
            }
            .width('100%')
          }, (task: KeepTask) => task.id.toString())
        }
      }
      .width('100%')
    }
  }

  @Builder
  private presetBar() {
    Scroll() {
      Row({ space: SunSpacing.sm }) {
        ForEach(this.presets, (preset: PresetTask) => {
          Button(`+ ${preset.title}`)
            .height(42)
            .padding({ left: 14, right: 14 })
            .borderRadius(999)
            .backgroundColor('#EDF4EF')
            .fontColor(SunColor.ink)
            .fontSize(12)
            .onClick(() => this.addPreset(preset))
        }, (preset: PresetTask) => preset.title)
      }
    }
    .width('100%')
    .height(52)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  build() {
    Column() {
      SunToolShell({
        manifest: appProfile,
        onPrimaryAction: () => this.addTask()
      }) {
        Column({ space: SunSpacing.md }) {
          this.summary()

          Row({ space: SunSpacing.sm }) {
            this.filterButton('Due')
            this.filterButton('Soon')
            this.filterButton('All')
          }
          .width('100%')

          Scroll() {
            this.taskList()
          }
          .width('100%')
          .layoutWeight(1)

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
