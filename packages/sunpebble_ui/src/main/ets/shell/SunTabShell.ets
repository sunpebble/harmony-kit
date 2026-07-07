import { SunAppManifest, SunColor, SunMode, SunSpacing } from '../tokens/SunTheme'
import { SunAppHeader } from './SunAppHeader'

@Builder
function emptyTabBody() {}

export interface SunTabItem {
  id: string
  label: ResourceStr
}

@Component
export struct SunTabShell {
  manifest: SunAppManifest = {
    name: 'Sunpebble',
    tagline: '',
    primaryAction: '',
    accent: SunColor.sun,
    mode: SunMode.Light
  }

  tabs: SunTabItem[] = []
  @Prop
  activeTab: string = ''

  onTabChange: (tabId: string) => void = () => {}

  @BuilderParam tabBody: (tabId: string) => void = emptyTabBody

  private shellBackground(): ResourceColor {
    return this.manifest.mode === SunMode.Dark ? SunColor.night : SunColor.cream
  }

  build() {
    Column() {
      SunAppHeader({ manifest: this.manifest })

      Tabs({ barPosition: BarPosition.End, index: this.selectedTabIndex() }) {
        ForEach(this.tabs, (tab: SunTabItem) => {
          TabContent() {
            Column() {
              Column() {
                this.tabBody(tab.id)
              }
              .width('100%')
              .layoutWeight(1)
            }
            .width('100%')
            .height('100%')
          }
          .tabBar(this.tabBarLabel(tab))
        }, (tab: SunTabItem) => tab.id)
      }
      .width('100%')
      .layoutWeight(1)
      .barMode(BarMode.Fixed)
      .barBackgroundColor(this.shellBackground())
      .barHeight(56)
      .onChange((index: number) => {
        if (index >= 0 && index < this.tabs.length) {
          this.onTabChange(this.tabs[index].id)
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.shellBackground())
  }

  @Builder
  private tabBarLabel(tab: SunTabItem) {
    Text(tab.label)
      .fontSize(11)
      .fontWeight(this.activeTab === tab.id ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.activeTab === tab.id
        ? (this.manifest.mode === SunMode.Dark ? SunColor.cream : SunColor.ink)
        : (this.manifest.mode === SunMode.Dark ? SunColor.darkSecondary : SunColor.pebble))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private selectedTabIndex(): number {
    const idx = this.tabs.findIndex((tab: SunTabItem) => tab.id === this.activeTab)
    return idx >= 0 ? idx : 0
  }
}