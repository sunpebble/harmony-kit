import {
  SunButton,
  SunButtonRole,
  SunCard,
  SunColor,
  SunListRow,
  SunMode,
  SunSafeRoot,
  SunSpacing,
  SunToolShell,
  SunType
} from 'sunpebble_ui'
import { common } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
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
@ComponentV2
struct Index {
  private presets: PresetTask[] = [
    { title: 'Replace HVAC filter', area: 'Air', cadence: 90 },
    { title: 'Test smoke alarms', area: 'Safety', cadence: 30 },
    { title: 'Clean dishwasher filter', area: 'Kitchen', cadence: 30 },
    { title: 'Flush water heater', area: 'Utility', cadence: 180 }
  ]
  @Local private nextId: number = 1
  @Local private filter: string = 'Due'
  @Local private tasksJson: string = ''
  @Local private draftTitle: string = ''
  @Local private draftArea: string = ''
  @Local private draftCadence: number = 30
  @Local private tasks: KeepTask[] = []
  @Local private confirmingTaskId: number = -1
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.nextId = AppStorage.get<number>('homekeep.nextId.v1') ?? 1
    this.filter = AppStorage.get<string>('homekeep.filter.v1') ?? 'Due'
    this.tasksJson = AppStorage.get<string>('homekeep.tasks.v1') ?? ''
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
    AppStorage.setOrCreate('homekeep.tasks.v1', this.tasksJson)
  }

  private saveTasksAndSyncReminders(): void {
    this.saveTasks()
    this.syncReminders()
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
    const usedIds: number[] = []
    let nextId = Math.max(1, this.nextId)
    const normalized = tasks.map((task: KeepTask) => {
      let id = task.id
      if (!id || id <= 0 || usedIds.includes(id)) {
        while (usedIds.includes(nextId)) {
          nextId += 1
        }
        id = nextId
      }
      usedIds.push(id)
      nextId = Math.max(nextId, id + 1)
      const cadence = task.cadence > 0 ? task.cadence : 30
      const taskWithId: KeepTask = {
        id,
        title: task.title && task.title.length > 0 ? task.title : 'Home task',
        area: task.area && task.area.length > 0 ? task.area : 'Home',
        dueAt: this.dueAt(task),
        cadence
      }
      return taskWithId
    })
    this.nextId = nextId
    AppStorage.setOrCreate('homekeep.nextId.v1', this.nextId)
    return normalized
  }

  private daysUntil(task: KeepTask): number {
    return Math.round((this.dueAt(task) - this.todayStart()) / this.dayMs())
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
    AppStorage.setOrCreate('homekeep.nextId.v1', this.nextId)
    this.filter = 'All'
    AppStorage.setOrCreate('homekeep.filter.v1', this.filter)
    this.confirmingTaskId = -1
    this.saveTasksAndSyncReminders()
  }

  private addCustomTask(): void {
    const title = this.draftTitle.trim()
    if (title.length === 0) {
      this.showToast($r('app.string.homekeep_toast_enter_name'))
      return
    }
    const task: KeepTask = {
      id: this.nextId,
      title,
      area: this.draftArea.trim().length > 0 ? this.draftArea.trim() : 'Home',
      dueAt: this.dueAtFromToday(this.draftCadence),
      cadence: this.draftCadence
    }
    this.tasks = [task, ...this.tasks]
    this.nextId += 1
    AppStorage.setOrCreate('homekeep.nextId.v1', this.nextId)
    this.draftTitle = ''
    this.draftArea = ''
    this.draftCadence = 30
    this.filter = 'All'
    AppStorage.setOrCreate('homekeep.filter.v1', this.filter)
    this.confirmingTaskId = -1
    this.saveTasksAndSyncReminders()
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 1800 })
    } catch (_error) {
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
    this.saveTasksAndSyncReminders()
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
    this.saveTasksAndSyncReminders()
  }

  private deleteTask(id: number): void {
    this.tasks = this.tasks.filter((task: KeepTask) => task.id !== id)
    this.confirmingTaskId = -1
    this.saveTasksAndSyncReminders()
  }

  private async syncReminders(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders()
      if (this.tasks.length === 0 || !await this.requestNotificationAccess()) {
        return
      }
      const now = Date.now()
      for (const task of this.tasks) {
        const due = new Date(this.dueAt(task))
        due.setHours(9, 0, 0, 0)
        if (due.getTime() <= now) {
          due.setTime(now)
          due.setDate(due.getDate() + 1)
          due.setHours(9, 0, 0, 0)
        }
        const request: reminderAgentManager.ReminderRequestCalendar = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          dateTime: {
            year: due.getFullYear(),
            month: due.getMonth() + 1,
            day: due.getDate(),
            hour: due.getHours(),
            minute: due.getMinutes(),
            second: 0
          },
          title: this.resolveText($r('app.string.EntryAbility_label'), 'Homekeep'),
          content: `${this.titleText(task.title)} · ${this.areaText(task.area)}`,
          expiredContent: this.formatText($r('app.string.homekeep_reminder_expired_format'), this.titleText(task.title), `${task.title} is due.`),
          notificationId: 300000 + task.id,
          tapDismissed: true
        }
        await reminderAgentManager.publishReminder(request)
      }
    } catch (_error) {
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

  private visibleTasks(): KeepTask[] {
    if (this.filter === 'All') {
      return this.tasks
    }
    if (this.filter === 'Soon') {
      return this.tasks.filter((task: KeepTask) => this.daysUntil(task) > 0 && this.daysUntil(task) <= 14)
    }
    return this.tasks.filter((task: KeepTask) => this.daysUntil(task) <= 0)
  }

  private dueLabel(task: KeepTask): ResourceStr {
    const days = this.daysUntil(task)
    if (days < 0) {
      return $r('app.string.homekeep_due_overdue_format', Math.abs(days))
    }
    if (days === 0) {
      return $r('app.string.homekeep_due_today')
    }
    return $r('app.string.homekeep_due_in_format', days)
  }

  // Display mapping only: stored task titles/areas stay English (they are persisted data).
  private titleResource(title: string): Resource | undefined {
    if (title === 'Replace HVAC filter') {
      return $r('app.string.homekeep_preset_hvac')
    }
    if (title === 'Test smoke alarms') {
      return $r('app.string.homekeep_preset_smoke')
    }
    if (title === 'Clean dishwasher filter') {
      return $r('app.string.homekeep_preset_dishwasher')
    }
    if (title === 'Flush water heater') {
      return $r('app.string.homekeep_preset_water_heater')
    }
    if (title === 'Home task') {
      return $r('app.string.homekeep_task_fallback')
    }
    return undefined
  }

  private areaResource(area: string): Resource | undefined {
    if (area === 'Air') {
      return $r('app.string.homekeep_area_air')
    }
    if (area === 'Safety') {
      return $r('app.string.homekeep_area_safety')
    }
    if (area === 'Kitchen') {
      return $r('app.string.homekeep_area_kitchen')
    }
    if (area === 'Utility') {
      return $r('app.string.homekeep_area_utility')
    }
    if (area === 'Home') {
      return $r('app.string.homekeep_area_home')
    }
    return undefined
  }

  private titleLabel(title: string): ResourceStr {
    const res = this.titleResource(title)
    return res !== undefined ? res : title
  }

  private resolveText(res: Resource, fallback: string): string {
    const context = this.getUIContext().getHostContext()
    if (!context) {
      return fallback
    }
    try {
      return context.resourceManager.getStringSync(res.id)
    } catch (_error) {
      return fallback
    }
  }

  private formatText(res: Resource, arg: string, fallback: string): string {
    const context = this.getUIContext().getHostContext()
    if (!context) {
      return fallback
    }
    try {
      return context.resourceManager.getStringSync(res.id, arg)
    } catch (_error) {
      return fallback
    }
  }

  private titleText(title: string): string {
    const res = this.titleResource(title)
    return res !== undefined ? this.resolveText(res, title) : title
  }

  private areaText(area: string): string {
    const res = this.areaResource(area)
    return res !== undefined ? this.resolveText(res, area) : area
  }

  private dueCount(): number {
    return this.tasks.filter((task: KeepTask) => this.daysUntil(task) <= 0).length
  }

  @Builder
  private filterButton(id: string, label: Resource) {
    // id is the stored filter key ('Due'/'Soon'/'All'); label is display-only.
    Button(label)
      .height(36)
      .padding({ left: 14, right: 14 })
      .borderRadius(999)
      .backgroundColor(this.filter === id ? appProfile.accent : SunColor.white)
      .fontColor(this.filter === id ? SunColor.white : SunColor.ink)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .border({ width: 1, color: SunColor.border })
      .onClick(() => {
        this.filter = id
        AppStorage.setOrCreate('homekeep.filter.v1', this.filter)
      })
  }

  @Builder
  private cadenceButton(days: number) {
    Button($r('app.string.homekeep_days_format', days))
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(999)
      .backgroundColor(this.draftCadence === days ? appProfile.accent : SunColor.white)
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
            .fontColor(this.dueCount() > 0 ? SunColor.danger : appProfile.accent)
          Text($r('app.string.homekeep_due_now'))
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
          Text($r('app.string.homekeep_tasks'))
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
          Text($r('app.string.homekeep_empty_list'))
            .fontSize(SunType.body)
            .fontColor(SunColor.pebble)
            .padding({ top: SunSpacing.lg, bottom: SunSpacing.lg })
        } else {
          ForEach(this.visibleTasks(), (task: KeepTask) => {
            Column({ space: SunSpacing.sm }) {
              SunListRow({
                title: this.titleLabel(task.title),
                value: this.dueLabel(task),
                caption: $r('app.string.homekeep_task_caption_format', this.areaText(task.area), task.cadence)
              })

              Row({ space: SunSpacing.sm }) {
                SunButton({
                  label: $r('app.string.homekeep_mark_done'),
                  role: SunButtonRole.Secondary,
                  action: () => this.completeTask(task.id)
                })

                if (this.daysUntil(task) <= 0) {
                  SunButton({
                    label: $r('app.string.homekeep_snooze_7d'),
                    role: SunButtonRole.Secondary,
                    action: () => this.snoozeTask(task.id)
                  })
                }
              }
              .width('100%')

              if (this.confirmingTaskId === task.id) {
                Row({ space: SunSpacing.sm }) {
                  SunButton({
                    label: $r('app.string.homekeep_confirm_delete'),
                    role: SunButtonRole.Danger,
                    action: () => this.deleteTask(task.id)
                  })

                  SunButton({
                    label: $r('app.string.homekeep_cancel'),
                    role: SunButtonRole.Secondary,
                    action: () => this.confirmingTaskId = -1
                  })
                }
                .width('100%')
              } else {
                SunButton({
                  label: $r('app.string.homekeep_delete'),
                  role: SunButtonRole.Danger,
                  action: () => this.confirmingTaskId = task.id
                })
              }
            }
            .width('100%')
          }, (task: KeepTask) => `${task.id}-${task.dueAt}`)
        }
      }
      .width('100%')
    }
  }

  @Builder
  private customTaskCard() {
    SunCard() {
      Column({ space: SunSpacing.md }) {
        Text($r('app.string.homekeep_custom_task'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.4)
          .fontColor(SunColor.pebble)

        TextInput({ placeholder: $r('app.string.homekeep_task_name_placeholder'), text: this.draftTitle })
          .id('draftTitle')
          .height(46)
          .width('100%')
          .fontSize(14)
          .fontColor(SunColor.ink)
          .backgroundColor(SunColor.white)
          .borderRadius(8)
          .border({ width: 1, color: SunColor.border })
          .onChange((value: string) => this.draftTitle = value)

        TextInput({ placeholder: $r('app.string.homekeep_area_placeholder'), text: this.draftArea })
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
          label: $r('app.string.homekeep_add_custom_task'),
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
          Button({ type: ButtonType.Normal }) {
            Text($r('app.string.homekeep_preset_add_format', this.titleText(preset.title)))
              .fontSize(12)
              .fontColor(SunColor.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 200 })
          }
            .height(42)
            .padding({ left: 14, right: 14 })
            .borderRadius(999)
            .backgroundColor(SunColor.panelTint)
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
      SunSafeRoot({ mode: SunMode.Light }) {
      SunToolShell({
        manifest: appProfile,
        onPrimaryAction: () => {
          if (this.tasks.length > 0) {
            this.scroller.scrollEdge(Edge.Bottom)
          }
          try {
            this.getUIContext().getFocusController().requestFocus('draftTitle')
          } catch (_e) {
          }
        },
        showPro: false,
        onPro: () => {}
      }) {
        Column({ space: SunSpacing.md }) {
          this.summary()

          Row({ space: SunSpacing.sm }) {
            this.filterButton('Due', $r('app.string.homekeep_filter_due'))
            this.filterButton('Soon', $r('app.string.homekeep_filter_soon'))
            this.filterButton('All', $r('app.string.homekeep_filter_all'))
          }
          .width('100%')

          Scroll(this.scroller) {
            Column({ space: SunSpacing.md }) {
              if (this.tasks.length === 0) {
                this.customTaskCard()
                this.taskList()
              } else {
                this.taskList()
                this.customTaskCard()
              }
            }
            .width('100%')
            .padding({ bottom: SunSpacing.lg })
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)

          this.presetBar()
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
