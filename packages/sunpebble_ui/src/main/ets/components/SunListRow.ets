import { SunColor, SunSpacing, SunType } from '../tokens/SunTheme'

@Component
export struct SunListRow {
  @Prop
  title: ResourceStr = ''
  @Prop
  value: ResourceStr = ''
  @Prop
  caption: ResourceStr = ''
  action: () => void = () => {}

  build() {
    Row({ space: SunSpacing.md }) {
      Column({ space: SunSpacing.xs }) {
        Text(this.title)
          .fontSize(SunType.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(SunColor.ink)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.caption) {
          Text(this.caption)
            .fontSize(SunType.caption)
            .fontColor(SunColor.pebble)
            .lineHeight(18)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.value) {
        Text(this.value)
          .fontSize(SunType.body)
          .fontColor(SunColor.pebble)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexShrink(0)
          .constraintSize({ maxWidth: '40%' })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ top: SunSpacing.sm, bottom: SunSpacing.sm })
    .border({ width: { bottom: 1 }, color: SunColor.border })

    .onClick(() => this.action())
  }
}
