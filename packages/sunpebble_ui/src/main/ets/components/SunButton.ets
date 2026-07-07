import { SunColor, SunRadius, SunSpacing, SunType } from '../tokens/SunTheme'

export enum SunButtonRole {
  Primary = 'primary',
  Secondary = 'secondary',
  Danger = 'danger'
}

@Component
export struct SunButton {
  @Prop
  label: ResourceStr = ''
  @Prop
  role: SunButtonRole = SunButtonRole.Primary
  @Prop
  disabled: boolean = false
  @Prop
  loading: boolean = false
  action: () => void = () => {}

  private buttonBackground(): ResourceColor {
    if (this.disabled || this.loading) {
      return SunColor.disabledBg
    }
    if (this.role === SunButtonRole.Secondary) {
      return SunColor.white
    }
    if (this.role === SunButtonRole.Danger) {
      return SunColor.danger
    }
    return SunColor.sun
  }

  private buttonForeground(): ResourceColor {
    if (this.disabled || this.loading) {
      return SunColor.pebble
    }
    if (this.role === SunButtonRole.Danger) {
      return SunColor.white
    }
    return SunColor.ink
  }

  build() {
    Button(this.loading ? $r('app.string.sun_button_working') : this.label)
      .height(40)
      .padding({ left: SunSpacing.lg, right: SunSpacing.lg })
      .borderRadius(SunRadius.pill)
      .backgroundColor(this.buttonBackground())
      .fontColor(this.buttonForeground())
      .fontSize(SunType.body)
      .fontWeight(FontWeight.Medium)
      .border({
        width: this.role === SunButtonRole.Secondary ? 1 : 0,
        color: SunColor.border
      })
      .enabled(!this.disabled && !this.loading)
      .stateEffect(!this.disabled && !this.loading)
      .onClick(() => {
        if (!this.disabled && !this.loading) {
          this.action()
        }
      })
  }
}
