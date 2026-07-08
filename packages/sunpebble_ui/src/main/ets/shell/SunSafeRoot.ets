import { AppStorageV2 } from '@kit.ArkUI'
import { SunColor, SunMode } from '../tokens/SunTheme'
import { SunWindowInsetsModel } from '../runtime/SunWindowInsets'

@Builder
function emptySafeBody() {}

@ComponentV2
export struct SunSafeRoot {
  @Param mode: SunMode = SunMode.Light

  @BuilderParam body: () => void = emptySafeBody

  @Local insets: SunWindowInsetsModel =
    AppStorageV2.connect(SunWindowInsetsModel, 'sun.insets.v2', () => new SunWindowInsetsModel())!

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
      top: this.insets.topVp,
      bottom: this.insets.bottomVp
    })
    .backgroundColor(this.rootBackground())
  }
}
