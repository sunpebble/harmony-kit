import { window } from '@kit.ArkUI'

const KEY_TOP = 'sun.inset.top.vp'
const KEY_BOTTOM = 'sun.inset.bottom.vp'

export function sunInsetTopVp(): number {
  return AppStorage.get<number>(KEY_TOP) ?? 0
}

export function sunInsetBottomVp(): number {
  return AppStorage.get<number>(KEY_BOTTOM) ?? 0
}

function applyInsets(mainWindow: window.Window): void {
  const systemArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
  const navArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
  const cutoutArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)

  const topPx = Math.max(systemArea.topRect.height, cutoutArea.topRect.height)
  const bottomPx = Math.max(navArea.bottomRect.height, systemArea.bottomRect.height)

  AppStorage.setOrCreate(KEY_TOP, px2vp(topPx))
  AppStorage.setOrCreate(KEY_BOTTOM, px2vp(bottomPx))
}

export function bindSunWindowInsets(windowStage: window.WindowStage): void {
  try {
    const mainWindow = windowStage.getMainWindowSync()
    mainWindow.setWindowLayoutFullScreen(true)
    applyInsets(mainWindow)
    mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
      if (data.type !== window.AvoidAreaType.TYPE_KEYBOARD) {
        applyInsets(mainWindow)
      }
    })
  } catch (_error) {
    AppStorage.setOrCreate(KEY_TOP, 0)
    AppStorage.setOrCreate(KEY_BOTTOM, 0)
  }
}