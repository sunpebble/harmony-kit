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
  dueAt?: number
  dueIn?: number
  cadence: number
}

interface PresetTask {
  title: string
  area: string
  cadence: number
}

PersistentStorage.persistProp('homekeep.nextId.v1', 1)
PersistentStorage.persistProp('homekeep.filter.v1', 'Due')
PersistentStorage.persistProp('homekeep.tasks.v1', '')

@Entry
@Component
struct Index {
  private presets: PresetTask[] = [
    { title: 'Replace HVAC filter', area: 'Air', cadence: 90 },
    { title: 'Test smoke alarms', area: 'Safety', cadence: 30 },
    { title: 'Clean dishwasher filter', area: 'Kitchen', cadence: 30 },
    { title: 'Flush water heater', area: 'Utility', cadence: 180 }
  ]
  @StorageLink('homekeep.nextId.v1') private nextId: number = 1
  @StorageLink('homekeep.filter.v1') private filter: string = 'Due'
  @StorageLink('homekeep.tasks.v1') private tasksJson: string = ''
  @State private draftTitle: string = ''
  @State private draftArea: string = ''
  @State private draftCadence: number = 30
  @State private tasks: KeepTask[] = []
  @State private confirmingTaskId: number = -1

  aboutToAppear(): void {
    this.loadTasks()
  }

  private loadTasks(): void {
    if (this.tasksJson.length === 0) {
      this.tasks = []
      this.saveTasks()
      return
    }
    try {
      const parsed = JSON.parse(this.tasksJson) as KeepTask[]
      this.tasks = this.normalizeTasks(parsed)
      this.saveTasks()
    } catch (_error) {
      this.tasks = []
      this.saveTasks()
    }
  }

  private saveTasks(): void {
    this.tasksJson = JSON.stringify(this.tasks)
  }

  private dayMs(): number {
    return 24 * 60 * 60 * 1000
  }

  private todayStart(): number {
    const now = new Date()
    return new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  }

  private dueAtFromToday(days: number): number {
    return this.todayStart() + days * this.dayMs()
  }

  private dueAt(task: KeepTask): number {
    if (task.dueAt !== undefined && task.dueAt > 0) {
      return task.dueAt
    }
    return this.dueAtFromToday(task.dueIn === undefined ? 0 : task.dueIn)
  }

  private normalizeTasks(tasks: KeepTask[]): KeepTask[] {
    return tasks.map((task: KeepTask) => {
      const normalized: KeepTask = {
        id: task.id,
        title: task.title,
        area: task.area,
        dueAt: this.dueAt(task),
        cadence: task.cadence
      }
      return normalized
    })
  }

  private daysUntil(task: KeepTask): number {
    return Math.ceil((this.dueAt(task) - this.todayStart()) / this.dayMs())
  }

  private addTask(): void {
    const preset = this.presets[this.tasks.length % this.presets.length]
    this.tasks = [
      ...this.tasks,
      {
        id: this.nextId,
        title: preset.title,
        area: preset.area,
        dueAt: this.dueAtFromToday(preset.cadence),
        cadence: preset.cadence
      }
    ]
    this.nextId += 1
    this.filter = 'All'
    this.confirmingTaskId = -1
    this.saveTasks()
  }

  private addPreset(preset: PresetTask): void {
    this.tasks = [
      ...this.tasks,
      {
        id: this.nextId,
        title: preset.title,
        area: preset.area,
        dueAt: this.dueAtFromToday(preset.cadence),
        cadence: preset.cadence
      }
    ]
    this.nextId += 1
    this.filter = 'All'
    this.confirmingTaskId = -1
    this.saveTasks()
  }

  private addCustomTask(): void {
    const title = this.draftTitle.trim()
    if (title.length === 0) {
      this.showToast('Enter a task name first.')
      return
    }
    const task: KeepTask = {
      id: this.nextId,
      title,
      area: this.draftArea.trim().length > 0 ? this.draftArea.trim() : 'Home',
      dueAt: this.dueAtFromToday(0),
      cadence: this.draftCadence
    }
    this.tasks = [task, ...this.tasks]
    this.nextId += 1
    this.draftTitle = ''
    this.draftArea = ''
    this.filter = 'Due'
    this.confirmingTaskId = -1
    this.saveTasks()
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 1800 })
    } catch (_error) {
      // ponytail: validation still blocks empty custom tasks if toast is unavailable.
    }
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
        dueAt: this.dueAtFromToday(task.cadence),
        cadence: task.cadence
      }
    })
    this.confirmingTaskId = -1
    this.saveTasks()
  }

  private snoozeTask(id: number): void {
    this.tasks = this.tasks.map((task: KeepTask) => {
      if (task.id !== id) {
        return task
      }
      return {
        id: task.id,
        title: task.title,
        area: task.area,
        dueAt: this.dueAtFromToday(7),
        cadence: task.cadence
      }
    })
    this.confirmingTaskId = -1
    this.saveTasks()
  }

  private deleteTask(id: number): void {
    this.tasks = this.tasks.filter((task: KeepTask) => task.id !== id)
    this.confirmingTaskId = -1
    this.saveTasks()
  }

  private visibleTasks(): KeepTask[] {
    if (this.filter === 'All') {
      return this.tasks
    }
    if (this.filter === 'Soon') {
      return this.tasks.filter((task: KeepTask) => this.daysUntil(task) > 0 && this.daysUntil(task) <= 14)
    }
    return this.tasks.filter((task: KeepTask) => this.daysUntil(task) <= 0)
  }

  private dueLabel(task: KeepTask): string {
    const days = this.daysUntil(task)
    if (days < 0) {
      return `${Math.abs(days)}d overdue`
    }
    if (days === 0) {
      return 'Due today'
    }
    return `Due in ${days}d`
  }

  private dueCount(): number {
    return this.tasks.filter((task: KeepTask) => this.daysUntil(task) <= 0).length
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
  private cadenceButton(days: number) {
    Button(`${days}d`)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.draftCadence === days ? '#4F8A6D' : SunColor.white)
      .fontColor(this.draftCadence === days ? SunColor.white : SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => this.draftCadence = days)
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

              if (this.daysUntil(task) <= 0) {
                Row({ space: SunSpacing.sm }) {
                  SunButton({
                    label: 'Mark Done',
                    role: SunButtonRole.Secondary,
                    action: () => this.completeTask(task.id)
                  })

                  SunButton({
                    label: 'Snooze 7d',
                    role: SunButtonRole.Secondary,
                    action: () => this.snoozeTask(task.id)
                  })
                }
                .width('100%')
              }

              if (this.confirmingTaskId === task.id) {
                Row({ space: SunSpacing.sm }) {
                  SunButton({
                    label: 'Confirm Delete',
                    role: SunButtonRole.Danger,
                    action: () => this.deleteTask(task.id)
                  })

                  SunButton({
                    label: 'Cancel',
                    role: SunButtonRole.Secondary,
                    action: () => this.confirmingTaskId = -1
                  })
                }
                .width('100%')
              } else {
                SunButton({
                  label: 'Delete',
                  role: SunButtonRole.Danger,
                  action: () => this.confirmingTaskId = task.id
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
  private customTaskCard() {
    SunCard() {
      Column({ space: SunSpacing.md }) {
        Text('CUSTOM TASK')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.4)
          .fontColor(SunColor.pebble)

        TextInput({ placeholder: 'Task name', text: this.draftTitle })
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.draftTitle = value)

        TextInput({ placeholder: 'Area (optional)', text: this.draftArea })
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.draftArea = value)

        Row({ space: SunSpacing.sm }) {
          this.cadenceButton(7)
          this.cadenceButton(30)
          this.cadenceButton(90)
          this.cadenceButton(180)
        }
        .width('100%')

        SunButton({
          label: 'Add Custom Task',
          action: () => this.addCustomTask()
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
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

          this.customTaskCard()

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
