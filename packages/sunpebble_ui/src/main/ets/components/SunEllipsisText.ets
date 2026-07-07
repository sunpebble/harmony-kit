import { SunColor, SunType } from '../tokens/SunTheme'

@Component
export struct SunEllipsisText {
  @Prop
  text: ResourceStr = ''

  @Prop
  fontSize: number = SunType.body

  @Prop
  fontColor: ResourceColor = SunColor.ink

  @Prop
  fontWeight: FontWeight = FontWeight.Regular

  @Prop
  maxLines: number = 1

  @Prop
  textAlign: TextAlign = TextAlign.Start

  @Prop
  letterSpacing: number = 0

  build() {
    Text(this.text)
      .fontSize(this.fontSize)
      .fontColor(this.fontColor)
      .fontWeight(this.fontWeight)
      .letterSpacing(this.letterSpacing)
      .maxLines(this.maxLines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .textAlign(this.textAlign)
      .width('100%')
  }
}