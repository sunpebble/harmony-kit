import { SunAppManifest, SunColor, SunMode, SunSpacing, SunType } from '../tokens/SunTheme'

@Component
export struct SunAppHeader {
  manifest: SunAppManifest = {
    name: 'Sunpebble',
    tagline: '',
    primaryAction: '',
    accent: SunColor.sun,
    mode: SunMode.Light
  }

  @Prop
  showPro: boolean = false

  onPro: () => void = () => {}

  private foreground(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? SunColor.cream : SunColor.ink
  }

  private secondary(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? SunColor.darkSecondary : SunColor.pebble
  }

  build() {
    Row() {
      Column({ space: SunSpacing.xs }) {
        Text(this.manifest.name)
          .fontSize(SunType.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.foreground())
          .letterSpacing(4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.manifest.tagline) {
          Text(this.manifest.tagline)
            .fontSize(SunType.body)
            .fontColor(this.secondary())
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.showPro) {
        Button($r('app.string.sun_header_pro'))
          .height(36)
          .responseRegion({ x: 0, y: -4, width: '100%', height: 44 })
          .padding({ left: SunSpacing.md, right: SunSpacing.md })
          .borderRadius(999)
          .backgroundColor(Color.Transparent)
          .fontColor(this.foreground())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .onClick(() => this.onPro())
      }
    }
    .width('100%')
    .padding({
      left: SunSpacing.xl,
      right: SunSpacing.xl,
      top: SunSpacing.sm,
      bottom: SunSpacing.md
    })
  }
}