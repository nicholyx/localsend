# 设计:第二轮上游同步与冲突解决

## 合并策略

沿用 `spec/maintenance/upstream-sync.md`:**分支 + merge(不 rebase)**,
预检已做(`git merge-tree` 报 1 处冲突),合并保留上游提交历史。

- 分支:`chore/upstream-sync-2`
- 预检结论:`app/lib/util/native/directories.dart` 冲突(双方都改)

## 冲突解决(唯一的冲突)

**背景**:本 fork 为鸿蒙把该文件的穷举 `switch (defaultTargetPlatform)`
改写成 if/else(fork 的 `TargetPlatform` 多了 `ohos` 值,穷举 switch 编译失败);
上游 `1e15f5cd` 在同一函数里加了软链接解析。

**解法**:保留 fork 的 if/else 结构 + 采纳上游逻辑:

```dart
import 'dart:io' show Directory, FileSystemException, Platform;   // 采纳上游的 import

// ... android / iOS 分支保持 fork 的 if 形式 ...
var downloadDir = await path.getDownloadsDirectory();
if (downloadDir == null) {
  // ... fork 的兜底逻辑不变 ...
}
try {
  // 采纳上游:Downloads 可能是软链接(含 macOS 沙盒)
  return (await downloadDir.resolveSymbolicLinks()).replaceAll('\\', '/');
} on FileSystemException {
  // 无法解析时回退到平台提供的路径
}
return downloadDir.path.replaceAll('\\', '/');
```

**验证该文件的正确性**:`flutter analyze` 通过 + `flutter test` 全过
(该函数有单测覆盖路径行为);另外 grep 确认文件内无 `switch (defaultTargetPlatform)`。

## 影响面与风险

| 变更 | 鸿蒙影响 | 风险与缓解 |
| --- | --- | --- |
| `612aeef2` IP 限流(新文件 `connection_limit.rs` + `http/server/mod.rs` + hyper features `http1,server`) | **自动生效**:core 服务端在鸿蒙原样运行,Dart 侧无新 API(未改 FRB 层) | 已确认**未新增 Cargo feature 门控**,不存在上次 `discovery` 那类"漏 feature"风险;`lru` 依赖已存在。ohos target 的实际编译由 CI 的 HAP 构建覆盖(本机无法交叉编译 ring 的 build script) |
| `5db88c63` 文件不可读 → 传输失败 | 行为改善 | 有单测(`e768240d` 整理了不可读文件上传测试) |
| `1e15f5cd` 路径解析 | 冲突源 | 见上 |
| `f5e1e667` 零填充 | 发送端行为 | 有对应测试 |
| `03317bc2` Kyrgyz | 与 fork 修复逐字一致 | 预期无冲突;若 git 报冲突则保留同字符串 |

## 为什么"移植到鸿蒙"这一步几乎为零

`app/ohos/**`、`third_party/**`、cargokit 均未被上游触碰(本轮 diff 文件清单里没有),
上游改动全部落在共享层(`packages/core`、`app/lib`),因此"更新到鸿蒙 app"
= 合并 + 鸿蒙约束回归检查 + 重新出包。

## 回滚

- 合并前:放弃 PR(不动 main)
- 合并后:`git revert -m 1 <merge-commit>`;HAP artifact 与 release 无关

## 额外收获(写入 spec 的机会)

上游独立修了同样的 Kyrgyz 缺口(字符串逐字一致)——这是"fork 的修复与上游收敛"
的正面样本,值得在同步 spec 的踩坑里补一句:自己的修复若上游后来同样修了,
合并时应零冲突;若字符串不同(如大小写/用词),则会出现"同义冲突",需要以
上游为准并保留 diff 备注。
