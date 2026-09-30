# 上游同步(第二轮):合并 9 个提交并把新功能/修复带到鸿蒙端

## 背景

上次同步(2026-09-17,PR #9)之后上游推进了 9 个提交。本 fork 复用同一
`packages/core` 与 `app/lib`,合并即等于把相关功能移植到鸿蒙端;本轮包含一个
**新功能**与**多个核心正确性修复**,不只是维护性更新。

上游提交(2026-09-30 通过 SSH 拉取,`git log main..upstream/main`):

| 提交 | 内容 | 对鸿蒙的影响 |
| --- | --- | --- |
| `612aeef2` | **feat: limit incoming requests by IP** | core HTTP 服务端新能力,鸿蒙直接生效(接收端限流) |
| `5db88c63` | fix: 文件不可读时让传输失败,而不是发空文件 | 核心传输正确性,鸿蒙直接受益 |
| `1e15f5cd` | fix: 显示真实保存路径(解析软链接) | **冲突源**(`directories.dart`),需按鸿蒙规则解 |
| `f5e1e667` | fix: 重命名选中文件时的零填充 | 发送端行为 |
| `03317bc2` | fix(i18n): name Kyrgyz locale | 与我们上次的修复**逐字一致**,不冲突 |
| `e768240d` / `acf7322c` / `6f6cd3ee` | 测试整理 / 移除未用 import / merge commit | 低风险 |
| `c5bbe363` | docs: 版本兼容表 | 文档 |

冲突预检(`git merge-tree main upstream/main`):**1 处冲突** ——
`app/lib/util/native/directories.dart`(我们为鸿蒙改成 if/else,上游也改了同文件)。

## 期望(验收标准)

- [ ] 9 个上游提交全部并入 main(经分支 + PR,merge commit 保留上游历史)
- [ ] `directories.dart` 冲突按设计解决:保留 if/else 结构(鸿蒙规则)+ 采纳上游
      的 `resolveSymbolicLinks()` 逻辑(含 `FileSystemException` 兜底)
- [ ] 新增的 IP 限流功能在 Dart/Rust 两侧契约一致(FRB 生成代码与 core 一致)
- [ ] `fvm dart format --set-exit-if-changed lib test` 通过
- [ ] `fvm flutter analyze` 0 issues;`fvm flutter test` 全过(app 与
      localsend_isolates)
- [ ] Rust:`cargo test --features full`(core)通过(既有 macOS 环境敏感用例
      #10 除外,需先用干净 worktree 判既有);`cargo check`(插件/server/cli)通过
- [ ] 鸿蒙约束无回归:无 `TargetPlatform.ohos` 代码引用;`directories.dart` 仍是
      if/else;ohos target 的 core features 仍为
      `["crypto", "discovery", "http", "multicast"]`
- [ ] `dart run slang` 零漂移(生成物与 assets 一致)
- [ ] PR 的 CI(`ci-summary`)全绿后合并
- [ ] 合并后触发 `Build HarmonyOS HAP` 并产出 artifact,在 Issue #3 留言验证重点

## 非目标

- 不发布 release
- 不在本 PR 里修既有问题(#10 等),发现的既有缺陷单独开 Issue
- 不重构鸿蒙移植层

## 备注

- 本次上游的 Kyrgyz 修复(`03317bc2`)与我们在 PR #9 的修复字符串完全一致,
  说明上次判断正确;合并后该处应无冲突(相同改动)
- **网络**:本机 HTTPS 到 github.com 不通(代理 127.0.0.1:56134 已失效),
  改用 SSH 通道:`git fetch git@github.com:localsend/localsend.git
  main:refs/remotes/upstream/main --tags`。gh CLI 同理需绕代理
