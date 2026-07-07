import { SunAppManifest, SunMode } from 'sunpebble_ui'

export const appProfile: SunAppManifest = {
  name: '{{APP_NAME}}',
  tagline: $r('app.string.{{APP_SLUG}}_tagline'),
  primaryAction: $r('app.string.{{APP_SLUG}}_primary_action'),
  accent: '{{ACCENT}}',
  mode: SunMode.Light
}
