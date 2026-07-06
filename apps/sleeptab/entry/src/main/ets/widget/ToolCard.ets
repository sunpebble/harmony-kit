import { SunColor, SunRadius, SunSpacing, SunType } from 'sunpebble_ui'
import { appProfile } from '../AppProfile'

@Component
export struct ToolCard {
  value: string = '--'
  label: string = 'Ready'

  build() {
    Column({ space: SunSpacing.xs }) {
      Text(appProfile.name)
        .fontSize(SunType.caption)
        .fontWeight(FontWeight.Medium)
        .fontColor(SunColor.pebble)

      Text(this.value)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(SunColor.ink)

      Text(this.label)
        .fontSize(SunType.caption)
        .fontColor(SunColor.pebble)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height('100%')
    .padding(SunSpacing.lg)
    .backgroundColor(SunColor.cream)
    .borderRadius(SunRadius.lg)
  }
}
