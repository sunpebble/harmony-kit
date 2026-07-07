# V2 迁移降风险 Spike 实证结论（AppStorageV2 + V1/V2 @BuilderParam 互操作）

> 任务 1 的 GO/NO-GO 关卡实测结果。环境：DevEco API 23 模拟器（`127.0.0.1:5555`，phone）、bundle `com.sunpebble.simmer`、hvigor 6.23.6、`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk`。spike 文件（`apps/simmer/entry/src/main/ets/pages/SpikePage.ets`）已删除，不入产物；本文档为唯一留存。

## 结论：4/4 GO 标准 PASS —— V2 迁移可按原计划推进

模拟器实测：四个计数器每秒自增且 UI 实时刷新（截图样本：t≈4s→3，t≈18s→50，t≈24s→94，四个计数始终同步）。

## 工作的 API 签名（已编译通过 + 运行期行为正确）

### 1. AppStorageV2.connect —— @StorageLink 的 V2 替代（响应式 ✅）

**真实签名是「type 在前」，brief 里 `(key, Type, default)` 的猜测顺序是错的。**

错误信息：`Argument of type 'string' is not assignable to parameter of type 'TypeConstructorWithArgs<SpikeData>'`（即第 1 个参数应为类型构造器，不是字符串 key）。

正确写法（从官方 `arkts-mvvm-v2` 文档样例对齐）：
```typescript
import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
class SpikeData {
  @Trace count: number = 0
}

// 在 @ComponentV2 内用 @Local 包裹 —— 响应式成立
@ComponentV2
struct SpikeChild {
  @Local connected: SpikeData =
    AppStorageV2.connect(SpikeData, 'spike.v2.key', () => new SpikeData())!
}
```
要点：
- 顺序：`connect(type: TypeConstructorWithArgs<T>, key: string, defaultCreator: () => T): T | undefined`，需要 `!` 解空。
- `connect` 按 key 返回**同一个共享实例**。父组件持有同一 key 的实例、在 `setInterval` 里改 `this.v2Data.count`，子组件 `@Local connected.count` 实时跟着刷新 —— **这正是 V1 `@StorageLink` 的跨组件双向同步语义的 V2 等价**。
- `type` 与 `defaultCreator` 返回类型必须一致，否则触发 140107 类型不匹配错误（官方 errorcode 文档已确认）。

### 2. V1 父 → V2 子：@BuilderParam 尾随闭包（未文档化场景，✅ 成立）

`@Entry @Component`（V1）父组件用尾随闭包初始化 `@ComponentV2`（V2）子的 `@BuilderParam` —— **编译通过且运行期渲染正常**。这是官方文档未覆盖的场景，spike 实证可行，意味着 4 个仍为 V1 `@Entry` 的 App 可以直接托管 V2 共享组件。

```typescript
@Builder
function emptyBody() {}   // @BuilderParam 的默认值必须是 @Builder 函数，内联 () => {} 不行

@ComponentV2
struct SpikeChild {
  @Param data: SpikeData = new SpikeData()
  @BuilderParam body: () => void = emptyBody
  build() {
    Column({ space: 8 }) {
      Text(`child @Param count: ${this.data.count}`).fontSize(20)
      this.body()
    }
  }
}

@Entry @Component          // ← V1 父
struct SpikePage {
  v2Data: SpikeData = AppStorageV2.connect(SpikeData, 'spike.v2.key', () => new SpikeData())!
  build() {
    SpikeChild({ data: this.v2Data }) {                 // ← V1 父用尾随闭包喂 V2 子的 @BuilderParam
      Text('--- trailing closure body ---').fontSize(14)
    }
  }
}
```
要点：
- `@BuilderParam` 的默认初始化器**必须是 `@Builder` 函数**（错误码：`'@BuilderParam' property can only initialized by '@Builder' function`）。用全局 `@Builder function emptyBody() {}` 作默认即可；brief 里的内联 `= () => {}` 编译失败。
- 尾随闭包从 V1 父传给 V2 子的 `@BuilderParam` 无需任何额外包装。

### 3. V1 父传对象给 V2 子 @Param（✅，无需 enableV2Compatibility 包装）

```typescript
@Entry @Component          // V1 父：普通属性（非 @State）
struct SpikePage {
  v2Data: SpikeData = AppStorageV2.connect(...)!
  build() { SpikeChild({ data: this.v2Data }) {...} }   // 直接传 @ObservedV2 对象给 V2 @Param
}
```
- brief 文档预设里担心的「V1 @State → V2 @Param 报错需 `UIUtils.enableV2Compatibility` 包装」**在「V1 普通属性 → V2 @Param」路径上不触发**。只有用 `@State` 装饰的对象才报「去掉 @State」。本次 spike 用普通属性传 @ObservedV2+@Trace 对象，编译 + 运行均通过。
- V2 子 `@Param data` 的 `@Trace count` 变化能被观测，UI 实时刷新。

## 四项 GO 标准（逐条）

| # | 标准 | 结果 | 证据 |
|---|------|------|------|
| 1 | legacy `@StorageLink` 计数自增 + UI 刷新（健全性） | **PASS** | 3→50→94 |
| 2 | `@Local`+`AppStorageV2.connect` 计数自增 + UI 刷新（核心） | **PASS** | child @Local connect count: 3→50→94 |
| 3 | V2 子 `@Param` 接收 @ObservedV2+@Trace 对象、观测属性变化 | **PASS** | child @Param count: 3→50→94 |
| 4 | V1 @Entry 父 → V2 @ComponentV2 子 @BuilderParam 尾随闭包渲染 | **PASS** | `--- trailing closure body ---` 始终可见 |

## 额外发现（对迁移有正面影响）

**V1 组件直接读 @ObservedV2+@Trace 属性也能响应式刷新。** spike 里 V1 父用**普通属性**（无 @State/@Local）持有共享对象，`Text(`parent V2 connect count: ${this.v2Data.count}`)` 仍然每秒刷新（3→50→94）。这说明 V2 的 @Trace 属性级观测**独立于** V1/V2 组件模型，V1 组件读 @Trace 属性即可拿到响应式。迁移期内「V1 页面临时引用 V2 数据」无需额外包装就有反应，降低了过渡复杂度。

## 踩坑记录（供后续 task 复用）

1. **`@Local` 只能在 `@ComponentV2` 内用。** brief 把 `@Local` 放进 V1 `@Component` 父，编译报 `'@Local' decorator can only be used in a 'struct' decorated with '@ComponentV2'`。V1 组件需用普通属性 / `@State` 持有数据，`@Local` 留给 V2 组件。
2. **`AppStorageV2.connect` 参数顺序是 `(type, key, defaultCreator)`**，不是 `(key, type, default)`。
3. **`@BuilderParam` 默认值必须是 `@Builder` 函数**，内联 lambda 不行。
4. （次要）spike 里 `aboutToAppear` 可能被多次触发，导致多个 `setInterval` 叠加、计数增长快于 1/s。这仅影响观察节奏，不影响响应式结论；正式组件应在 `aboutToDisappear` 清理 interval。
