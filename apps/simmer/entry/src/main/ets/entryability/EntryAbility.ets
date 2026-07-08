import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window, KeyboardAvoidMode } from '@kit.ArkUI'
import { bindSunWindowInsets } from 'sunpebble_ui'

const DOMAIN = 0xC0DE

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
    hilog.info(DOMAIN, 'Simmer', 'Ability onCreate')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    bindSunWindowInsets(windowStage)
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'Simmer', 'Failed to load page: %{public}s', JSON.stringify(err))
        return
      }
      // Default OFFSET keyboard avoidance shifts the whole window up, pushing the top
      // safe-area padding (header) into the status bar. RESIZE shrinks instead — header stays.
      windowStage.getMainWindowSync().getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
      hilog.info(DOMAIN, 'Simmer', 'Loaded Index page')
    })
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'Simmer', 'Ability onForeground')
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'Simmer', 'Ability onBackground')
  }
}
