import { SunAppManifest, SunColor, SunMode, SunSpacing } from '../tokens/SunTheme'
import { SunAppHeader } from './SunAppHeader'
import { SunButton } from '../components/SunButton'

@Builder
function emptyBody() {}

@ComponentV2
export struct SunToolShell {
  @Param manifest: SunAppManifest = {
    name: 'Sunpebble',
    tagline: '',
    primaryAction: '',
    accent: SunColor.sun,
    mode: SunMode.Light
  }

  @BuilderParam body: () => void = emptyBody
  @Param onPrimaryAction: () => void = () => {}

  @Param showPro: boolean = false
  @Param onPro: () => void = () => {}

  private shellBackground(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? SunColor.night : SunColor.cream
  }

  private foreground(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? SunColor.cream : SunColor.ink
  }

  private secondary(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? SunColor.darkSecondary : SunColor.pebble
  }

  build() {
    Column() {
      SunAppHeader({
        manifest: this.manifest,
        showPro: this.showPro,
        onPro: this.onPro
      })

      if (this.manifest.primaryAction) {
        Row() {
          Blank().layoutWeight(1)
          SunButton({
            label: this.manifest.primaryAction,
            action: this.onPrimaryAction
          })
        }
        .width('100%')
        .padding({
          left: SunSpacing.xl,
          right: SunSpacing.xl,
          top: SunSpacing.sm,
          bottom: SunSpacing.sm
        })
      }

      Column() {
        this.body()
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: SunSpacing.xl, right: SunSpacing.xl })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: SunSpacing.md })
    .backgroundColor(this.shellBackground())
  }
}
