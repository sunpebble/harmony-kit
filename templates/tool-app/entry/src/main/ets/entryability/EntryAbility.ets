import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'

const DOMAIN = 0xC0DE

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    hilog.info(DOMAIN, '{{APP_NAME}}', 'Ability onCreate')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, '{{APP_NAME}}', 'Failed to load page: %{public}s', JSON.stringify(err))
        return
      }
      hilog.info(DOMAIN, '{{APP_NAME}}', 'Loaded Index page')
    })
  }
}
