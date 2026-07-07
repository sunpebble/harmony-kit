import { SunColor } from '../tokens/SunTheme'

@Component
export struct SunFitText {
  @Prop
  text: ResourceStr = ''

  @Prop
  maxFontSize: number = 12

  @Prop
  minFontSize: number = 8

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