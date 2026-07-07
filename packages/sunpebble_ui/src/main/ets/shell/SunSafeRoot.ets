import { SunColor, SunMode } from '../tokens/SunTheme'

@Builder
function emptySafeBody() {}

@Component
export struct SunSafeRoot {
  @Prop
  mode: SunMode = SunMode.Light

  @BuilderParam body: () => void = emptySafeBody

  @StorageLink('sun.inset.top.vp')
  private insetTop: number = 0

  @StorageLink('sun.inset.bottom.vp')
  private insetBottom: number = 0

  private rootBackground(): ResourceColor {
    return this.mode === SunMode.Dark ? SunColor.night : SunColor.cream
  }

  build() {
    Column() {
      this.body()
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.insetTop,
      bottom: this.insetBottom
    })
    .backgroundColor(this.rootBackground())
  }
}