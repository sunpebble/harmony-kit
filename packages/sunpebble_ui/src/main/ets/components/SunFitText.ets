import { SunColor } from '../tokens/SunTheme'

@ComponentV2
export struct SunFitText {
  @Param
  text: ResourceStr = ''

  @Param
  maxFontSize: number = 12

  @Param
  minFontSize: number = 8

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
      .fontSize(this.maxFontSize)
      .minFontSize(this.minFontSize)
      .maxFontSize(this.maxFontSize)
      .fontColor(this.fontColor)
      .fontWeight(this.fontWeight)
      .letterSpacing(this.letterSpacing)
      .maxLines(this.maxLines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .textAlign(this.textAlign)
      .width('100%')
  }
}