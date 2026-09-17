# Spec 导航

本目录是 localsend(鸿蒙移植 fork)的编码规范,供 AI 会话在动手前注入。
所有规则都来自真实代码与真实踩坑,每条都给出处。

## 这个项目是什么

一句话:**LocalSend(开源跨平台 AirDrop 替代)的 HarmonyOS/OHOS 移植版 fork。**

- 本仓库只维护**鸿蒙相关代码**;上游(localsend/localsend)不接受 AI 生成的贡献,
  本 fork 不受此约束,但保持上游风格的提交规范(Conventional Commits、英文提交信息)
- 移植采用官方推荐的 flutter-ohos 方式:`app/ohos/` 应用壳 +
  `third_party/flutter/` vendored OHOS 插件 + cargokit 的 `ohos-arm64` 支持
- 完整移植文档见 [docs/HARMONYOS.md](../../docs/HARMONYOS.md);构建/CI 踩坑详情
  见 harmonyos spec

## 按任务类型选择要读的 spec

| 你要动什么 | 先读 |
| --- | --- |
| `app/ohos/**`、CI 打包、签名、工具链 | [harmonyos/index.md](harmonyos/index.md) —— **必读** |
| `app/lib/**`、`app/test/**`(Dart/Flutter) | [flutter/index.md](flutter/index.md) |
| `packages/core`、`packages/localsend_isolates/rust`、`cli`、`server` | [rust/index.md](rust/index.md) |
| Issue / PR / 里程碑 / 发布 / 开发闭环 | [maintenance/index.md](maintenance/index.md) —— **必读** |
| 合并上游(localsend/localsend)的更新 | [maintenance/upstream-sync.md](maintenance/upstream-sync.md) —— **必读** |
| 设计判断(该不该做、怎么取舍) | [guides/index.md](guides/index.md) |

## Pre-Development Checklist(任何任务动手前)

1. 读上表对应的 spec 入口;鸿蒙相关改动再核对 `docs/HARMONYOS.md` 的架构表
2. 本地基线先跑绿(见下);涉及版本号时检查三处同步(见 harmonyos spec)
3. GitHub 侧:gh 命令一律带 `-R nicholyx/localsend`;流程规则见
   [maintenance/index.md](maintenance/index.md)(小批量提交、测试包不进 release、
   人工验证是发布硬门禁)

## Quality Check(任何任务收尾前)

- [ ] `fvm dart format --set-exit-if-changed lib test`(在 `app/`,CI 会先删 lib/gen)
- [ ] `fvm flutter analyze` 0 issues;`fvm flutter test` 全过
- [ ] Rust 改动:`cargo clippy --features full`(core)、`cargo check`(插件 crate/cli/server)
- [ ] ohos 相关:Dart 侧无 `TargetPlatform.ohos` 引用;中文内容全仓扫 U+FFFD
- [ ] 行为变了 → `docs/HARMONYOS.md` 同步;CI 全绿才合并
