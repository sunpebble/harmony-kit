# @ObservedV2 + @Trace 的 JSON.stringify 陷阱

> 来源：Task 7 simmer Index V2 迁移实证（2025-07-08）。环境：DevEco API 23、hvigor 6.23.6。

## 问题

`@Trace` 装饰的属性**不能**被 `JSON.stringify` 正确序列化。

## 根因

ArkUI V2 的 `@Trace` 把属性的实际存储重命名为 `__ob_<name>`，并在原名上安装 getter/setter 做属性级观测。`JSON.stringify` 只序列化 enumerable own property：

```typescript
@ObservedV2
class Foo {
  plain: number = 1
  @Trace observed: number = 2
}
const f = new Foo()
JSON.stringify(f)
// 实际输出：{"plain":1,"__ob_observed":2}
// 注意：key 是 __ob_observed，不是 observed
```

`JSON.parse` 回来后对象上有 `__ob_observed` 但没有 `observed`，访问 `f.observed` 得到 `undefined`。

## 影响

任何把 `@ObservedV2` 对象（含 `@Trace` 字段）序列化到磁盘 / 传输 / `JSON.stringify` 的代码都会静默丢字段。症状：恢复后 @Trace 字段全 `undefined`，非 @Trace 字段正常。

## 解决方案

序列化前显式映射到 plain object（interface / class 实例），通过 getter 读取真实值：

```typescript
interface FooSnapshot {
  plain: number
  observed: number
}

// ✅ 正确：显式读 getter，plain object 序列化出正确 key
const snapshot: FooSnapshot = { plain: f.plain, observed: f.observed }
JSON.stringify(snapshot)  // {"plain":1,"observed":2}

// ❌ 错误：直接 stringify @ObservedV2 对象
JSON.stringify(f)  // {"plain":1,"__ob_observed":2}
```

反序列化（`JSON.parse` → plain object → `new Foo(...)` 构造）不受影响。

## 适用范围

- ✅ 持久化到 AppStorage / PersistentStorage（JSON string 形式）
- ✅ 跨进程 / 跨 ability 传递（序列化为 JSON）
- ❌ 不影响：直接在内存里读 `obj.field`（getter 正常工作）、@Param 传递对象引用（不经过 JSON）

## 已知受影响位置

| 文件 | 状态 |
|---|---|
| `apps/simmer/.../Index.ets` `saveTimers()` | ✅ 已修复（Task 7，commit cb69972） |
| 其它 App 数据类 | 暂无 @ObservedV2 数据类 + JSON 持久化的场景；迁移时注意 |

## 验证方法

加临时 `console.info(`DEBUG raw=${JSON.stringify(obj)}`)`，hilog 看 key 名是否带 `__ob_` 前缀。
