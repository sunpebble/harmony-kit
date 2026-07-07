import { SunCard, SunEmptyState, SunListRow, SunToolShell } from 'sunpebble_ui'
import { appProfile } from '../AppProfile'

@Entry
@Component
struct Index {
  @State private items: number[] = []

  private addSample(): void {
    this.items = [...this.items, this.items.length + 1]
  }

  build() {
    Column() {
      SunToolShell({
        manifest: appProfile,
        onPrimaryAction: () => this.addSample()
      }) {
        if (this.items.length === 0) {
          SunEmptyState({
            title: $r('app.string.{{APP_SLUG}}_empty_title'),
            message: $r('app.string.{{APP_SLUG}}_empty_message'),
            actionLabel: appProfile.primaryAction,
            onAction: () => this.addSample()
          })
        } else {
          SunCard() {
            ForEach(this.items, (item: number) => {
              SunListRow({
                title: $r('app.string.{{APP_SLUG}}_item_format', item),
                caption: $r('app.string.{{APP_SLUG}}_row_caption')
              })
            }, (item: number) => `${item}`)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
