import { SunColor, SunSpacing, SunType } from '../tokens/SunTheme'

@Component
export struct SunListRow {
  title: string = ''
  value: string = ''
  caption: string = ''
  action: () => void = () => {}

  build() {
    Row({ space: SunSpacing.md }) {
      Column({ space: SunSpacing.xs }) {
        Text(this.title)
          .fontSize(SunType.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(SunColor.ink)

        if (this.caption.length > 0) {
          Text(this.caption)
            .fontSize(SunType.caption)
            .fontColor(SunColor.pebble)
            .lineHeight(18)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.value.length > 0) {
        Text(this.value)
          .fontSize(SunType.body)
          .fontColor(SunColor.pebble)
      }
    }
    .width('100%')
    .height(56)
    .padding({ top: SunSpacing.sm, bottom: SunSpacing.sm })
    .border({ width: { bottom: 1 }, color: SunColor.border })
    .onClick(() => this.action())
  }
}
