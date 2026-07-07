import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { bindSunWindowInsets } from 'sunpebble_ui'

const DOMAIN = 0xC0DE

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
    hilog.info(DOMAIN, 'Dayroll', 'Ability onCreate')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    bindSunWindowInsets(windowStage)
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'Dayroll', 'Failed to load page: %{public}s', JSON.stringify(err))
        return
      }
      hilog.info(DOMAIN, 'Dayroll', 'Loaded Index page')
    })
  }
}
