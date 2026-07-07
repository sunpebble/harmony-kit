# HarmonyOS 平台特定化优化 · Simmer Pilot 设计

- **Status**: Draft, awaiting user review
- **Date**: 2026-07-07
- **Scope**: `harmony-kit/apps/simmer` (pilot 本体) + `packages/sunpebble_ui` (全 V2 迁移，全 App 受益)
- **策略**: 1A 大爆炸——pilot 内同步完成共享包 + Index 的彻底 V2 迁移
- **Out of scope**: sleeptab / steady / dayroll / homekeep 的 UX 改造（但共享包 V2 迁移会波及它们，本轮做编译回归而非 UX 改造）
- **Source of truth**: 工作目录 `harmony-kit/apps/simmer`，与 `simmer-harmony/apps/simmer` 已确认完全一致

## 1. 背景与动机

Sunpebble 的 5 个 HarmonyOS 应用都从 `harmony-kit` 同步派生。当前 simmer 的实现工作正常，但有几个可以更"为 HarmonyOS 而生"的方面：

- 进度环用手画 `Circle + strokeDashArray + rotate(-90)` 而非原生 `Progress` 组件
- App 后台时 `setInterval` 被系统暂停，回前台后 running 计时器不会立即识别已到点（真实 bug）
- 10 处 `// ponytail: no SunColor token` 硬编码颜色（`#D8CFBD`、`#F7F0E5`），设计系统未收口
- 前台到点几乎静默（仅 toast），没有触感/系统音反馈
- 每张 burner 卡常驻 3 按钮，视觉噪音偏大
- 保存的预设和内置预设混在一个水平 chip 行里，删除走 `×` 二次确认
- burner 增删是硬切，无动效
- 手机/平板都用同一个 `Flex wrap` 居中堆叠，平板空间未利用
- `@Observed/@ObjectLink` 是 V1 状态管理，每秒 tick 会连带刷新 burner 内不该变的字段

本 pilot 在 simmer 上跑通完整的"优化 → 模拟器构建/安装 → 冒烟测试 → 截图前后对比 → 验证"闭环，沉淀为可复制到其余 4 个 App 的 playbook。

## 2. 目标与非目标

**目标**

1. 用原生 ArkUI 能力替换 workaround，代码更地道、性能更好
2. 修后台 → 前台计时器不响的真实生命周期 bug
3. 清掉 simmer 全部 10 处 ponytail 硬编码（同时给 `sunpebble_ui` 补 token）
4. 加完成时触感 + 系统计时器铃声（前台层）
5. 长按 burner 唤出操作菜单，减少常驻按钮噪音
6. 保存的预设提升为独立垂直区块，用鸿蒙原生 swipe-to-delete
7. burner 增删动效
8. 自适应网格（手机 1 列 / 折叠 2 列 / 平板 3 列）
9. **全 V2 状态迁移**：`sunpebble_ui` 全部 10 个组件 + `Index` + `KitchenTimer`/`Burner` 彻底迁 `@ComponentV2`/`@ObservedV2`/`@Trace`/`@Param`/`@Local`，`@StorageLink` → `AppStorageV2`（精确属性级刷新 + 现代 API）
10. 共享包 V2 迁移波及的其他 4 个 App 编译回归通过
11. 沉淀验证 playbook（构建/安装/冒烟/截图/编译回归），可复制

**非目标**

- 不拆分 `Index.ets`（避免与改动叠加，留作后续重构）
- 不改持久化数据磁盘 schema（`simmer.*.v1` keys 和 JSON 格式保持兼容）
- 不改已有字符串文案（仅新增 `simmer_action_delete`）
- 不引入自动化测试框架（仓库无测试基建；本 pilot 用手工冒烟 + 截图 + 编译回归）
- 不做其他 4 个 App 的 UX/平台原生改造（仅编译回归；它们的 UX 改造是后续独立 spec）

## 3. 架构与文件布局（1A 大爆炸：含共享包全 V2 迁移）

用户选定 1A：pilot 内同步把 `sunpebble_ui` 全部 10 个组件 + `Index` 彻底迁 V2。原因：V2 parent + V1 child 是不支持方向，Index 一旦 `@ComponentV2`，所有共享子组件必须同步 V2。

**影响面**：共享包变更波及全部 5 个 App。pilot 验证不仅要 simmer 跑通，还要保证其他 4 个 App 至少**编译通过**（它们 import 同一个共享包）。

### 3.1 `apps/simmer`（pilot 本体）

| 文件 | 变更 |
|---|---|
| `apps/simmer/entry/src/main/ets/pages/Index.ets` | `@Entry @Component` → `@Entry @ComponentV2`；`@State`→`@Local`、`@StorageLink`→`AppStorageV2.connect`、`@Prop`→`@Param`；burner / presetBar / customPanel / 完成 feedback / 生命周期 / 原生 Progress / 自适应 Grid |
| `apps/simmer/entry/src/main/ets/runtime/TimerDoneFeedback.ets` | **新增**：振动 + 系统计时器铃声封装 |
| `apps/simmer/entry/src/main/ets/entryability/EntryAbility.ets` | 加 `onForeground`/`onBackground` 观测日志 |
| `apps/simmer/entry/src/main/module.json5` | `requestPermissions` 加 `ohos.permission.VIBRATE` |
| `apps/simmer/entry/src/main/resources/{base,zh_CN}/element/string.json` | 新增 `simmer_action_delete`（zh:"删除" / en:"Delete"） |

### 3.2 `packages/sunpebble_ui`（全 V2 迁移，全 App 受益）

| 文件 | V1 → V2 迁移要点 |
|---|---|
| `tokens/SunTheme.ets` | `SunColor` 补 `hairline` / `panelTint`；`SunAppManifest` 类型不变（纯 interface） |
| `components/SunButton.ets` | `@Component`→`@ComponentV2`；`@Prop×4`→`@Param`；回调 `action` 普通函数参数 |
| `components/SunCard.ets` | `@Prop`→`@Param` |
| `components/SunEmptyState.ets` | `@Prop`→`@Param` |
| `components/SunListRow.ets` | `@Prop`→`@Param` |
| `components/SunFitText.ets` | `@State×9`→`@Local`；`@Prop`→`@Param` |
| `components/SunEllipsisText.ets` | `@State×8`→`@Local`；`@Prop`→`@Param` |
| `shell/SunAppHeader.ets` | `@Prop`→`@Param` |
| `shell/SunToolShell.ets` | `@Prop`→`@Param`；`@BuilderParam body` 保留（V2 支持）；回调普通函数 |
| `shell/SunTabShell.ets` | 同 SunToolShell |
| `shell/SunSafeRoot.ets` | `@Prop`→`@Param`；`@BuilderParam` 保留；**`@StorageLink×2`→`AppStorageV2.connect`**（最复杂，见 §4.5） |
| `runtime/SunWindowInsets.ets` | 写入端 `AppStorage.setOrCreate` → `AppStorageV2.setOrCreate`（与 SunSafeRoot 读端配对，否则 V2 读不到 V1 写的值） |
| `index.ets` | 导出表不变 |

## 4. 组件设计

### 4.1 Burner 卡片（最大视觉变化）

**Before**：
```
Stack {
  Circle().stroke(border).strokeWidth(8)             // 底环
  Circle().stroke(done?sun:ink).strokeDashArray(...)  // 进度环
    .rotate(-90)
  Column { emoji; 剩余文本; paused/done 标签 }
}
.onClick(toggle)
Text(label.toUpperCase())
Row { 加一分钟; 重启; 取消 }   // 常驻 3 按钮
```

**After**：
```
Stack {
  Progress({ value: pct, total: 100, type: ProgressType.Ring })
    .style({ strokeWidth: 8 })
    .color(done ? SunColor.sun : SunColor.ink)
    .trackColor(SunColor.border)
    .width(142).height(142)
  Column { emoji; 剩余文本; paused/done 标签 }
}
.onClick(toggle)
.bindContextMenu(this.burnerMenu, ResponseType.LongPress)
Text(label.toUpperCase())
Text('⋯')                              // 提示图标，右下角小尺寸低饱和
  .fontSize(14).opacity(0.4)
```

- 进度环：原生 `Progress(Ring)` 替 2 个 Circle + strokeDashArray + rotate。`pct = round((1 - remaining/seconds) * 100)`，done 时 pct=100
- 操作菜单：`.bindContextMenu` 长按唤出 `[加一分钟, 重启, 删除]`（替换常驻 3 按钮）
- 发现性补救：右下角 `⋯` glyph（14vp，opacity 0.4），低视觉噪音但可发现。用 glyph 而非 `sys.media` 资源，避免资源名猜测
- 删除项文案改为"删除"——原代码里 burner 卡的"取消"按钮（`simmer_action_cancel`）实际调用 `deleteTimer`，语义错位。新增字符串资源 `simmer_action_delete`（zh: "删除" / en: "Delete"），仅 burner 菜单内使用；自定义面板的"取消"仍用原 key
- 增删动效：Burner 组件加 `.transition({ type: TransitionOp.All, opacity: 0→1, scale: 0.9→1 })`；外层包裹 `animateTo({ curve: curves.springMotion() })` 在 timers 数组变化时触发

### 4.2 保存的预设（架构级重构）

**Before**：底部水平 `Scroll > Row`，保存的预设和内置预设混在一起，删除走 `× → 确认删除 / 取消` chip。

**After**：拆成两个区块：

1. **保存的预设区块**（仅 `savedPresets.length > 0` 时显示，位于 burner 区**正下方**、customPanel 之上，与活跃任务区视觉分组）：
   ```
   Text("我的预设")    // 小标题，all-caps pebble 色
   List({ space: SunSpacing.sm }) {
     LazyForEach ... {                  // 暂用 ForEach 也可，数量小
       ListItem() { ...预设行... }
         .swipeAction({
           end: { builder: () => this.deleteSwipeAction(preset.id) }
         })
     }
   }
   .height(自适应或限定最大高度)
   ```
   每行：emoji + label + 时长 → 点击启动；右滑露红色"删除"按钮，点删除即时移除（无二次确认，swipe + 显式点按已是 explicit gesture）

布局顺序变为：
```
Column {
  if (空) emptyState() else burnerGrid()
  if (savedPresets.length > 0) savedPresetsBlock()    // 新增
  customPanel()
  builtInPresetBar()                                  // 原 presetBar，去掉保存预设部分
  paywallPanel()
}
```

2. **底部水平预设行**（保留 `Scroll > Row`）：只放"自定义"按钮 + 12 个内置预设 chip。删除"×"逻辑和 `confirmingPresetId` 状态。

收益：swipe-to-delete 是鸿蒙原生手势；语义上保存的预设更像"我的收藏"，与内置区分清楚；更接近 iOS 版本布局。

### 4.3 完成时触感 + 系统音（新增模块）

新增 `runtime/TimerDoneFeedback.ets`：

```typescript
import { vibrator } from '@kit.SensorServiceKit'
// 系统计时器铃声：ringtoneManager 或 systemSoundManager
// 精确 API 在实现阶段对照 API 23 文档确认（haptic.clock.timer 预设效果 / TYPE_TIMER_TONE）

export class TimerDoneFeedback {
  static async fire(): Promise<void> {
    try {
      await vibrator.startVibration({ type: 'preset', effectId: 'haptic.clock.timer' }, ...)
    } catch (_) { /* 静默失败：可见状态仍是 source of truth */ }
    try {
      // 播放系统计时器铃声一次
    } catch (_) { /* 同上 */ }
    // TODO(impl): 文档核对——API 23 是否暴露 systemSoundManager.playSystemSound(TYPE_TIMER_TONE)
    //             或必须用 ringtoneManager.getRingtonePlayer(RingtoneType.TYPE_TIMER_TONE)
  }
}
```

- 仅前台触发（`tick()` 内检测到 remaining→0 时调用）
- 后台到点仍由 `reminderAgentManager` 兜底
- 静默失败：任何 permission denied / API 缺失都 catch 掉，可见状态仍是 source of truth
- 实现阶段第一步先在模拟器跑最小 demo 确认 API，再合入

`module.json5` 加：
```json5
{ "name": "ohos.permission.VIBRATE" }
```

### 4.4 自适应网格（替换 Flex wrap）

**Before**：`Scroll > Flex({ wrap: Wrap, justifyContent: Center })`。

**After**：`Scroll > Grid`（或 `GridContainer`，实现阶段对照文档二选一）：

```
Grid() {
  ForEach(timers, ...) {
    GridItem() { Burner(...) }
  }
}
.columnsTemplate(this.gridColumns())   // 1fr / 1fr 1fr / 1fr 1fr 1fr
.columnsGap(SunSpacing.lg)
.rowsGap(SunSpacing.lg)
.onAreaChange((_old, newArea) => this.containerWidth = newArea.width)
```

`gridColumns()` 基于 `containerWidth` (vp)：
- `< 600`：`'1fr'`（手机）
- `600 ≤ w < 840`：`'1fr 1fr'`（折叠展开/大手机）
- `≥ 840`：`'1fr 1fr 1fr'`（平板）

`module.json5` 已声明 `deviceTypes: ['phone', 'tablet']`，这让平板真正用起来。

### 4.5 平台原生收口

1. **Ponytail token 收口**（全 App 受益）：`SunColor` 新增
   ```typescript
   static readonly hairline: string = '#D8CFBD'   // 替换 9 处 ponytail
   static readonly panelTint: string = '#F7F0E5'  // 替换 1 处 ponytail
   ```
   simmer 内 10 处 `'#D8CFBD'` 和 1 处 `'#F7F0E5'` 全部替换为 `SunColor.hairline` / `SunColor.panelTint`。删除对应 ponytail 注释。

2. **全 V2 状态迁移**（1A 大爆炸：共享包 + Index 彻底迁）：

   **2a. 共享包 `sunpebble_ui` —— 所有组件 `@Component`→`@ComponentV2`**
   - `@Prop x` → `@Param x`（V2 单向，父→子）
   - `@State x` → `@Local x`（V2 组件内部状态）
   - `@BuilderParam` 保留（V2 原生支持，文档已确认）
   - 回调函数（`action`/`onTap` 等）保持普通函数参数，不用 `@Event`（除非需要子→父反向通知，本 pilot 不需要）

   **2b. `SunSafeRoot` + `SunWindowInsets` 的 insets 管道迁移（最复杂）**
   - 现状：`SunWindowInsets.bindSunWindowInsets` 用 V1 `AppStorage.setOrCreate('sun.inset.top.vp', v)` 写；`SunSafeRoot` 用 V1 `@StorageLink('sun.inset.top.vp')` 读
   - 迁移：两端都走 `AppStorageV2`
     - 写端（`SunWindowInsets.ets`）：`AppStorageV2.setOrCreate(KEY, value)` 或 `AppStorageV2.connect(KEY, number, 0)?.set(value)`
     - 读端（`SunSafeRoot.ets`）：`@Local insetTop: number = AppStorageV2.connect('sun.inset.top.vp', number, 0)!`（connect 返回 observable 引用）
   - **API 细节留实现阶段对照 API 23 文档最终确认**：`AppStorageV2.connect` 的签名（`connect<T>(key, type, default)` vs `connect(key)`）、是否需要 `@Local` 包裹。先写最小 demo 在模拟器验证再合入

   **2c. `Index.ets` —— `@Entry @Component` → `@Entry @ComponentV2`，全状态迁 V2**
   - `@State`（7 个）→ `@Local`
   - `@StorageLink`（9 个持久化 key）→ `AppStorageV2.connect(key, type, default)`，包成 `@Local`：
     ```typescript
     // 替代 @StorageLink('simmer.nextId.v1') private nextId: number = 1
     @Local nextId: number = AppStorageV2.connect('simmer.nextId.v1', number, 1)!
     ```
   - `PersistentStorage.persistProp(...)` 9 处 → `PersistenceV2.persistV2(key, default)` 或保留 `PersistentStorage` 让 V2 经由 `AppStorageV2` 间接读写（实现阶段二选一，原则：保持磁盘 key 兼容，老用户数据不丢）
   - `@Prop`（1 个）→ `@Param`
   - `@ObjectLink`（Burner 内）→ `@Param`

   **2d. `KitchenTimer` —— `@Observed` → `@ObservedV2 + @Trace`**
   ```typescript
   @ObservedV2
   class KitchenTimer {
     @Trace remaining: number
     @Trace running: boolean
     @Trace done: boolean
     @Trace endAt: number
     @Trace completedAt: number
     // 其余字段（id/label/emoji/seconds）不 Trace
   }

   @ComponentV2
   struct Burner {
     @Param timer: KitchenTimer
     @Local nowMs: number = Date.now()
     // 回调用普通函数参数
   }
   ```

   **2e. 数据模型兼容**
   - 持久化 key（`simmer.timers.v1` 等）**不变**，磁盘格式不变，老用户数据无损
   - 内存表示：`@StorageLink` 存的是 JSON 字符串再 `JSON.parse`；V2 下仍走 AppStorageV2 的字符串 key + 手动 parse，**不**改成 PersistenceV2 对象持久化（后者会变磁盘格式）。最小改动原则

   **风险与回退**：
   - 主要风险在 2b（insets 管道）和 2c（持久化 key 经 AppStorageV2）。若 AppStorageV2 在 API 23 行为与文档不符或 connect 语义有坑，回退方案：`SunSafeRoot` 用 `@Monitor` 监听 + `AppStorage.get` 手动读，或局部保留 V1（接受 1 个 V1 组件作为子项的限制——但 V2 不能含 V1，所以只能整体回退到方案 1B）
   - **若 V2 迁移在模拟器验证阶段暴露不可解的混用/API 问题，触发降级到 1B**（先合并共享包 V2，pilot 二次进）。此决策点在实施计划里标为 explicit go/no-go gate

### 4.6 生命周期正确性（修真实 bug）

**Bug 复现**：启动一个 30s 计时器 → 立即按 Home 把 App 切后台 → 等 35s → 切回前台。预期：burner 显示 done + 触感/音。实际：tick 被系统暂停，回前台后 burner 仍显示 ~30s 剩余，要等下一次 setInterval（最多 1s）才识别。

**修复**：
```typescript
// Index.ets 内
onPageShow(): void {
  this.tick()   // 重同步：立即识别到点状态
}
```
- `onPageShow` 是 ArkUI 页面级生命周期，页面回到前台时触发，足够覆盖此场景
- `EntryAbility.onForeground` 只加 hilog 观测，不直接驱动 UI（页面级钩子已够）

## 5. 数据流（不变）

持久化 schema 不变：
- `simmer.timers.v1` (JSON)
- `simmer.savedPresets.v1` (JSON)
- `simmer.nextId.v1` / `simmer.nextPresetId.v1`
- `simmer.custom*` 系列
- `simmer.proUnlocked.v1`（保持 `true`，与近期 commit 一致）

新增**非持久化**状态：
- `containerWidth: number`（网格列数推断）
- `nowMs` 已存在

## 6. 错误处理

- 触感/铃声：try/catch 静默失败，可见状态仍是 source of truth
- V2 迁移：insets 管道（2b）和持久化 key 经 AppStorageV2（2c）是高风险点；若 API 23 行为与文档不符且无 workaround，触发降级到方案 1B（见 §4.5 2e 的 go/no-go gate）
- 其他 4 个 App 受共享包 V2 迁移波及：必须编译通过；若某 App 因 V2 子组件 API 变化（如 `@Prop`→`@Param` 传参语义差异）编译失败，修到通过为止（这些 App 本轮只编译验证，不做 UX 改造）
- swipe-to-delete：删除即时生效，撤销不做（数量小、可重建）
- onPageShow tick：失败也无副作用（tick 内本身幂等）

## 7. 验证计划

仓库无测试基建，采用手工冒烟 + 截图 + 编译回归。

### 7.1 构建与安装
```bash
cd apps/simmer
# hvigorw 路径：/Applications/DevEco-Studio.app/Contents/tools/hvigor
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC install entry/build/default/outputs/default/entry-default-signed.hap
```

### 7.2 其他 4 App 编译回归（共享包 V2 迁移波及）

```bash
for app in homekeep sleeptab dayroll steady; do
  cd apps/$app && hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
done
```
- 只要求**编译通过**，不要求运行（UX 改造本轮只针对 simmer）
- 若编译失败，根因多是 `@Prop`→`@Param` 的传参差异或 `@StorageLink` 在 V2 下不可用——按 V2 语义修对应 App 的调用点
- 这一步是 1A 大爆炸的必要代价：共享包动了，全 App 都要过编译

### 7.3 simmer 冒烟脚本（按顺序执行）

| # | 步骤 | 预期 |
|---|---|---|
| 1 | 启动 App | 空态：🍳 + 文案 + 底部 chip 行 |
| 2 | 点 🍵 Tea 预设 | 出现一张 burner，剩余 3:00，倒计时中 |
| 3 | 点 🍜 Ramen | 第二张 burner，并发运行 |
| 4 | 点第一张 burner | 暂停（剩 ~2:58，paused 标签） |
| 5 | 再点 | 恢复运行 |
| 6 | 长按第一张 burner | 弹出菜单：加一分钟 / 重启 / 删除 |
| 7 | 菜单选"加一分钟" | 该 burner seconds +60，剩余相应增加 |
| 8 | 打开自定义面板，emoji+1m30s+label"测试" | 填写正常 |
| 9 | 勾"保存为预设" + 启动 | burner 启动，**新预设出现在 burner 下方"我的预设"垂直区块** |
| 10 | 在"我的预设"右滑那行 | 露红色"删除"按钮 |
| 11 | 点删除 | 该预设消失，垂直区块如有 0 项则整个区块消失 |
| 12 | 启动一个 15s 计时器，等其到点 | **触感 + 系统铃声 + toast + burner 变 done 黄环 + overdue 计数**（模拟器若无振动/铃声硬件，至少 toast + 视觉 done + overdue） |
| 13 | 点 done burner | 删除该 burner |
| 14 | 启动 30s 计时器 → 立即 Home 切后台 → 等 35s → 切回 | **立即显示 done（验证 onPageShow 重 sync bug 修复）** |
| 15 | 在平板尺寸（如改模拟器窗口）下查看 | burner 网格变 2-3 列 |
| 16 | 退出 App 重启 | timers / savedPresets / 自定义设置全部恢复（验证持久化 key 兼容，老数据不丢） |

### 7.4 截图

```bash
$HDC shell snapshot_display -f /data/local/tmp/simmer_<scene>.jpeg
$HDC file recv /data/local/tmp/simmer_<scene>.jpeg .asc-shots/simmer/after/
```

关键屏（8 张）：`empty` / `single_running` / `multi_running` / `paused` / `context_menu` / `saved_presets_block` / `swipe_delete` / `done_state`。

存到 `.asc-shots/simmer/after/`，与 `.asc-shots/simmer/before/`（实施前先拍）逐张对比。

### 7.5 通过标准

- §7.2 其他 4 App **全部编译通过**（1A 必要条件）
- §7.3 simmer 16 项冒烟全部符合预期
- 8 张截图视觉合理（进度环、网格、保存预设区块布局正确）
- 无 ponytail 注释残留：`rg -c "ponytail" apps/simmer` 返回 0
- 无 V1 装饰器残留：`rg "@State|@StorageLink|@StorageProp|@Prop\b|@ObjectLink|@Observed\b" apps/simmer/entry/src/main/ets` 返回 0（确认 Index 彻底 V2）
- 启动无 crash，hilog 无新 error
- 重启后数据无损（验证 §7.3 第 16 步）
- `apps/simmer` 与 `simmer-harmony/apps/simmer` 文件级一致（diff 为空）

## 8. 风险与回退

| 风险 | 概率 | 影响 | 回退 |
|---|---|---|---|
| **V2 insets 管道（SunSafeRoot + SunWindowInsets）在 API 23 行为不符** | 中 | 高（影响所有 App 安全区） | 触发降级到 1B；或局部用 `@Monitor`+`AppStorage.get` 手动读 |
| **AppStorageV2 connect 语义有坑**（返回值/observable 性质） | 中 | 高（持久化全断） | 同上；或保留 PersistentStorage + 在 V2 组件内用 `@Monitor` 桥接 |
| **其他 4 App 因 V2 子组件 API 变化编译失败** | 高 | 中（需修 4 App 调用点） | 按错误信息逐个修；属预期工作量，非阻断 |
| 触感/铃声 API 在模拟器不可用 | 高（模拟器无硬件） | 低（真机能用） | catch 静默失败；冒烟第 12 步降级为"至少 toast+视觉" |
| `Grid` 自适应在模拟器尺寸下边界 case | 低 | 低 | 列数阈值可调；最差回退到 `Flex wrap` |
| swipeAction 在低版本 API 行为差异 | 低 | 低 | API 23 是目标，模拟器即 API 23 |
| bindContextMenu 与 onClick 冲突 | 低 | 低 | 改用 `.bindMenu` + 显式 gesture |
| 持久化磁盘格式意外变化导致老用户数据丢 | 低 | 高 | key 不变 + 仍是 JSON 字符串；冒烟第 16 步专项验证 |

## 9. Playbook 沉淀

pilot 完成后，本文档 + 实施过程沉淀出可复用的 playbook，包含：
- HarmonyOS 平台优化检查清单（进度环/触感/铃声/swipe/网格/V2/生命周期/pigtail token）
- 验证脚本模板（构建/安装/冒烟/截图）
- 后续 4 个 App 的复制顺序建议（建议 homekeep → sleeptab → dayroll → steady，按复杂度递增）

playbook 文档独立写到 `docs/superpowers/specs/2026-07-07-harmony-platform-optimization-playbook.md`，不在本 spec 内。

## 10. 开放问题（实现阶段确认，不阻断 spec 批准）

1. 触感 exact API：`vibrator.startVibration` 的 preset 效果 ID（`haptic.clock.timer` 是否存在）— 实现阶段查 API 23 文档
2. 系统计时器铃声：`systemSoundManager` vs `ringtoneManager`，二选一 — 实现阶段查文档
3. `GridContainer` vs `Grid + onAreaChange`，二选一 — 实现阶段验证
4. **`AppStorageV2.connect` 签名与 observable 性质**（§4.5 2b/2c 关键依赖）— 实现阶段先写最小 demo 在模拟器验证：connect 返回的是否为响应式引用、能否直接绑 `@Local`、写端 `setOrCreate` 是否触发读端刷新
5. **`PersistenceV2` 与 `AppStorageV2` 关系**：持久化 key 是走 `PersistenceV2.persistV2` 还是保留 `PersistentStorage.persistProp` 让 `AppStorageV2` 间接读写 — 实现阶段二选一，原则是磁盘 key 兼容

### 实施顺序建议（go/no-go gate 在第 3 步）

1. 先拍 before 截图（§7.4）
2. 共享包 `sunpebble_ui` 全 V2 迁移（§3.2 全表）
3. **gate**：写 `AppStorageV2.connect` 最小 demo 在模拟器验证 §10 第 4 点。**通过→继续；失败→停下找替代或降级 1B**
4. 4 个 App 编译回归（§7.2），修到通过
5. simmer Index 全 V2 + UX + 平台原生（§4 全部）
6. simmer 冒烟 16 项 + after 截图（§7.3/7.4）
7. 通过标准核对（§7.5）
