import { SunColor, SunSpacing, SunType } from '../tokens/SunTheme'
import { SunButton, SunButtonRole } from './SunButton'

@Component
export struct SunEmptyState {
  title: string = ''
  message: string = ''
  actionLabel: string = ''
  onAction: () => void = () => {}

  build() {
    Column({ space: SunSpacing.md }) {
      Text(this.title)
        .fontSize(SunType.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(SunColor.ink)
        .textAlign(TextAlign.Center)

      Text(this.message)
        .fontSize(SunType.body)
        .fontColor(SunColor.pebble)
        .textAlign(TextAlign.Center)
        .lineHeight(22)

      if (this.actionLabel.length > 0) {
        SunButton({
          label: this.actionLabel,
          role: SunButtonRole.Primary,
          action: this.onAction
        })
      }
    }
    .width('100%')
    .padding({ top: 56, left: SunSpacing.xl, right: SunSpacing.xl })
  }
}
