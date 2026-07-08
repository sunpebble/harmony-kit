# V2 迁移后 4 App 编译回归（homekeep / sleeptab / dayroll / steady）

> 任务 6 实测记录。共享包 `sunpebble_ui` 在任务 3-5 全量迁移到 `@ComponentV2`/`@Param` 后，4 个仍为 V1 `@Entry @Component` 的 App 必须编译通过。环境：DevEco SDK API 23、hvigor 6.23.6、`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk`。

## 结论：4/4 BUILD SUCCESSFUL，仅 1 处共享包迁移遗漏需修

首次全量编译：homekeep ✅、sleeptab ✅、dayroll ✅、steady ❌。仅 steady 报错，其余 3 App 零改动通过。

## per-app 结果

| App | 首次 | 修复后 | 改动 |
|---|---|---|---|
| homekeep | ✅ | ✅ | 无 |
| sleeptab | ✅ | ✅ | 无 |
| dayroll | ✅ | ✅ | 无 |
| steady | ❌ | ✅ | 见下（共享包 1 行） |

## steady 唯一报错与修法（playbook 资产）

**报错**（`apps/steady/entry/src/main/ets/pages/Index.ets:2449`）：

```
ArkTS:ERROR 10905324
The 'regular' property 'tabs' in the custom component 'SunTabShell'
cannot be initialized here (forbidden to specify).
```

**调用点**（steady `Index.ets`，V1 `@Entry @Component`）：
```typescript
SunTabShell({
  manifest: appProfile,
  tabs: this.steadyTabs(),      // ← 报错行
  activeTab: this.tab,
  onTabChange: (tabId: string) => { ... },
  tabBody: (tabId: string) => { this.steadyTabBody(tabId) }
})
```

**根因**：`SunTabShell.ets` 迁移到 `@ComponentV2` 时，`tabs: SunTabItem[]` 被刻意保留为普通成员（提交 `bdc6bd2`，commit message 写明 *"kept as plain member (parent passes once, no reactive updates needed)"*）。该判断对 **V1** 成立（普通属性可被父组件初始化），但在 **V2 `@ComponentV2`** 下错误——**只有 `@Param`/`@Local`/`@Once` 等被装饰的成员才能从父调用点初始化**，普通成员禁止外部赋值。这是任务 4 的迁移遗漏，不是调用点 bug。

**为何 simmer 绿、steady 红**：simmer 不使用 `SunTabShell`（只有 steady 用）。任务 3-5 仅以 simmer 编译为验收门槛，未覆盖该代码路径，所以遗漏未暴露。

**修复**（`packages/sunpebble_ui/src/main/ets/shell/SunTabShell.ets:22`，1 行）：
```diff
-  tabs: SunTabItem[] = []
+  @Param tabs: SunTabItem[] = []
```
与同组件内 `manifest`/`activeTab`/`onTabChange` 全部 `@Param` 的迁移方式一致；`= []` 默认值保留，未传 `tabs` 的调用点不受影响。**外部 API（属性名、类型、传值方式）零变化**，仅装饰器补齐。调用点无需改动。

## 通用规则（后续迁移 playbook）

1. **V2 组件凡需父组件传入的成员，必须加 `@Param`（或 `@Once`）**。V1 时代「普通成员 + 父组件赋值」的写法在 V2 下编译失败，报错码 `10905324` *"regular property ... cannot be initialized here"*。
2. **迁移验收要覆盖所有消费方**，不能只靠一个 pilot App 编译。本次遗漏正是因为只有 steady 用到 `SunTabShell`，而验收只跑 simmer。
3. **V1 父 → V2 子的 `@Param` 传对象 / 回调 / `@BuilderParam` 尾随闭包均无摩擦**（spike 已证，本任务 4 App 再证）。`manifest`（对象）、`onTabChange`/`tabBody`（回调）、`tabBody` 尾随闭包在 4 个 V1 `@Entry` 中全部直接通过，无需 `UIUtils.enableV2Compatibility`。
4. 本轮**未改动任何 App 自身的 V1 装饰器**（`@State`/`@StorageLink` 等保持），符合试点范围。

## 验证命令

```bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/shikun/Developer/freelance/sunpebble/harmony-kit
for app in homekeep sleeptab dayroll steady; do
  (cd apps/$app && $HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon 2>&1 | grep -E "BUILD SUCCESSFUL|BUILD FAILED")
done
```
修复后 4 App 均 `BUILD SUCCESSFUL`。
