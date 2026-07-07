import { SunColor, SunRadius, SunSpacing } from '../tokens/SunTheme'

@Builder
function emptyContent() {}

@ComponentV2
export struct SunCard {
  @BuilderParam content: () => void = emptyContent

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(SunSpacing.lg)
    .backgroundColor(SunColor.white)
    .borderRadius(SunRadius.md)
    .border({ width: 1, color: SunColor.border })
  }
}
