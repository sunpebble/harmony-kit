import { SunCard, SunEmptyState, SunListRow, SunToolShell } from 'sunpebble_ui'
import { appProfile } from '../AppProfile'

@Entry
@Component
struct Index {
  @State private items: string[] = []

  private addSample(): void {
    this.items = [...this.items, `Item ${this.items.length + 1}`]
  }

  build() {
    Column() {
      SunToolShell({
        manifest: appProfile,
        onPrimaryAction: () => this.addSample()
      }) {
        if (this.items.length === 0) {
          SunEmptyState({
            title: 'Nothing here yet',
            message: 'Start with one useful record. The shell stays the same across apps.',
            actionLabel: appProfile.primaryAction,
            onAction: () => this.addSample()
          })
        } else {
          SunCard() {
            ForEach(this.items, (item: string) => {
              SunListRow({
                title: item,
                caption: 'Replace this row with the app workflow.'
              })
            }, (item: string) => item)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
