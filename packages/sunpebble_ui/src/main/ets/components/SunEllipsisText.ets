import { SunColor, SunType } from '../tokens/SunTheme'

@ComponentV2
export struct SunEllipsisText {
  @Param
  text: ResourceStr = ''

  @Param
  fontSize: number = SunType.body

  @Param
  fontColor: ResourceColor = SunColor.ink

  @Param
  fontWeight: FontWeight = FontWeight.Regular

  @Param
  maxLines: number = 1

  @Param
  textAlign: TextAlign = TextAlign.Start

  @Param
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