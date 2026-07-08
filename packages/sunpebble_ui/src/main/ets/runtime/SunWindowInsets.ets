import { window, AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class SunWindowInsetsModel {
  @Trace topVp: number = 0
  @Trace bottomVp: number = 0
}

const INSETS_KEY = 'sun.insets.v2'

export function sunInsetTopVp(): number {
  const model = AppStorageV2.connect(SunWindowInsetsModel, INSETS_KEY, () => new SunWindowInsetsModel())
  return model ? model.topVp : 0
}

export function sunInsetBottomVp(): number {
  const model = AppStorageV2.connect(SunWindowInsetsModel, INSETS_KEY, () => new SunWindowInsetsModel())
  return model ? model.bottomVp : 0
}

function applyInsets(mainWindow: window.Window, model: SunWindowInsetsModel): void {
  const systemArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
  const navArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
  const cutoutArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)

  const topPx = Math.max(systemArea.topRect.height, cutoutArea.topRect.height)
  const bottomPx = Math.max(navArea.bottomRect.height, systemArea.bottomRect.height)

  model.topVp = px2vp(topPx)
  model.bottomVp = px2vp(bottomPx)
}

export function bindSunWindowInsets(windowStage: window.WindowStage): void {
  const model = AppStorageV2.connect(SunWindowInsetsModel, INSETS_KEY, () => new SunWindowInsetsModel())!
  try {
    const mainWindow = windowStage.getMainWindowSync()
    // Register before going full screen so the transition's own avoidAreaChange isn't missed.
    mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
      if (data.type !== window.AvoidAreaType.TYPE_KEYBOARD) {
        applyInsets(mainWindow, model)
      }
    })
    // Read avoid areas only AFTER the full-screen transition resolves. A synchronous read here
    // returns the pre-fullscreen (often 0) status-bar height on some devices (e.g. Mate 70),
    // leaving topVp=0 so the immersive header draws under the status bar and overlaps it.
    mainWindow.setWindowLayoutFullScreen(true)
      .then(() => applyInsets(mainWindow, model))
      .catch(() => applyInsets(mainWindow, model))
  } catch (_error) {
    model.topVp = 0
    model.bottomVp = 0
  }
}
