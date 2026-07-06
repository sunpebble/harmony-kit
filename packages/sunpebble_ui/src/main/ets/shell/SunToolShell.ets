import { SunAppManifest, SunColor, SunMode, SunSpacing, SunType } from '../tokens/SunTheme'
import { SunButton } from '../components/SunButton'

@Builder
function emptyBody() {}

@Component
export struct SunToolShell {
  manifest: SunAppManifest = {
    name: 'Sunpebble',
    tagline: 'Small, polished tools.',
    primaryAction: 'Add',
    accent: SunColor.sun,
    mode: SunMode.Light
  }

  @BuilderParam body: () => void = emptyBody
  onPrimaryAction: () => void = () => {}

  private shellBackground(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? SunColor.night : SunColor.cream
  }

  private foreground(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? SunColor.cream : SunColor.ink
  }

  private secondary(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? '#BFB8AA' : SunColor.pebble
  }

  build() {
    Column() {
      Row({ space: SunSpacing.lg }) {
        Column({ space: SunSpacing.xs }) {
          Text(this.manifest.name)
            .fontSize(SunType.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.foreground())
            .letterSpacing(4)

          if (this.manifest.tagline.length > 0) {
            Text(this.manifest.tagline)
              .fontSize(SunType.body)
              .fontColor(this.secondary())
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.manifest.primaryAction.length > 0) {
          SunButton({
            label: this.manifest.primaryAction,
            action: this.onPrimaryAction
          })
        }
      }
      .width('100%')
      .padding({ bottom: SunSpacing.xl })

      Column() {
        this.body()
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(SunSpacing.xl)
    .backgroundColor(this.shellBackground())
  }
}
