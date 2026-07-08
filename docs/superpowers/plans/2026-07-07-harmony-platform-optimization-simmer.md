# HarmonyOS 平台优化 · Simmer Pilot 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 simmer 上完成"平台原生化 + 全 V2 状态迁移 + 5 项 UX 改造"，跑通"构建/安装/冒烟/截图/编译回归"闭环，沉淀可复制 playbook。

**Architecture:** 1A 大爆炸——pilot 内同步把共享包 `sunpebble_ui` 全部组件 + simmer `Index` 彻底迁 V2 状态管理（`@ComponentV2`/`@ObservedV2`/`@Trace`/`@Param`/`@Local`/`AppStorageV2`），同时替换手画进度环为原生 `Progress`、加完成触感+铃声、长按菜单、swipe-to-delete 自定义预设、自适应 Grid、修后台→前台生命周期 bug。

**Tech Stack:** ArkTS / ArkUI (HarmonyOS API 23), DevEco Studio toolchain (`hvigorw`, `ohpm`, `hdc`), 模拟器 phone (API 23)。

**Spec:** `docs/superpowers/specs/2026-07-07-harmony-platform-optimization-simmer-design.md`

## Global Constraints

- **无单测框架**：仓库无 ArkTS 测试基建。每个任务的"测试"= `hvigorw` 编译通过 + 模拟器内冒烟验证。不写 `*.test.ets`。
- **API 23**：模拟器为 phone API 23（`hdc shell "param get const.ohos.apiversion"` 返回 23）。所有 API 必须在此版本可用。
- **工具路径**（已验证存在）：
  - hvigorw: `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw`
  - hdc: `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`
  - 模拟器: `127.0.0.1:5555`（已运行）
- **持久化兼容**：`simmer.*.v1` 磁盘 key 和 JSON 格式必须保持兼容，老用户数据不丢。
- **V2 迁移边界**：V2 parent + V1 child 不支持。simmer Index 迁 V2 后，所有共享子组件必须同步 V2。
- **文案**：仅新增 `simmer_action_delete`（zh:"删除" / en:"Delete"），不动现有字符串。
- **不要提交**：除非用户明确要求（AGENTS.md 约定）。每个 task 的 "Commit" 步骤仅作 staging 准备，是否真正 `git commit` 由用户决定。
- ** ponytail 注释**：所有 `// ponytail: ...` 在收口后必须删除。
- **跨 App 一致**：`harmony-kit/apps/simmer` 是 source of truth；`simmer-harmony/apps/simmer` 需最终保持一致（实施末尾同步，见 Task 16）。

---

## 文件结构总览

### 新建
- `apps/simmer/entry/src/main/ets/runtime/TimerDoneFeedback.ets` —— 振动+铃声封装
- `apps/simmer/entry/src/main/resources/base/element/string.json` 内新增 key（修改既有文件）
- `apps/simmer/entry/src/main/resources/zh_CN/element/string.json` 内新增 key（修改既有文件）

### 修改 · 共享包 `packages/sunpebble_ui/src/main/ets/`
- `tokens/SunTheme.ets` —— 加 2 个 token
- `components/SunButton.ets` —— V2
- `components/SunCard.ets` —— V2
- `components/SunEmptyState.ets` —— V2
- `components/SunListRow.ets` —— V2
- `components/SunFitText.ets` —— V2
- `components/SunEllipsisText.ets` —— V2
- `shell/SunAppHeader.ets` —— V2
- `shell/SunToolShell.ets` —— V2
- `shell/SunTabShell.ets` —— V2
- `shell/SunSafeRoot.ets` —— V2 + AppStorageV2
- `runtime/SunWindowInsets.ets` —— AppStorageV2 写端

### 修改 · `apps/simmer/entry/src/main/`
- `ets/pages/Index.ets` —— V2 + UX + 平台原生（最大改动）
- `ets/entryability/EntryAbility.ets` —— 加 onForeground/onBackground 日志
- `module.json5` —— 加 VIBRATE 权限

### 仅编译回归（不改 UX）
- `apps/{homekeep,sleeptab,dayroll,steady}/entry/src/main/ets/pages/Index.ets` —— 按需修 V2 子组件调用点

---

## Task 0: 基线构建 + before 截图

**Files:** 无修改（仅观测）

**Interfaces:** 无

**目的**：确认当前未改动代码能干净构建，并拍下 before 截图作为对比基线。

- [ ] **Step 1: 确认模拟器在线**

Run:
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC list targets
```
Expected: 输出含 `127.0.0.1:5555`

- [ ] **Step 2: 清理后构建 simmer（验证基线可构建）**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR clean --no-daemon
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。记录 hap 路径 `entry/build/default/outputs/default/entry-default-signed.hap`。

若失败：**STOP**，先解决基线构建问题（环境/SDK），不进入后续 task。

- [ ] **Step 3: 卸载旧版 + 安装基线 hap**

Run:
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC uninstall com.sunpebble.simmer.harmony 2>/dev/null || true
$HDC install entry/build/default/outputs/default/entry-default-signed.hap
```
Expected: `install success`。若 bundleName 不确定，先 `$HDC shell "bm dump -n"` 查。

- [ ] **Step 4: 拍 8 张 before 截图**

在模拟器内手工触发以下场景，每个场景截图：
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
mkdir -p /Users/shikun/Developer/freelance/sunpebble/.asc-shots/simmer/before
for scene in empty single_running multi_running paused context_menu saved_presets_block swipe_delete done_state; do
  $HDC shell snapshot_display -f /data/local/tmp/before_${scene}.jpeg
  $HDC file recv /data/local/tmp/before_${scene}.jpeg \
    /Users/shikun/Developer/freelance/sunpebble/.asc-shots/simmer/before/${scene}.jpeg
done
```
注意：`context_menu`/`saved_presets_block`/`swipe_delete`/`done_state` 在 before 版本可能形态不同（before 用常驻按钮无菜单、保存预设混在 chip 行），按 before 实际形态拍即可，after 再对应拍。

Expected: `.asc-shots/simmer/before/` 下有 8 张 jpeg。

- [ ] **Step 5: 记录基线冒烟结果**

在模拟器内跑一遍 spec §7.3 冒烟第 1-5、12 步，确认 before 行为符合预期（除新 UX 外）。把任何异常记到 `docs/superpowers/notes/baseline-smoke.md`（新建）。

- [ ] **Step 6: 不提交**

基线不 commit（仅参考）。

---

## Task 1: 降风险 spike —— AppStorageV2 + V1/V2 @BuilderParam 互操作验证（GO/NO-GO 关卡）

**Files:**
- Create: `apps/simmer/entry/src/main/ets/pages/SpikePage.ets`（临时，验证后删）
- Modify: `apps/simmer/entry/src/main/resources/base/profile/main_pages.json`（临时加 SpikePage 路由）
- Modify: `apps/simmer/entry/src/main/ets/entryability/EntryAbility.ets:16`（临时把 loadContent 改为 SpikePage）

**Interfaces:** 无（spike，不入产物）

**目的**：在投入全量 V2 迁移前，实证两个关键未知点。**任一失败 → STOP 并升级到用户决策（降级 1B 或扩大 scope）**。

- [ ] **Step 1: 写 SpikePage 验证 AppStorageV2.connect 响应式 + V1 父→V2 子 @BuilderParam + @Param 对象传递**

Create `apps/simmer/entry/src/main/ets/pages/SpikePage.ets`:
```typescript
import { AppStorageV2, PersistenceV2 } from '@kit.ArkUI'

// 验证点 A: AppStorageV2.connect 返回值是否响应式
@ObservedV2
class SpikeData {
  @Trace count: number = 0
}

// 验证点 B: V2 子组件接收 @Param 对象 + @BuilderParam 尾随闭包
@ComponentV2
struct SpikeChild {
  @Param data: SpikeData = new SpikeData()
  @BuilderParam body: () => void = () => {}

  build() {
    Column({ space: 8 }) {
      Text(`child count: ${this.data.count}`).fontSize(20)
      this.body()
    }
  }
}

@Entry
@Component
struct SpikePage {
  // 验证 AppStorageV2: 经 @StorageLink 写, V2 connect 读
  @StorageLink('spike.count.v1') legacyCount: number = 0
  @Local v2Data: SpikeData = AppStorageV2.connect('spike.v2.key', SpikeData, () => new SpikeData())!

  aboutToAppear(): void {
    setInterval(() => {
      this.legacyCount += 1
      this.v2Data.count += 1
    }, 1000)
  }

  build() {
    Column({ space: 16 }) {
      Text(`legacy @StorageLink: ${this.legacyCount}`).fontSize(20)
      Text(`V2 connect count: ${this.v2Data.count}`).fontSize(20)
      SpikeChild({ data: this.v2Data }) {
        Text('--- trailing closure body ---').fontSize(14)
      }
    }
    .width('100%').height('100%').padding(40)
  }
}
```

- [ ] **Step 2: 临时挂载 SpikePage 为入口**

Modify `apps/simmer/entry/src/main/ets/entryability/EntryAbility.ets` 第 16 行：
```typescript
// 原: windowStage.loadContent('pages/Index', ...)
windowStage.loadContent('pages/SpikePage', (err) => {
```

Modify `apps/simmer/entry/src/main/resources/base/profile/main_pages.json`，加 `"pages/SpikePage"` 到 `src` 数组。

- [ ] **Step 3: 构建并安装**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
$HDC uninstall com.sunpebble.simmer.harmony
$HDC install entry/build/default/outputs/default/entry-default-signed.hap
```
Expected: `BUILD SUCCESSFUL` + `install success`。

**若编译失败**：记录错误信息。常见失败点：`AppStorageV2.connect` 签名不符、`@Param` 不能接 class、`@BuilderParam` 在 V2 内语法差异。尝试按错误信息调整 SpikePage 签名后重试。

- [ ] **Step 4: 在模拟器观察 30 秒**

启动 App（`$HDC shell aa start -a EntryAbility -b com.sunpebble.simmer.harmony`）。

Expected（GO 条件，全部满足）：
- 4 个数字每秒 +1 且 UI 跟着刷新（验证 AppStorageV2.connect 响应式 + @Trace 触发）
- `child count` 也跟着刷新（验证 V2 子组件 @Param 对象 + @Trace 属性能观测）
- `--- trailing closure body ---` 显示出来（验证 V1 父 @Entry → V2 子 @BuilderParam 尾随闭包可行）

**NO-GO 处理**：
- 若 AppStorageV2 不响应式 → 评估 `PersistenceV2.globalConnect` 替代；仍不行则升级用户降级 1B
- 若 V1→V2 @BuilderParam 尾随闭包不工作 → 升级用户：需把 4 个 App 的 Index 也迁 V2（scope 扩大）或降级 1B
- 记录最终有效的 API 签名到 `docs/superpowers/notes/v2-spike-findings.md`（新建），供后续 task 引用

- [ ] **Step 5: 还原入口 + 删除 spike**

确认 GO 后：
- 还原 `EntryAbility.ets` 第 16 行回 `'pages/Index'`
- 从 `main_pages.json` 删除 `"pages/SpikePage"`
- 删除 `apps/simmer/entry/src/main/ets/pages/SpikePage.ets`

Run:
```bash
rm /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer/entry/src/main/ets/pages/SpikePage.ets
```

- [ ] **Step 6: 验证还原后仍能构建**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 7: 不提交**

---

## Task 2: SunColor 补 token + 新增字符串资源

**Files:**
- Modify: `packages/sunpebble_ui/src/main/ets/tokens/SunTheme.ets:6-17`
- Modify: `apps/simmer/entry/src/main/resources/base/element/string.json`
- Modify: `apps/simmer/entry/src/main/resources/zh_CN/element/string.json`

**Interfaces:**
- Produces: `SunColor.hairline` (`'#D8CFBD'`) / `SunColor.panelTint` (`'#F7F0E5'`)（供 Task 13 替换 ponytail）；`simmer_action_delete`（en:"Delete" / zh:"删除"，供 Task 8/9）；`simmer_saved_presets_title`（en:"MY PRESETS" / zh:"我的预设"，供 Task 9）

> **为何字符串在此 task 而非 Task 13**：Task 8/9 的代码引用这些 `$r(...)` 资源，必须在引用前先建好，否则 Task 8/9 编译失败。字符串是纯增量、低风险，提前到此 task 与 token 一起加。

- [ ] **Step 1: 在 SunColor 类内加两个静态 token**

Modify `packages/sunpebble_ui/src/main/ets/tokens/SunTheme.ets`，在 `SunColor` 类内（`disabledBg` 之后）加：
```typescript
  static readonly hairline: string = '#D8CFBD'
  static readonly panelTint: string = '#F7F0E5'
```

完整修改后 `SunColor` 类应为：
```typescript
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
```

- [ ] **Step 2: 新增 simmer_action_delete 字符串**

Modify `apps/simmer/entry/src/main/resources/base/element/string.json`（en），加（在 `simmer_action_cancel` 附近插入，保持文件原有顺序）：
```json
    { "name": "simmer_action_delete", "value": "Delete" },
```

Modify `apps/simmer/entry/src/main/resources/zh_CN/element/string.json`（zh），加：
```json
    { "name": "simmer_action_delete", "value": "删除" },
```

- [ ] **Step 3: 新增 simmer_saved_presets_title 字符串**

同 base/element/string.json（en）加：
```json
    { "name": "simmer_saved_presets_title", "value": "MY PRESETS" },
```
（en 用全大写配合 letterSpacing，与现有 caption 风格一致）

同 zh_CN/element/string.json（zh）加：
```json
    { "name": "simmer_saved_presets_title", "value": "我的预设" },
```

- [ ] **Step 4: 验证共享包 + simmer 仍可构建**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: 不提交**

---

## Task 3: 共享包叶子组件 V2 迁移（SunButton / SunCard / SunEmptyState / SunListRow / SunFitText / SunEllipsisText）

**Files:**
- Modify: `packages/sunpebble_ui/src/main/ets/components/SunButton.ets`
- Modify: `packages/sunpebble_ui/src/main/ets/components/SunCard.ets`
- Modify: `packages/sunpebble_ui/src/main/ets/components/SunEmptyState.ets`
- Modify: `packages/sunpebble_ui/src/main/ets/components/SunListRow.ets`
- Modify: `packages/sunpebble_ui/src/main/ets/components/SunFitText.ets`
- Modify: `packages/sunpebble_ui/src/main/ets/components/SunEllipsisText.ets`

**Interfaces:**
- Produces: 所有叶子组件从 V1 `@Component` → V2 `@ComponentV2`，外部 API（导出名、props 名、类型）保持不变，下游调用方零改动

**迁移规则**（本 task 全部适用）：
- `@Component` → `@ComponentV2`
- `@Prop x` → `@Param x`
- `@State x` → `@Local x`
- 回调函数（`action`/`onAction`）→ `@Param`；若编译报错则降级为普通成员变量（spike 已验证哪种可行，参考 `docs/superpowers/notes/v2-spike-findings.md`）
- `@BuilderParam` 保留不动

- [ ] **Step 1: SunButton 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/components/SunButton.ets`，把声明段改为：
```typescript
@ComponentV2
export struct SunButton {
  @Param
  label: ResourceStr = ''
  @Param
  role: SunButtonRole = SunButtonRole.Primary
  @Param
  disabled: boolean = false
  @Param
  loading: boolean = false
  @Param action: () => void = () => {}
```
（其余 `buttonBackground()`/`buttonForeground()`/`build()` 不变）

- [ ] **Step 2: SunCard 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/components/SunCard.ets` 第 6-8 行：
```typescript
@ComponentV2
export struct SunCard {
  @BuilderParam content: () => void = emptyContent
```
（`build()` 不变）

- [ ] **Step 3: SunEmptyState 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/components/SunEmptyState.ets` 第 4-12 行：
```typescript
@ComponentV2
export struct SunEmptyState {
  @Param
  title: ResourceStr = ''
  @Param
  message: ResourceStr = ''
  @Param
  actionLabel: ResourceStr = ''
  @Param onAction: () => void = () => {}
```
（`build()` 不变）

- [ ] **Step 4: SunListRow 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/components/SunListRow.ets` 第 3-11 行：
```typescript
@ComponentV2
export struct SunListRow {
  @Param
  title: ResourceStr = ''
  @Param
  value: ResourceStr = ''
  @Param
  caption: ResourceStr = ''
  @Param action: () => void = () => {}
```
（`build()` 不变）

- [ ] **Step 5: SunFitText 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/components/SunFitText.ets` 第 3-27 行（全部 `@Prop` → `@Param`）：
```typescript
@ComponentV2
export struct SunFitText {
  @Param
  text: ResourceStr = ''
  @Param maxFontSize: number = 12
  @Param minFontSize: number = 8
  @Param fontColor: ResourceColor = SunColor.ink
  @Param fontWeight: FontWeight = FontWeight.Regular
  @Param maxLines: number = 1
  @Param textAlign: TextAlign = TextAlign.Start
  @Param letterSpacing: number = 0
```
（`build()` 不变）

- [ ] **Step 6: SunEllipsisText 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/components/SunEllipsisText.ets` 第 3-24 行（全部 `@Prop` → `@Param`）：
```typescript
@ComponentV2
export struct SunEllipsisText {
  @Param text: ResourceStr = ''
  @Param fontSize: number = SunType.body
  @Param fontColor: ResourceColor = SunColor.ink
  @Param fontWeight: FontWeight = FontWeight.Regular
  @Param maxLines: number = 1
  @Param textAlign: TextAlign = TextAlign.Start
  @Param letterSpacing: number = 0
```
（`build()` 不变）

- [ ] **Step 7: 编译验证共享包 + simmer**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。simmer Index 仍为 V1，V1 父含 V2 叶子子组件（无 @BuilderParam 尾随闭包，仅传 @Param），编译应通过（spike 已验证 V1→V2 @Param 可行）。

**若 SunButton 的 @Param action 报错**：降级为 `action: () => void = () => {}`（普通成员），重编译。

- [ ] **Step 8: 不提交**

---

## Task 4: 共享包 shell 组件 V2 迁移（SunAppHeader / SunToolShell / SunTabShell）

**Files:**
- Modify: `packages/sunpebble_ui/src/main/ets/shell/SunAppHeader.ets`
- Modify: `packages/sunpebble_ui/src/main/ets/shell/SunToolShell.ets`
- Modify: `packages/sunpebble_ui/src/main/ets/shell/SunTabShell.ets`

**Interfaces:**
- Produces: shell 组件 V2。`SunAppHeader.manifest`（对象类型）→ `@Param manifest`；`SunToolShell.body` / `SunTabShell.tabBody`（@BuilderParam）保留

- [ ] **Step 1: SunAppHeader 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/shell/SunAppHeader.ets` 第 3-16 行：
```typescript
@ComponentV2
export struct SunAppHeader {
  @Param manifest: SunAppManifest = {
    name: 'Sunpebble',
    tagline: '',
    primaryAction: '',
    accent: SunColor.sun,
    mode: SunMode.Light
  }
  @Param showPro: boolean = false
  @Param onPro: () => void = () => {}
```
（`foreground()`/`secondary()`/`build()` 不变）

- [ ] **Step 2: SunToolShell 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/shell/SunToolShell.ets` 第 8-24 行：
```typescript
@ComponentV2
export struct SunToolShell {
  @Param manifest: SunAppManifest = {
    name: 'Sunpebble',
    tagline: '',
    primaryAction: '',
    accent: SunColor.sun,
    mode: SunMode.Light
  }

  @BuilderParam body: () => void = emptyBody
  @Param onPrimaryAction: () => void = () => {}

  @Param showPro: boolean = false
  @Param onPro: () => void = () => {}
```
（`shellBackground()`/`foreground()`/`secondary()`/`build()` 不变）

- [ ] **Step 3: SunTabShell 迁 V2**

Modify `packages/sunpebble_ui/src/main/ets/shell/SunTabShell.ets` 第 12-28 行：
```typescript
@ComponentV2
export struct SunTabShell {
  @Param manifest: SunAppManifest = {
    name: 'Sunpebble',
    tagline: '',
    primaryAction: '',
    accent: SunColor.sun,
    mode: SunMode.Light
  }

  tabs: SunTabItem[] = []
  @Param activeTab: string = ''

  @Param onTabChange: (tabId: string) => void = () => {}

  @BuilderParam tabBody: (tabId: string) => void = emptyTabBody
```
注意：`tabs: SunTabItem[] = []` 保持普通成员（非响应式数组，父传入后不再变）。若编译报错（V2 要求 @Param），改为 `@Param tabs: SunTabItem[] = []`。

（`shellBackground()`/`build()`/`tabBarLabel()`/`selectedTabIndex()` 不变）

- [ ] **Step 4: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。此步开始考验 V1 父（simmer Index 仍 V1）→ V2 子（SunToolShell 含 @BuilderParam 尾随闭包）的互操作，spike 已验证可行。

- [ ] **Step 5: 不提交**

---

## Task 5: SunSafeRoot + SunWindowInsets V2（insets 管道）

**Files:**
- Modify: `packages/sunpebble_ui/src/main/ets/shell/SunSafeRoot.ets`
- Modify: `packages/sunpebble_ui/src/main/ets/runtime/SunWindowInsets.ets`

**Interfaces:**
- Produces: `SunSafeRoot` V2，insets 经 `AppStorageV2` 读写；`bindSunWindowInsets`/`sunInsetTopVp`/`sunInsetBottomVp` 签名不变（外部调用方零改动）
- Consumes: spike 验证过的 `AppStorageV2.connect` 签名（参考 `docs/superpowers/notes/v2-spike-findings.md`）

- [ ] **Step 1: SunWindowInsets 写端改 AppStorageV2**

Modify `packages/sunpebble_ui/src/main/ets/runtime/SunWindowInsets.ets`，整体替换为：
```typescript
import { window, AppStorageV2 } from '@kit.ArkUI'

const KEY_TOP = 'sun.inset.top.vp'
const KEY_BOTTOM = 'sun.inset.bottom.vp'

export function sunInsetTopVp(): number {
  return AppStorageV2.get<number>(KEY_TOP) ?? 0
}

export function sunInsetBottomVp(): number {
  return AppStorageV2.get<number>(KEY_BOTTOM) ?? 0
}

function applyInsets(mainWindow: window.Window): void {
  const systemArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
  const navArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
  const cutoutArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)

  const topPx = Math.max(systemArea.topRect.height, cutoutArea.topRect.height)
  const bottomPx = Math.max(navArea.bottomRect.height, systemArea.bottomRect.height)

  AppStorageV2.setOrCreate(KEY_TOP, px2vp(topPx))
  AppStorageV2.setOrCreate(KEY_BOTTOM, px2vp(bottomPx))
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
    AppStorageV2.setOrCreate(KEY_TOP, 0)
    AppStorageV2.setOrCreate(KEY_BOTTOM, 0)
  }
}
```

**若 `AppStorageV2.setOrCreate`/`AppStorageV2.get` 签名与 spike 验证不符**：按 spike findings 文档调整为实际可用的 API（可能是 `AppStorageV2.connect(KEY, number, 0)?.set(v)` 模式）。

- [ ] **Step 2: SunSafeRoot 读端改 V2 + AppStorageV2.connect**

Modify `packages/sunpebble_ui/src/main/ets/shell/SunSafeRoot.ets`，整体替换为：
```typescript
import { AppStorageV2 } from '@kit.ArkUI'
import { SunColor, SunMode } from '../tokens/SunTheme'

@Builder
function emptySafeBody() {}

@ComponentV2
export struct SunSafeRoot {
  @Param mode: SunMode = SunMode.Light

  @BuilderParam body: () => void = emptySafeBody

  @Local insetTop: number = AppStorageV2.connect('sun.inset.top.vp', number, 0)!
  @Local insetBottom: number = AppStorageV2.connect('sun.inset.bottom.vp', number, 0)!

  private rootBackground(): ResourceColor {
    return this.mode === SunMode.Dark ? SunColor.night : SunColor.cream
  }

  build() {
    Column() {
      this.body()
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.insetTop,
      bottom: this.insetBottom
    })
    .backgroundColor(this.rootBackground())
  }
}
```

**若 `AppStorageV2.connect` 返回值不能直接初始化 `@Local`**（spike findings 会指明）：改用 `@Monitor` + 手动 `AppStorageV2.get` 模式，参考 spike findings 文档的实际可行写法。

- [ ] **Step 3: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 4: 安装并验证安全区仍生效**

Run:
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HDC uninstall com.sunpebble.simmer.harmony
$HDC install entry/build/default/outputs/default/entry-default-signed.hap
$HDC shell aa start -a EntryAbility -b com.sunpebble.simmer.harmony
```
观察：simmer 内容应仍在状态栏下方、导航条上方（与 Task 0 before 截图对比，布局应一致）。

- [ ] **Step 5: 不提交**

---

## Task 6: 其他 4 App 编译回归 + 修调用点

**Files:**
- Modify（按需）: `apps/homekeep/entry/src/main/ets/pages/Index.ets`
- Modify（按需）: `apps/sleeptab/entry/src/main/ets/pages/Index.ets`
- Modify（按需）: `apps/dayroll/entry/src/main/ets/pages/Index.ets`
- Modify（按需）: `apps/steady/entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes: Task 3/4/5 迁移后的 V2 共享组件（API 不变，但 V1 父→V2 子语义可能需调整）

**目的**：共享包已全 V2，4 个 App 的 V1 Index 含 V2 子组件必须编译通过。本轮**不改它们的 UX**。

- [ ] **Step 1: 逐个编译 4 个 App**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit
for app in homekeep sleeptab dayroll steady; do
  echo "=== building $app ==="
  (cd apps/$app && $HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon) || echo "FAILED: $app"
done
```

- [ ] **Step 2: 逐个修复编译错误**

对每个失败的 App，按错误信息修 `Index.ets` 调用点。预期常见错误与修法：

| 错误 | 修法 |
|---|---|
| `@Param` 子组件要求父传值，但某 prop 未传 | 在调用处补上该 prop，或确认子组件 `@Param` 有默认值 |
| 对象类型（如 `manifest`）传 V2 子组件需 `UIUtils.enableV2Compatibility` | 包裹：`manifest: UIUtils.enableV2Compatibility(appProfile)`（import `UIUtils` from `@kit.ArkUI`） |
| `@BuilderParam` 尾随闭包 V1→V2 不工作 | 改用显式参数传递：`SunToolShell({ manifest: ..., body: () => { ... } })` 而非尾随闭包 |
| `tabs`/回调 @Param 报错 | 按 spike findings 调整 |

每个 App 修完后单独验证：
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/<app>
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: 每个都 `BUILD SUCCESSFUL`。

- [ ] **Step 3: 全部 4 个 App 编译通过后，汇总记录改动**

把每个 App 的改动行数和修法写到 `docs/superpowers/notes/v2-compile-regression.md`（新建），作为 playbook 资产。

- [ ] **Step 4: 不提交**

---

## Task 7: simmer Index 状态装饰器全 V2 迁移

**Files:**
- Modify: `apps/simmer/entry/src/main/ets/pages/Index.ets`（声明段，1-1063 行多处）

**Interfaces:**
- Produces: Index 从 `@Entry @Component` → `@Entry @ComponentV2`；`@State`→`@Local`、`@StorageLink`→`AppStorageV2.connect`、`@Prop`→`@Param`；`KitchenTimer` 迁 `@ObservedV2`+`@Trace`。`Burner` 留到 Task 8 一起改（含 Progress/菜单/动效）。

**注意**：本 task **只动状态装饰器和 KitchenTimer 类**，不动 UI 逻辑（burner 卡片、presetBar 等 UI 改造在 Task 8-13）。这样隔离便于定位编译错误。

- [ ] **Step 1: KitchenTimer 迁 @ObservedV2 + @Trace**

Modify `apps/simmer/entry/src/main/ets/pages/Index.ets` 第 41-64 行（`@Observed class KitchenTimer` 段）：
```typescript
@ObservedV2
class KitchenTimer {
  id: number
  label: string
  emoji: string
  seconds: number
  @Trace remaining: number
  @Trace running: boolean
  @Trace done: boolean
  @Trace endAt: number
  @Trace completedAt: number

  constructor(id: number, label: string, emoji: string, seconds: number, remaining: number, running: boolean, done: boolean, endAt: number, completedAt: number) {
    this.id = id
    this.label = label
    this.emoji = emoji
    this.seconds = seconds
    this.remaining = remaining
    this.running = running
    this.done = done
    this.endAt = endAt
    this.completedAt = completedAt
  }
}
```

- [ ] **Step 2: Index struct 头迁 @ComponentV2，@State→@Local**

Modify 第 234-270 行（`@Entry @Component struct Index` 的声明段）。`@Entry @Component` → `@Entry @ComponentV2`，状态装饰器映射：
```typescript
@Entry
@ComponentV2
struct Index {
  private presets: PresetTimer[] = [ /* 不变，原 237-250 行内容 */ ]
  private customEmojis: string[] = [ /* 不变 */ ]
  private customSecondOptions: number[] = [ /* 不变 */ ]
  private intervalId: number = -1

  @Local nextId: number = AppStorageV2.connect('simmer.nextId.v1', number, 1)!
  @Local timersJson: string = AppStorageV2.connect('simmer.timers.v1', String, '')!
  @Local customMinutes: number = AppStorageV2.connect('simmer.customMinutes.v1', number, 5)!
  @Local customSeconds: number = AppStorageV2.connect('simmer.customSeconds.v1', number, 0)!
  @Local customEmoji: string = AppStorageV2.connect('simmer.customEmoji.v1', String, '🍲')!
  @Local customLabelText: string = AppStorageV2.connect('simmer.customLabel.v1', String, '')!
  @Local savedPresetsJson: string = AppStorageV2.connect('simmer.savedPresets.v1', String, '')!
  @Local nextPresetId: number = AppStorageV2.connect('simmer.nextPresetId.v1', number, 1)!
  @Local proUnlocked: boolean = AppStorageV2.connect('simmer.proUnlocked.v1', Boolean, true)!
  @Local customOpen: boolean = false
  @Local timers: KitchenTimer[] = []
  @Local savedPresets: SavedPresetTimer[] = []
  @Local nowMs: number = Date.now()
  @Local confirmingPresetId: number = -1
  @Local customSaveAsPreset: boolean = false
  @Local paywallOpen: boolean = false
  @Local containerWidth: number = 0
```

**关键**：`AppStorageV2.connect` 签名以 spike findings 为准。`String`/`Boolean` 用包装类型（V2 反射需要）。

- [ ] **Step 3: 移除 PersistentStorage.persistProp 调用**

Modify 第 66-74 行（`PersistentStorage.persistProp(...)` × 9）。这些 key 改由 `AppStorageV2.connect` 配合 `PersistenceV2` 持久化。

在文件顶部 import 加 `PersistenceV2`：
```typescript
import { AppStorageV2, PersistenceV2 } from '@kit.ArkUI'
```

把第 66-74 行的 9 个 `PersistentStorage.persistProp(...)` 替换为：
```typescript
PersistenceV2.persistV2('simmer.nextId.v1', 1)
PersistenceV2.persistV2('simmer.timers.v1', '')
PersistenceV2.persistV2('simmer.customMinutes.v1', 5)
PersistenceV2.persistV2('simmer.customSeconds.v1', 0)
PersistenceV2.persistV2('simmer.customEmoji.v1', '🍲')
PersistenceV2.persistV2('simmer.customLabel.v1', '')
PersistenceV2.persistV2('simmer.savedPresets.v1', '')
PersistenceV2.persistV2('simmer.nextPresetId.v1', 1)
PersistenceV2.persistV2('simmer.proUnlocked.v1', true)
```

**若 `PersistenceV2.persistV2` 签名不符**（spike findings 会指明）：按实际 API 调整。原则：磁盘 key 必须保持 `simmer.*.v1` 原样以兼容老数据。

- [ ] **Step 4: Burner struct 头暂迁 V2（仅装饰器，UI 留 Task 8）**

Modify 第 108-116 行（`@Component struct Burner` 声明）：
```typescript
@ComponentV2
struct Burner {
  @Param timer: KitchenTimer
  @Local nowMs: number = Date.now()
  @Param onTap: (id: number) => void = (_id: number) => {}
  @Param onAddMinute: (id: number) => void = (_id: number) => {}
  @Param onRestart: (id: number) => void = (_id: number) => {}
  @Param onCancel: (id: number) => void = (_id: number) => {}
```
（原 `@ObjectLink`/`@Prop` 移除；`build()` 暂不动，Task 8 改）

- [ ] **Step 5: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

**若 `this.timers.find(...)` 等数组方法在 `@Trace` 数组上报错**：`timers` 本身是 `@Local`，元素是 `@ObservedV2`，应可行。若 ArkUI 对 `@ObservedV2` 实例数组的 `.find().remaining = x` 赋值不触发刷新，改用 `[...this.timers]` 重新赋整个数组触发 `@Local` 刷新（spec §4.5 2e 风险点的现场处理）。

- [ ] **Step 6: 安装并冒烟（仅验状态迁移不破坏既有行为）**

Run:
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC uninstall com.sunpebble.simmer.harmony
$HDC install entry/build/default/outputs/default/entry-default-signed.hap
$HDC shell aa start -a EntryAbility -b com.sunpebble.simmer.harmony
```
跑 spec §7.3 冒烟第 1-5、12 步，确认行为与 before 一致（UI 还没改，应该看起来一样）。

- [ ] **Step 7: 不提交**

---

## Task 8: Burner 卡片 —— 原生 Progress 环 + 长按菜单 + 增删动效

**Files:**
- Modify: `apps/simmer/entry/src/main/ets/pages/Index.ets`（`Burner` struct 的 `build()`，约第 149-217 行；及 `Index.build()` 内 burner 列表渲染段）

**Interfaces:**
- Consumes: Task 7 的 V2 `Burner` 声明、`KitchenTimer`（`@Trace remaining/done/running`）
- Produces: 新 burner 卡片：原生 `Progress(Ring)` + `bindContextMenu` + `.transition`

- [ ] **Step 1: 替换 Burner.build() 的 Stack 内进度环为原生 Progress**

Modify `apps/simmer/entry/src/main/ets/pages/Index.ets` 内 `Burner` struct 的 `build()`。把第 149-196 行的 `Stack() { Circle()... Circle()... Column() {...} }` 段替换为：
```typescript
  build() {
    Column({ space: SunSpacing.sm }) {
      Stack() {
        Progress({ value: this.progress(), total: 100, type: ProgressType.Ring })
          .style({ strokeWidth: 8 })
          .color(this.timer.done ? SunColor.sun : SunColor.ink)
          .trackColor(SunColor.border)
          .width(142)
          .height(142)

        Column({ space: SunSpacing.xs }) {
          Text(this.timer.emoji)
            .fontSize(36)

          if (this.timer.done) {
            Text($r('app.string.simmer_burner_done'))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.ink)

            Text($r('app.string.simmer_burner_over_format', this.timerText(this.overdue())))
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor(SunColor.pebble)
          } else {
            Text(this.timerText(this.timer.remaining))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(SunColor.ink)

            if (!this.timer.running) {
              Text($r('app.string.simmer_burner_paused'))
                .fontSize(9)
                .fontWeight(FontWeight.Medium)
                .fontColor(SunColor.pebble)
            }
          }
        }
      }
      .width(150)
      .height(150)
      .onClick(() => this.onTap(this.timer.id))
      .bindContextMenu(this.burnerMenu, ResponseType.LongPress)

      Row() {
        Text(displayLabel(this.getUIContext().getHostContext(), this.timer.label).toUpperCase())
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(SunColor.pebble)
          .letterSpacing(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text('⋯')
          .fontSize(14)
          .opacity(0.4)
          .fontColor(SunColor.pebble)
      }
      .width('100%')
    }
    .width(190)
    .height(250)
    .justifyContent(FlexAlign.Center)
    .transition({ type: TransitionType.All, opacity: 0, scale: 0.9 })
  }

  @Builder
  private burnerMenu() {
    Menu() {
      MenuItem({ value: $r('app.string.simmer_action_add_minute') })
        .onClick(() => this.onAddMinute(this.timer.id))
      MenuItem({ value: $r('app.string.simmer_action_restart') })
        .onClick(() => this.onRestart(this.timer.id))
      MenuItem({ value: $r('app.string.simmer_action_delete') })
        .onClick(() => this.onCancel(this.timer.id))
    }
  }
```

**注意**：
- 删除了原底部常驻 3 按钮 `Row { actionButton×3 }` 段
- `ringDash()` 方法（第 144-147 行）已无用，可删
- `actionButton` Builder（第 219-231 行）已无用，可删
- `onCancel` 回调在 Index 内仍绑 `deleteTimer`（语义：删除），菜单文案改为"删除"更准确
- **`.trackColor()` API 不确定**：ArkUI Progress 的轨道背景色方法名可能是 `.trackColor()` 或需经 `RingStyleOptions`（`ProgressStyleMap`）。Task 8 Step 4 编译会立即暴露。若 `.trackColor()` 不存在，回退：删掉该行（用默认轨道色），或查 API 23 文档用正确的 RingStyleOptions 写法

- [ ] **Step 2: 删除 Burner 内已无用的 ringDash / actionButton**

Modify `apps/simmer/entry/src/main/ets/pages/Index.ets`，删除 `Burner` struct 内的：
- `private ringDash(): number[] { ... }`（原第 144-147 行）
- `@Builder private actionButton(...)` 整段（原第 219-231 行）

- [ ] **Step 3: burner 列表渲染加 animateTo 包裹（增删动效）**

Modify `Index.build()` 内的 `burnerList()` Builder（原第 731-751 行）。Task 11 会把这里换成 Grid，本步先保留 Flex 但加 transition 触发。先不动此处，Task 11 统一处理 Grid + 动效。

（本步仅验证 Burner 卡片改动，列表容器在 Task 11）

- [ ] **Step 4: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: 安装并验证菜单 + 进度环**

Run:
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC uninstall com.sunpebble.simmer.harmony
$HDC install entry/build/default/outputs/default/entry-default-signed.hap
$HDC shell aa start -a EntryAbility -b com.sunpebble.simmer.harmony
```
冒烟 spec §7.3 第 2、6、7 步：
- 点 Tea 预设 → burner 出现，进度环为原生 Ring（非手画）
- 长按 burner → 弹出菜单（加一分钟/重启/删除）
- 选"加一分钟" → burner 时长 +60

- [ ] **Step 6: 不提交**

---

## Task 9: 保存的预设独立垂直区块 + swipe-to-delete

**Files:**
- Modify: `apps/simmer/entry/src/main/ets/pages/Index.ets`（`presetBar()` Builder + `Index.build()` 布局段）

**Interfaces:**
- Consumes: `savedPresets: SavedPresetTimer[]`（`@Local`，Task 7）
- Produces: 新 `savedPresetsBlock()` Builder；`presetBar()` 去除保存预设部分

- [ ] **Step 1: 新增 savedPresetsBlock Builder**

在 `Index` struct 内（`presetBar()` 之前）加：
```typescript
  @Builder
  private deleteSwipeAction(id: number) {
    Button($r('app.string.simmer_action_delete'))
      .height('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(SunColor.danger)
      .fontColor(SunColor.white)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .onClick(() => this.removeSavedPreset(id))
  }

  @Builder
  private savedPresetsBlock() {
    if (this.savedPresets.length > 0) {
      Column({ space: SunSpacing.sm }) {
        Text($r('app.string.simmer_saved_presets_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
          .fontColor(SunColor.pebble)

        List({ space: SunSpacing.sm }) {
          ForEach(this.savedPresets, (preset: SavedPresetTimer) => {
            ListItem() {
              Row({ space: 8 }) {
                Text(preset.emoji).fontSize(20)
                Text(this.labelText(preset.label))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(SunColor.ink)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.timerText(preset.seconds))
                  .fontSize(13)
                  .fontColor(SunColor.pebble)
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .borderRadius(SunRadius.md)
              .backgroundColor(SunColor.white)
              .border({ width: 1, color: SunColor.border })
              .onClick(() => this.startSavedPreset(preset))
            }
            .swipeAction({
              end: { builder: () => this.deleteSwipeAction(preset.id) }
            })
          }, (preset: SavedPresetTimer) => preset.id.toString())
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: SunSpacing.xl, right: SunSpacing.xl, bottom: SunSpacing.sm })
    }
  }
```

- [ ] **Step 2: presetBar 去除保存预设部分**

Modify `presetBar()` Builder（原第 873-969 行），删除其中 `ForEach(this.savedPresets, ...)` 整段（原第 888-943 行，含 `confirmingPresetId` 二次确认逻辑）。保留"自定义"按钮 + 内置预设 `ForEach(this.presets, ...)`。

`confirmingPresetId` 状态（Task 7 声明里保留但不再用）可删，或留作无害。

- [ ] **Step 3: Index.build() 插入 savedPresetsBlock**

Modify `Index.build()` 内的 `Column()` 布局（原第 1045-1055 行），在 `burnerList()`/`emptyState()` 之后、`customPanel()` 之前插入：
```typescript
        Column() {
          if (this.timers.length === 0) {
            this.emptyState()
          } else {
            this.burnerList()
          }

          this.savedPresetsBlock()

          this.customPanel()
          this.presetBar()
          this.paywallPanel()
        }
```

- [ ] **Step 4: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: 安装并验证 swipe 删除**

冒烟 spec §7.3 第 9、10、11 步：
- 自定义并勾"保存为预设"启动 → 新预设出现在 burner 下方"我的预设"区块
- 右滑该行 → 露红色"删除"按钮
- 点删除 → 行消失

- [ ] **Step 6: 不提交**

---

## Task 10: 完成触感 + 系统铃声（TimerDoneFeedback）

**Files:**
- Create: `apps/simmer/entry/src/main/ets/runtime/TimerDoneFeedback.ets`
- Modify: `apps/simmer/entry/src/main/module.json5`
- Modify: `apps/simmer/entry/src/main/ets/pages/Index.ets`（`tick()` 内调用）

**Interfaces:**
- Produces: `TimerDoneFeedback.fire()` 静态方法，静默失败安全

- [ ] **Step 1: 新建 TimerDoneFeedback.ets**

Create `apps/simmer/entry/src/main/ets/runtime/TimerDoneFeedback.ets`:
```typescript
import { vibrator } from '@kit.SensorServiceKit'

export class TimerDoneFeedback {
  static async fire(): Promise<void> {
    try {
      await vibrator.startVibration({ type: 'preset', effectId: 'haptic.effect.scene3' }, { usage: 'notification' })
    } catch (_error) {
      // 模拟器无振动硬件，静默失败；可见状态仍是 source of truth
    }
    // 系统铃声：API 23 实现阶段确认 systemSoundManager vs ringtoneManager 哪个可用
    // 先用 vibrator，铃声若 API 不可用则跳过（模拟器本就无铃声硬件）
  }
}
```

**说明**：`effectId` 用通用 preset（`haptic.effect.scene3` 是已知存在的通知类效果）。精确的 timer 效果 ID 在 API 23 文档查；若不存在用此通用效果兜底。

- [ ] **Step 2: module.json5 加 VIBRATE 权限**

Modify `apps/simmer/entry/src/main/module.json5`，在 `requestPermissions` 数组加：
```json5
    "requestPermissions": [
      {
        "name": "ohos.permission.PUBLISH_AGENT_REMINDER"
      },
      {
        "name": "ohos.permission.VIBRATE"
      }
    ],
```

- [ ] **Step 3: tick() 内到点时调用 TimerDoneFeedback.fire()**

Modify `apps/simmer/entry/src/main/ets/pages/Index.ets` 的 `tick()` 方法（原第 537-568 行）。在 `this.showDone(timer.label)` 之后（原第 557 行后）加：
```typescript
      TimerDoneFeedback.fire()
```

文件顶部加 import：
```typescript
import { TimerDoneFeedback } from '../runtime/TimerDoneFeedback'
```

- [ ] **Step 4: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: 安装并验证到点行为**

冒烟 spec §7.3 第 12 步：启动 15s 计时器，等其到点。
模拟器无振动/铃声硬件，预期降级为：toast + burner 变 done 黄环 + overdue 计数（与 before 一致），但代码路径已含 fire() 调用（真机会有振动）。

- [ ] **Step 6: 不提交**

---

## Task 11: 自适应 Grid 布局 + 增删动效

**Files:**
- Modify: `apps/simmer/entry/src/main/ets/pages/Index.ets`（`burnerList()` Builder）

**Interfaces:**
- Consumes: `containerWidth: number`（`@Local`，Task 7）、`timers: KitchenTimer[]`

- [ ] **Step 1: 替换 burnerList 为 Grid + onAreaChange**

Modify `Index` 内 `burnerList()` Builder（原第 731-751 行），整体替换为：
```typescript
  private gridColumns(): string {
    if (this.containerWidth >= 840) {
      return '1fr 1fr 1fr'
    }
    if (this.containerWidth >= 600) {
      return '1fr 1fr'
    }
    return '1fr'
  }

  @Builder
  private burnerList() {
    Scroll() {
      Grid() {
        ForEach(this.timers, (timer: KitchenTimer) => {
          GridItem() {
            Burner({
              timer: timer,
              nowMs: this.nowMs,
              onTap: (id: number) => this.handleTimerTap(id),
              onAddMinute: (id: number) => this.addMinute(id),
              onRestart: (id: number) => this.restartTimer(id),
              onCancel: (id: number) => this.deleteTimer(id)
            })
          }
        }, (timer: KitchenTimer) => timer.id.toString())
      }
      .columnsTemplate(this.gridColumns())
      .columnsGap(SunSpacing.lg)
      .rowsGap(SunSpacing.lg)
      .padding(SunSpacing.xl)
      .width('100%')
      .onAreaChange((_old: Area, newArea: Area) => {
        this.containerWidth = newArea.width as number
      })
    }
    .width('100%')
    .layoutWeight(1)
  }
```

**注意**：`Burner` 的 `nowMs` 在 Task 8 迁 V2 后是 `@Local`，但通过构造参数传入仍可行（V2 @Param 接收）。若 `@Param` 不接受 `nowMs` 这种每秒变化的值导致不刷新，改为 `@Watch` 或在 Burner 内自维护 `setInterval`。先用当前写法，编译+运行验证。

- [ ] **Step 2: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 3: 安装并验证网格 + 动效**

冒烟 spec §7.3 第 2、3、15 步：
- 加预设 → burner 出现（验证 `.transition` 进场动效）
- 加多个 → 手机宽度下 1 列
- 改模拟器窗口尺寸到平板宽度 → 自动变多列（模拟器窗口可拖拽调整）

- [ ] **Step 4: 不提交**

---

## Task 12: onPageShow 生命周期修复（后台→前台重 sync）

**Files:**
- Modify: `apps/simmer/entry/src/main/ets/pages/Index.ets`（加 `onPageShow`）
- Modify: `apps/simmer/entry/src/main/ets/entryability/EntryAbility.ets`（加 onForeground/onBackground 日志）

**Interfaces:** 无

- [ ] **Step 1: Index 加 onPageShow**

在 `Index` struct 内（`aboutToAppear` 附近，原第 272 行后）加：
```typescript
  onPageShow(): void {
    this.tick()
  }
```

- [ ] **Step 2: EntryAbility 加 onForeground/onBackground 观测**

Modify `apps/simmer/entry/src/main/ets/entryability/EntryAbility.ets`，在 `onWindowStageCreate` 之后加：
```typescript
  onForeground(): void {
    hilog.info(DOMAIN, 'Simmer', 'Ability onForeground')
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'Simmer', 'Ability onBackground')
  }
```

- [ ] **Step 3: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 4: 安装并验证后台→前台重 sync**

冒烟 spec §7.3 第 14 步：
- 启动 30s 计时器
- 按 Home 切后台
- 等 35s
- 切回前台
- 预期：**立即**显示 done（不再等 1 秒）

- [ ] **Step 5: 不提交**

---

## Task 13: simmer ponytail 硬编码收口

**Files:**
- Modify: `apps/simmer/entry/src/main/ets/pages/Index.ets`（剩余 ponytail 硬编码）

**Interfaces:** 无

> 字符串资源（`simmer_action_delete` / `simmer_saved_presets_title`）已在 Task 2 添加，本 task 只处理 ponytail 颜色硬编码。

- [ ] **Step 1: 定位所有 ponytail 硬编码**

Run:
```bash
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit
rg -n "ponytail|#D8CFBD|#F7F0E5" apps/simmer/entry/src/main/ets
```
预期剩余 `#D8CFBD` / `#F7F0E5` 处（部分已在 Task 8 删 burner 按钮时一并去掉，按实际剩余处理）。

- [ ] **Step 2: 替换硬编码为 SunColor token**

对每处：
- `'#D8CFBD'` → `SunColor.hairline`
- `'#F7F0E5'` → `SunColor.panelTint`

删除对应 `// ponytail: ...` 注释行。

`Index.ets` 顶部 import 已含 `SunColor`（原第 3 行），无需补。

- [ ] **Step 3: 验证无 ponytail 残留**

Run:
```bash
rg -c "ponytail" apps/simmer/entry/src/main/ets
```
Expected: 输出为空（返回码 1，无匹配）。

- [ ] **Step 4: 编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: 不提交**

---

## Task 14: EntryAbility VIBRATE 权限声明核对 + 最终编译

（Task 10 已加权限，本 task 是核对 + 整体冒烟前最终编译）

**Files:** 无新增修改

- [ ] **Step 1: 核对 module.json5**

Run:
```bash
cat /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer/entry/src/main/module.json5 | rg -A6 requestPermissions
```
Expected: 含 `PUBLISH_AGENT_REMINDER` 和 `VIBRATE`。

- [ ] **Step 2: clean 后最终编译**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HVIGOR clean --no-daemon
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 3: 不提交**

---

## Task 15: 全量冒烟（16 项）+ after 截图 + 通过标准核对

**Files:** 无修改

- [ ] **Step 1: 重新安装最终版本**

Run:
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit/apps/simmer
$HDC uninstall com.sunpebble.simmer.harmony
$HDC install entry/build/default/outputs/default/entry-default-signed.hap
$HDC shell aa start -a EntryAbility -b com.sunpebble.simmer.harmony
```

- [ ] **Step 2: 跑 spec §7.3 全 16 步冒烟**

逐项执行 spec `docs/superpowers/specs/2026-07-07-harmony-platform-optimization-simmer-design.md` 的 §7.3 表格 16 行，记录每项实际结果。

任一项不符预期：回到对应 Task 修复，不进入 Step 3。

- [ ] **Step 3: 拍 8 张 after 截图**

Run:
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
mkdir -p /Users/shikun/Developer/freelance/sunpebble/.asc-shots/simmer/after
for scene in empty single_running multi_running paused context_menu saved_presets_block swipe_delete done_state; do
  $HDC shell snapshot_display -f /data/local/tmp/after_${scene}.jpeg
  $HDC file recv /data/local/tmp/after_${scene}.jpeg \
    /Users/shikun/Developer/freelance/sunpebble/.asc-shots/simmer/after/${scene}.jpeg
done
```

- [ ] **Step 4: 核对通过标准（spec §7.5）**

逐项核对：
- [ ] 4 个其他 App 编译通过（Task 6 已验，复核）
- [ ] 16 项冒烟全过
- [ ] 8 张 after 截图视觉合理
- [ ] `rg -c "ponytail" apps/simmer` 返回 0（Task 13 已验）
- [ ] `rg "@State|@StorageLink|@StorageProp|@Prop\b|@ObjectLink|@Observed\b" apps/simmer/entry/src/main/ets` 返回 0（V1 装饰器清零）

Run:
```bash
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit
rg "@State|@StorageLink|@StorageProp|@Prop\b|@ObjectLink|@Observed\b" apps/simmer/entry/src/main/ets
echo "exit: $?"
```
Expected: 无匹配（exit 1）。

- [ ] **Step 5: hilog 核对无新 error**

Run:
```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC shell hilog | rg -i "error|fatal" | rg "Simmer" | head -20
```
Expected: 无新增 error（对比 before 基线）。

- [ ] **Step 6: 不提交**

---

## Task 16: 同步 simmer-harmony 镜像 repo

**Files:**
- `simmer-harmony/apps/simmer/**`（从 harmony-kit 镜像）

**Interfaces:** 无

**目的**：`harmony-kit/apps/simmer` 是 source of truth，`simmer-harmony/apps/simmer` 需保持一致（spec §7.5 通过标准）。

- [ ] **Step 1: diff 确认差异**

Run:
```bash
cd /Users/shikun/Developer/freelance/sunpebble
diff -r harmony-kit/apps/simmer/entry/src/main simmer-harmony/apps/simmer/entry/src/main | head -50
```

- [ ] **Step 2: 镜像同步**

Run:
```bash
cd /Users/shikun/Developer/freelance/sunpebble
rsync -av --delete \
  --exclude '.hvigor' --exclude '.build' --exclude 'build' --exclude 'oh_modules' --exclude '*.hap' \
  harmony-kit/apps/simmer/ simmer-harmony/apps/simmer/
```

- [ ] **Step 3: diff 确认一致**

Run:
```bash
diff -r harmony-kit/apps/simmer/entry/src/main simmer-harmony/apps/simmer/entry/src/main
```
Expected: 无输出（完全一致）。

- [ ] **Step 4: 镜像 repo 独立编译验证**

Run:
```bash
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/simmer-harmony/apps/simmer
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: 不提交（除非用户要求）**

---

## Playbook 沉淀（实施完成后）

pilot 跑通后，把以下写入 `docs/superpowers/specs/2026-07-07-harmony-platform-optimization-playbook.md`：
- V2 迁移检查清单（V1 装饰器→V2 映射表 + spike findings 实测 API 签名）
- 平台优化检查清单（Progress/swipe/Grid/触感/铃声/onPageShow/ponytail token）
- 验证脚本模板（构建/安装/冒烟/截图/编译回归）
- 4 App 编译回归实际改动汇总（Task 6 的 notes）
- 后续 4 App 复制顺序建议：homekeep → sleeptab → dayroll → steady
