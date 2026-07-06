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
  name: string
  tagline: string
  primaryAction: string
  accent: ResourceColor
  mode: SunMode
}
