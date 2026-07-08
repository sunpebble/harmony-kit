# V2 迁移 · 其余 4 App 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Checkbox tracking.

**Goal:** 将 homekeep / sleeptab / dayroll / steady 的 `Index.ets` 从 V1 状态管理迁到 V2，并清理 ponytail 硬编码。

**Architecture:** 共享包已全 V2（simmer pilot 完成），4 App 已编译通过。本计划只迁各 App 自有的 `Index.ets` 状态装饰器 + 清理 ponytail。无 `@Observed` 类（比 simmer 简单）。

**Playbook:** `docs/superpowers/notes/v2-spike-findings.md` + `docs/superpowers/notes/v2-trace-serialization-gotcha.md` + `docs/superpowers/notes/v2-compile-regression.md`

## Global Constraints

- **DEVECO_SDK_HOME**=`/Applications/DevEco-Studio.app/Contents/sdk`
- **hvigorw**=`/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw`
- **hdc**=`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`
- 模拟器 `127.0.0.1:5555` (API 23)
- **V2 迁移规则**（simmer 验证过）：
  - `@Component` → `@ComponentV2`
  - `@State` → `@Local`
  - `@StorageLink('key')` → `@Local` + `aboutToAppear` 里 `AppStorage.get` + 每次 mutation 调 `AppStorage.setOrCreate`
  - `@Prop` → `@Param`
  - **保留** `PersistentStorage.persistProp(...)` 调用（磁盘兼容）
  - **无 `@Observed` 类**（4 App 均无），无需处理 `@ObservedV2`/`@Trace`
- **Ponytail 清理**：`#D8CFBD` → `SunColor.hairline`，`#F7F0E5` → `SunColor.panelTint`，删 `// ponytail:` 注释
- `AppStorage` 是全局 API，无需 import
- 构建验证：`hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
- 提交：每 App 一个 commit（分支 `harmony-platform-opt-batch2`）

---

## Task H: homekeep V2 + ponytail

**Files:** `apps/homekeep/entry/src/main/ets/pages/Index.ets`

**Scope:** 5 `@State` → `@Local`，3 `@StorageLink` → `@Local` + AppStorage，1 `@Component` → `@ComponentV2`，3 ponytail → token

- [ ] V2 迁移 + ponytail 清理 + 构建验证 + 模拟器冒烟（启动正常、数据持久）
- [ ] Review

## Task S: sleeptab V2 + ponytail

**Files:** `apps/sleeptab/entry/src/main/ets/pages/Index.ets`

**Scope:** 3 `@State` → `@Local`，7 `@StorageLink` → `@Local` + AppStorage，1 `@Prop` → `@Param`，2 `@Component` → `@ComponentV2`（有子组件？），15 ponytail → token

- [ ] V2 迁移 + ponytail 清理 + 构建验证 + 模拟器冒烟
- [ ] Review

## Task D: dayroll V2 + ponytail

**Files:** `apps/dayroll/entry/src/main/ets/pages/Index.ets`

**Scope:** 11 `@State` → `@Local`，9 `@StorageLink` → `@Local` + AppStorage，1 `@Component` → `@ComponentV2`，19 ponytail → token

- [ ] V2 迁移 + ponytail 清理 + 构建验证 + 模拟器冒烟
- [ ] Review

## Task ST: steady V2 + ponytail

**Files:** `apps/steady/entry/src/main/ets/pages/Index.ets`（2506 行，最大）

**Scope:** 19 `@State` → `@Local`，27 `@StorageLink` → `@Local` + AppStorage，1 `@Component` → `@ComponentV2`，5 ponytail → token

- [ ] V2 迁移 + ponytail 清理 + 构建验证 + 模拟器冒烟
- [ ] Review

---

## 通过标准（每 App）

- `rg "@State|@StorageLink|@StorageProp|@Prop\b|@ObjectLink|@Observed\b" apps/<app>/entry/src/main/ets` 返回空
- `rg "ponytail" apps/<app>/entry/src/main/ets` 返回空
- `hvigorw assembleHap` BUILD SUCCESSFUL
- 模拟器启动正常、数据持久（重启后恢复）
