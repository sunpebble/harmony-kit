export enum SunMode {
  Light = 'light',
  Dark = 'dark'
}

export class SunColor {
  static readonly cream: string = '#FFF6E8'
  static readonly ink: string = '#232733'
  static readonly sun: string = '#F7B733'
  static readonly pebble: string = '#6E6E73'
  static readonly night: string = '#161928'
  static readonly white: string = '#FFFFFF'
  static readonly border: string = '#E6DCCB'
  static readonly danger: string = '#B82118'
  static readonly disabledBg: string = '#E9DDCA'
  static readonly darkSecondary: string = '#BFB8AA'
  static readonly hairline: string = '#D8CFBD'
  static readonly panelTint: string = '#F7F0E5'
}

export class SunSpacing {
  static readonly xs: number = 4
  static readonly sm: number = 8
  static readonly md: number = 12
  static readonly lg: number = 16
  static readonly xl: number = 24
  static readonly xxl: number = 32
}

export class SunRadius {
  static readonly sm: number = 8
  static readonly md: number = 12
  static readonly lg: number = 16
  static readonly pill: number = 999
}

export class SunType {
  static readonly caption: number = 12
  static readonly body: number = 15
  static readonly title: number = 20
  static readonly display: number = 28
}

export interface SunAppManifest {
  name: ResourceStr
  tagline: ResourceStr
  primaryAction: ResourceStr
  // ponytail: accent is app-identity data; intentionally NOT consumed by SunToolShell
  // button color, to prevent per-app styling drift (PRODUCT.md). Surfaced for widgets/future use.
  accent: ResourceColor
  mode: SunMode
}
